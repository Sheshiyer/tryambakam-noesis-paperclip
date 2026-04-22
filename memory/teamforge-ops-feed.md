# TeamForge Ops Feed Contract

## Purpose

Define how `ts-paperclip` ingests TeamForge `agent_feed/v1`, routes signals, dispatches tasks, and measures closed-loop outcomes.

## Ingestion and Schema Rules

- Ingestion entrypoint: `scripts/teamforge-sync.sh`.
- Expected TeamForge schema: `agent_feed/v1`.
- Feed pulls are cursor-driven (`nextCursor`) and idempotent by `syncKey`.
- If schema version mismatches, the run is marked failed, cursor is not advanced, and no previous artifacts are mutated.

## Immutable Snapshots and Replay

- Snapshot base path: `vault/leadership/teamforge-feed/YYYY/MM/DD/`.
- Snapshot filename pattern: `teamforge-feed-<timestamp>-<nonce>.json`.
- Snapshot writes are atomic (`tmp` + `mv`) to avoid partial corruption.
- Replay command:
  - `./scripts/teamforge-sync.sh replay <snapshot-file> --dry-run`
- Retention policy:
  - `retention_days` in `manifest.yaml` (default `30`).
  - Pruning only deletes files older than retention; latest snapshots are never rewritten.

## Routing Rules

`teamforge-sync` applies deterministic signal-to-owner routing:

- `standup.miss|heartbeat|quality|drift|sync.failed` -> `sentinel`
- `clockify|huly.issue|deploy|build|runtime|bug|error` -> `clawd`
- `content|copy|marketing|client|research` -> `sage`
- critical fallback or unknown patterns -> `jarvis`

Override and fallback behavior:

- `ownerHint` prefixed with `agent:` is treated as an explicit owner override.
- If no rule matches, fallback owner is always `jarvis`.
- Route reason is recorded per signal for debugging traces.

## Severity Scoring Rubric

Every signal gets:

- `feedSeverity` (upstream value)
- `score` (0..100)
- `scoredSeverity` (`info|warn|critical`)
- `scoreRationale` (human-readable rationale string)

Base score starts from feed severity, then adjusts for event risk patterns.
Dispatch priority mapping:

- `critical` -> Paperclip priority `critical`
- `warn` -> Paperclip priority `high`
- `info` -> Paperclip priority `medium`

## Dedupe and Cooldown

Cooldown key:

- `eventType|entityId|routeOwner`

Rules:

- Duplicate `syncKey` events are suppressed immediately.
- Non-critical signals are suppressed during cooldown windows.
- Critical signals bypass cooldown by default.
- Dispatch guard: `dispatch-task.sh` reuses the existing active task for a `--sync-key` instead of creating another registry/inbox entry.
- Review-intent guard: for `source=review-intent`, dispatch also reuses existing `completed`/`archived` tasks for the same `sync-key` to prevent recreate-close churn while still allowing redispatch after `failed` outcomes.

Configurable windows:

- `cooldown_info_minutes` (default `120`)
- `cooldown_warn_minutes` (default `60`)
- `cooldown_critical_minutes` (default `0`)

Clockify info policy (backlog shaping):

- Low-severity (`info|warn`) Clockify signals are non-actionable telemetry.
- Visibility window: keep Clockify info signals in active TeamForge slices for `clockify_info_active_days` (default `14` days) using one representative signal per `eventType/day/owner`.
- Daily collapse: additional same-day duplicates are suppressed with `clockify_daily_aggregate_duplicate`.
- Retention suppressor: signals older than the active window are suppressed with `clockify_info_retention_window`.
- Queue hygiene: TeamForge sync auto-archives active low-severity Clockify tasks in `task-registry.json` and annotates `sync-state.json` (`clockifyPolicy` + per-sync-key `actions` archive fields), preserving auditability while removing operator queue noise.
- Registry reconciliation: TeamForge sync also auto-runs `task-registry.sh reconcile-inbox` (non-dry-run) to close active registry tasks (`pending|in_progress|blocked`) that inbox owners already moved to `## Processed`, using `Task-ID`, processed `Sync-Key`, and safe duplicate `review-intent` sync-key matching.
- Reconciliation reporting: `task-registry.sh reconcile-inbox` reports a unique reconciled-task total; per-lane counters (`inbox`, `sync_key_inbox`, `duplicate_review_intent`) are debug breakdowns and can overlap for the same task.
- High-severity (`critical`) Clockify signals are unaffected and continue through normal dispatch/cooldown paths.

Suppression counters are persisted in TeamForge sync state and emitted in health metrics.

## Role-Specific Slices

Generated slice files:

- `.thoughtseed/teamforge/slices/jarvis.json`
- `.thoughtseed/teamforge/slices/clawd.json`
- `.thoughtseed/teamforge/slices/sentinel.json`
- `.thoughtseed/teamforge/slices/sage.json`

Overlap policy:

- A signal may appear in multiple role slices.
- `routeOwner` remains the canonical dispatch owner.
- Missing role slice fallback is always `jarvis`.

## Prompt Injection

`scripts/agent-prompt-assembler.sh`:

- Loads only the current role's slice (`jarvis|clawd|sentinel|sage`).
- Falls back to `jarvis` slice if role-specific slice is missing.
- Applies prompt guardrails:
  - `TEAMFORGE_PROMPT_MAX_ITEMS` (default `8`)
  - `TEAMFORGE_PROMPT_MAX_CHARS` (default `6000`)

## Health Metrics and Alerts

Health artifact:

- `.thoughtseed/teamforge/health.json`

Metrics include:

- new/skipped/suppressed/dispatched/errors
- lag (`projectionLagSeconds`, `maxSourceLagSeconds`, per-source lag)
- coverage ratio for expected sources (`clockify`, `huly`, `slack`)
- quality score and finding counts
- outcome statistics (`resolved|partial|no-change|regressed`)

Default warning thresholds:

- `health_max_lag_warn_seconds: 3600`
- `health_failure_rate_warn: 0.20`
- `health_min_coverage_warn: 0.66`

Alert semantics:

- `failureRateWarning` is current-cycle only (`errors > 0`); historical `failureRate` remains a trend metric.
- Health output also emits `failureRateCurrent` (0/1 per cycle) and `failureRateScope="historical_lifetime_runs"` to disambiguate current vs trend semantics.
- `teamforge-sync.sh status` backfills `failureRateCurrent` and `failureRateScope` defaults for legacy snapshots that predate these fields.
- `teamforge-sync.sh status` now also accepts snake_case `failure_rate` for trend-metric backfill before `metrics.runs` ratio fallback.
- `teamforge-sync.sh status` now also accepts snake_case run counters (`total_runs`, `failed_runs`) within `metrics.runs` when deriving trend `failureRate` fallback.
- `teamforge-sync.sh status` now also accepts camelCase run counters (`totalRuns`, `failedRuns`) within `metrics.runs` when deriving trend `failureRate` fallback.
- `teamforge-sync.sh status` now also accepts root-level snake_case `generated_at` before emitting canonical `generatedAt`.
- `teamforge-sync.sh status` now also accepts snake_case error counters (`error_count`, `errors_count`) before emitting canonical `errors` and evaluating current-cycle failure alerts.
- `teamforge-sync.sh status` now also accepts camelCase error counters (`errorCount`, `errorsCount`) before emitting canonical `errors` and evaluating current-cycle failure alerts.
- `teamforge-sync.sh status` now also accepts snake_case `coverage_ratio` before computing derived ratio from expected/seen source overlap.
- `teamforge-sync.sh status` now also accepts camelCase `coverageRatio` before computing derived ratio from expected/seen source overlap.
- `teamforge-sync.sh status` now also accepts evaluated-flag aliases (`is_evaluated`, `coverage_evaluated`) before falling back to `newSignals > 0` coverage-evaluation semantics.
- `teamforge-sync.sh status` now also accepts camelCase evaluated-flag aliases (`isEvaluated`, `coverageEvaluated`) before falling back to `newSignals > 0` coverage-evaluation semantics.
- `teamforge-sync.sh status` now also accepts snake_case `lag_sources` as the lag source-array key before canonical lag-source normalization and max-lag derivation.
- `teamforge-sync.sh status` now also accepts camelCase `lagSources` as the lag source-array key before canonical lag-source normalization and max-lag derivation.
- `teamforge-sync.sh status` now also accepts quality score aliases (`quality_score`, `qualityScore`) before deriving weighted quality score defaults.
- `teamforge-sync.sh status` now also accepts object-map `quality.findingsByType` payloads (type->count dictionaries), coercing them into canonical `{type,count}` arrays before finding count and weighted score normalization.
- `teamforge-sync.sh status` now also falls back to root-level `runs` when `metrics.runs` is absent, preserving historical `failureRate` derivation for legacy snapshot layouts.
- `teamforge-sync.sh status` now also falls back to root-level `lag` when `metrics.lag` is absent, preserving legacy lag projection/source metadata and max-lag derivation.
- `teamforge-sync.sh status` now also falls back to root-level `coverage` when `metrics.coverage` is absent, preserving legacy expected/seen source sets and explicit coverage-ratio semantics.
- `teamforge-sync.sh status` now also falls back to root-level `quality` when `metrics.quality` is absent, preserving legacy quality score/finding payloads.
- `teamforge-sync.sh status` now also falls back to root-level `outcomes` when `metrics.outcomes` is absent, preserving legacy outcome telemetry and derived validated-signal totals.
- `teamforge-sync.sh status` now also falls back to root-level failure-rate fields (`failureRate|failure_rate`, `failureRateCurrent|failure_rate_current`, `failureRateScope|failure_rate_scope`) when `metrics.*` is absent, preserving legacy trend/current/scope semantics.
- `teamforge-sync.sh status` now also falls back to root-level core counters (`newSignals|new_signals`, `skippedSignals|skipped_signals`, `suppressedSignals|suppressed_signals`, `dispatchedSignals|dispatched_signals`, and error aliases) when `metrics.*` is absent, preserving canonical counters and current-cycle failure semantics.
- `teamforge-sync.sh status` now also falls back to root-level alert keys (`maxLagWarning|max_lag_warning`, `failureRateWarning|failure_rate_warning`, `coverageWarning|coverage_warning`) when `.alerts` is absent, preserving explicit legacy alert override semantics.
- `teamforge-sync.sh status` now coerces root `metrics` and `alerts` containers to objects before field lookup, preventing jq indexing failures when legacy snapshots provide scalar/array container values.
- `teamforge-sync.sh status` now enforces object-only semantics for `metrics` sub-containers (`lag`, `coverage`, `quality`, `outcomes`, `runs`), ignoring malformed scalar/array values and falling back to root object variants before field indexing.
- `teamforge-sync.sh status` now guards root payload shape by coercing non-object health snapshots (scalar/array JSON) to `{}` before normalization, emitting canonical defaults instead of crashing.
- `teamforge-sync.sh status` now enforces array-only lag source containers before `map` iteration; malformed scalar/object `lag.sources` values are coerced to `[]` to avoid jq iteration failures.
- `teamforge-sync.sh status` now preserves scalar lag source containers (`string|number|boolean`) as single canonical source rows (wrapped before row normalization), retaining legacy source identifiers while keeping non-array/object iteration safety.
- `teamforge-sync.sh status` now also preserves object-shaped lag source containers (single source objects) as one canonical source row before normalization, retaining legacy source metadata and derived max-lag semantics instead of dropping non-array containers.
- `teamforge-sync.sh status` now also expands source-keyed lag object maps (for example `{clockify:{...}, huly:11}`) into canonical per-source lag rows before normalization, preserving per-source metadata and derived max-lag behavior.
- `teamforge-sync.sh status` now also unwraps nested object-wrapped lag source payloads (`{sources: ...}`), normalizing nested array/scalar/object forms into canonical lag rows before max-lag derivation.
- `teamforge-sync.sh status` now also filters explicit `false` boolean entries when expanding lag source object maps, avoiding placeholder null-lag rows for sources explicitly marked inactive in legacy flag-style payloads.
- `teamforge-sync.sh status` now also drops explicit `false` boolean scalar rows in lag source arrays, preventing inactive-source flags from surfacing as placeholder canonical source rows.
- `teamforge-sync.sh status` now ignores boolean scalar rows in lag source arrays entirely (`true|false`), so flag-only legacy entries do not surface as canonical lag sources.
- `teamforge-sync.sh status` now derives fallback `maxSourceLagSeconds` only from lag rows with non-null canonical `source`, so malformed/source-less rows cannot inflate max-lag status/alerts.
- `teamforge-sync.sh status` now catches invalid-JSON health snapshot parse failures and emits canonical default status payloads instead of failing command execution.
- `teamforge-sync.sh status` now also emits that same canonical default JSON payload when the health snapshot file is missing, preserving machine-readable status semantics before first sync.
- `teamforge-sync.sh status` now accepts scalar coverage source containers (`expectedSources|expected_sources`, `seenSources|seen_sources`) as one-item source sets before canonicalization and ratio derivation.
- `teamforge-sync.sh status` now ignores scalar boolean coverage source containers (`true|false`) in both direct and nested (`{sources: ...}`) forms, preventing phantom `"true"`/`"false"` canonical source tokens.
- `teamforge-sync.sh status` now also filters boolean/null entries inside direct coverage source arrays before canonicalization, preventing boolean source-token leakage from array payloads.
- `teamforge-sync.sh status` now extracts valid `.source` scalar values from object entries within coverage source arrays, dropping invalid object rows instead of stringifying object payloads into source tokens.
- `teamforge-sync.sh status` now restricts coverage source-array object extraction to explicit `.sources`/`.source` payloads only; unsupported object rows are ignored instead of falling back to generic key extraction, preventing metadata-key leakage (for example `"note"`) into canonical source sets.
- `teamforge-sync.sh status` now also accepts object-shaped coverage source containers for `expectedSources|expected_sources` and `seenSources|seen_sources`, extracting source keys (or explicit `.source`) into canonical source sets before ratio derivation.
- `teamforge-sync.sh status` now filters object-container `.source` values to string/number types only; boolean/null/non-scalar `.source` payloads are ignored to prevent phantom source tokens.
- `teamforge-sync.sh status` now falls back to `.sources` when `.source` is present but invalid in coverage object containers, preserving valid nested source sets and avoiding phantom `"source"` key emission.
- `teamforge-sync.sh status` now prefers non-empty `.sources` sets over `.source` when both are present in coverage object containers, preserving multi-source payload fidelity.
- `teamforge-sync.sh status` now also unwraps nested object-wrapped coverage source payloads (`{sources: ...}`) for `expectedSources|expected_sources` and `seenSources|seen_sources`, normalizing nested array/scalar/object forms before ratio derivation.
- `teamforge-sync.sh status` now normalizes invalid nested coverage wrapper payloads (`{sources: null}` and other unsupported nested types) to `[]` instead of falling back to wrapper keys, preventing phantom `"sources"` entries in canonical source sets.
- `teamforge-sync.sh status` now also applies scalar truthy filtering when extracting source keys from object-map coverage source sets, so explicitly false map entries are not miscounted as covered sources.
- `teamforge-sync.sh status` now preserves unknown scalar labels when extracting object-map coverage source keys (excluding only explicit false/null values), so legacy labels like `"enabled"`/`"active"` are retained in canonical source sets instead of being dropped.
- `teamforge-sync.sh status` now evaluates object-map coverage source entries per key (including mixed scalar + object maps), so explicit false/null scalar flags are still filtered even when sibling entries are non-scalar.
- `teamforge-sync.sh status` now treats blank-string scalar map values as missing during object-map source extraction, preventing whitespace-only placeholders from being counted as canonical source keys.
- `teamforge-sync.sh status` now normalizes `failureRateCurrent` with shared boolean coercion (including string booleans and numeric strings), falling back to `errors > 0` only when missing/unusable.
- `teamforge-sync.sh status` now also accepts snake_case failure-rate keys (`failure_rate_current`, `failure_rate_scope`) before emitting canonical camelCase status fields.
- `teamforge-sync.sh status` now also accepts snake_case core counters (`new_signals`, `skipped_signals`, `suppressed_signals`, `dispatched_signals`) before emitting canonical camelCase counter fields.
- `teamforge-sync.sh status` now also accepts snake_case lag keys (`projection_lag_seconds`, `max_source_lag_seconds`, `last_sync_at`, `lag_seconds`) before emitting canonical camelCase lag fields.
- `teamforge-sync.sh status` now also accepts snake_case quality keys (`findings_by_type`, `finding_count`) before emitting canonical camelCase quality fields.
- Boolean precedence now preserves explicit `false` values for `failureRateCurrent` and `coverage.evaluated` (null-only fallback), preventing fallback logic from overriding intentional false payloads.
- `teamforge-sync.sh status` also normalizes legacy/missing coverage objects with defaults for `expectedSources`, `seenSources`, `evaluated`, and `ratio`.
- Coverage normalization now also accepts snake_case source keys (`expected_sources`, `seen_sources`) from legacy payloads before emitting canonical camelCase coverage fields.
- For legacy coverage marked as evaluated but missing `ratio`, `status` computes ratio from expected-vs-seen source overlap (with deduped `seenSources`).
- For snapshots where `evaluated=false`, `status` forces `ratio=null` even if stale legacy ratio values are present.
- `teamforge-sync.sh status` also backfills `alerts` fields (`maxLagWarning`, `failureRateWarning`, `coverageWarning`) when absent, using normalized metrics and configured warning thresholds.
- `teamforge-sync.sh status` now also normalizes legacy `quality`/`outcomes` fields: canonical `findingsByType` objects (`{type,count}`), backfilled `findingCount`/`score`, deterministic outcomes defaults (`resolved|partial|noChange|regressed|validatedSignals|avgTimeToResolutionSeconds|recurrenceSignals`), and `failureRate` fallback from `metrics.runs` when absent.
- Outcomes backfill now also supports snake_case aliases (`no_change`, `avg_time_to_resolution_seconds`, `recurrence_signals`, `validated_signals`) in legacy snapshots before emitting canonical outcomes keys.
- `teamforge-sync.sh status` now canonicalizes `quality.findingsByType.type` tokens to trimmed lowercase strings (empty -> `unknown`) before grouping and weighted score computation, preventing case/whitespace drift from bypassing canonical finding weights.
- `teamforge-sync.sh status` now normalizes sparse legacy core counters (`newSignals|skippedSignals|suppressedSignals|dispatchedSignals|errors`) to numeric defaults and canonicalizes `lag` (`projectionLagSeconds`, normalized sources, derived `maxSourceLagSeconds` from source lag values when missing) before evaluating lag/failure alert fallbacks.
- `teamforge-sync.sh status` also coerces string numeric values and clamps invalid ranges across these normalized metrics (quality score/count, failure rates, outcomes numerics), preventing malformed legacy snapshots from leaking out-of-range or type-inconsistent values.
- `teamforge-sync.sh status` now canonicalizes mixed-type coverage source lists (`expectedSources`, `seenSources`) into deduped non-empty string sets and coerces legacy `coverage.evaluated` value types (boolean/number/string) before ratio and coverage-warning evaluation.
- `teamforge-sync.sh status` now also canonicalizes those coverage source sets to trimmed lowercase strings before dedupe, preventing case/whitespace drift in legacy snapshots from producing false coverage gaps.
- `teamforge-sync.sh status` now coerces and clamps legacy `coverage.ratio` values to numeric `[0,1]` when evaluated, preventing malformed ratio payloads from surfacing out-of-range values.
- `teamforge-sync.sh status` now also coerces alert fields (`maxLagWarning`, `failureRateWarning`, `coverageWarning`) from legacy string/number forms into booleans, using computed alert defaults only when alert fields are absent/unusable.
- Alert normalization now also accepts snake_case alert keys (`max_lag_warning`, `failure_rate_warning`, `coverage_warning`) and preserves explicit boolean `false` values during precedence selection.
- `teamforge-sync.sh status` now treats unknown legacy boolean strings as unusable and falls back to computed defaults (rather than forcing false), while trimming whitespace for recognized boolean tokens; this applies to alert fields and `coverage.evaluated`.
- Boolean normalization now also parses numeric strings before token matching (for example `"3"` -> `true`), improving compatibility with legacy numeric-like string payloads.
- `teamforge-sync.sh status` now normalizes `failureRateScope` into a trimmed non-empty string, defaulting to `"historical_lifetime_runs"` for malformed/non-string legacy values.
- `teamforge-sync.sh status` now also lowercases `failureRateScope` after trimming, ensuring mixed-case legacy scope values normalize to canonical tokens.
- `teamforge-sync.sh status` now normalizes lag payload field types and ranges: source scalars are emitted as stable string/null values, lag numerics are coerced to numeric/null, and negative lag values are clamped to `0`.
- `teamforge-sync.sh status` now canonicalizes lag `source` labels to trimmed lowercase tokens and trims lag text metadata (`entity`, `lastSyncAt`), preventing case/whitespace drift from fragmenting lag source rows.
- `teamforge-sync.sh status` now supports scalar rows in legacy `lag.sources` arrays, coercing them into canonical source records rather than failing on non-object entries.
- `coverageWarning` is evaluated only when `newSignals > 0`.
- No-new-signal cycles set `metrics.coverage.evaluated=false` and `metrics.coverage.ratio=null` (coverage not assessed).
- No-new-signal cycles emit empty quality findings and `quality.score = 100` to avoid replay-only noise.

## Data Quality Findings and Remediation

Structured findings output:

- `.thoughtseed/teamforge/quality-findings.json`

Finding types:

- `orphan_owner`: owner hint missing and routing fell to fallback.
- `stale_mapping`: actor IDs exist but owner hint is empty.
- `timestamp_drift`: `detectedAt` and `occurredAt` drift exceeds threshold.

Each finding includes remediation guidance in-line.

Quality scoring semantics:

- Sync-path quality findings are evaluated for actionable/new signals only.
- Replay-only skipped/suppressed batches do not penalize score.

## Closed-Loop Outcome Tracking

Dispatch linkage:

- `dispatch-task.sh` and `task-registry.sh` persist `source_sync_key`.

Outcome states:

- `resolved`, `partial`, `no-change`, `regressed`

Derived metrics:

- average time-to-resolution (seconds)
- recurrence count (resolved signals seen again in later syncs)
- validated signal totals

These metrics are persisted into TeamForge sync state and health output for automation tuning.
