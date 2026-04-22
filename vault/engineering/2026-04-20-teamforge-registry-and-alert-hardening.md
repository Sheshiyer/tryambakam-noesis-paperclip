# TeamForge Registry and Alert Hardening

Date: 2026-04-20  
Owner: CLAWD

## Scope

Harden TeamForge task-state hygiene and health signal quality after recovery-era backlog drift:

- eliminate stale active tasks (`pending|in_progress|blocked`) that were already processed in agent inboxes
- keep replay/no-new-signal cycles from degrading health/quality status

## Changes

Updated:

- `scripts/task-registry.sh`
- `scripts/teamforge-sync.sh`
- `scripts/dispatch-task.sh`
- `tests/test_task_registry_reconcile_inbox.sh`
- `tests/test_teamforge_reconcile_inbox_hook.sh`
- `tests/test_dispatch_task_sync_key_dedupe.sh`
- `tests/test_teamforge_clockify_policy.sh`

### Registry reconciliation

`task-registry.sh reconcile-inbox` now reconciles active registry records via:

1. direct processed `Task-ID` matches from `agents/*/INBOX.md`
2. processed `Sync-Key` matches for `review-intent` lanes
3. duplicate `review-intent` `source_sync_key` records where a completed/archived peer already exists

TeamForge sync now auto-runs this reconciliation in non-dry-run mode before outcome aggregation.
Reconciliation reporting now emits a unique task total so overlap across matching lanes (Task-ID + Sync-Key + duplicate lineage) does not inflate the headline count.

### Dispatch sync-key dedupe

`dispatch-task.sh` now checks for active tasks by `--sync-key` before creating a new task:

- if an active task exists, dispatch returns that existing task id and skips registry/inbox writes
- this prevents repeated pending inbox entries for recurring identical review-intent signals
- for `source=review-intent`, dispatch reuses existing `completed`/`archived` tasks for the same sync key, preventing recreate-close churn when the signal has not changed while still allowing redispatch after `failed` runs

### Health/quality alert hardening

- `failureRateWarning` now reflects current-cycle execution errors only (`errors > 0`).
- Health metrics now include `failureRateCurrent` (0/1 for current cycle) plus `failureRateScope="historical_lifetime_runs"` alongside historical `failureRate`.
- `teamforge-sync.sh status` backfills these new failure fields for legacy health snapshots to avoid null outputs during schema transition.
- Failure-rate trend normalization now also accepts snake_case `failure_rate` before `metrics.runs` fallback derivation.
- Failure-rate fallback now also accepts snake_case run counters (`total_runs`, `failed_runs`) within `metrics.runs`.
- Failure-rate fallback now also accepts camelCase run counters (`totalRuns`, `failedRuns`) within `metrics.runs`.
- Root timestamp normalization now also accepts snake_case `generated_at` before emitting canonical `generatedAt`.
- Error normalization now also accepts snake_case error counters (`error_count`, `errors_count`) before evaluating current-cycle failure semantics.
- Error normalization now also accepts camelCase error counters (`errorCount`, `errorsCount`) before evaluating current-cycle failure semantics.
- Coverage ratio normalization now also accepts snake_case `coverage_ratio` before deriving ratio from expected/seen overlap.
- Coverage ratio normalization now also accepts camelCase `coverageRatio` before deriving ratio from expected/seen overlap.
- Coverage evaluation normalization now also accepts legacy aliases (`is_evaluated`, `coverage_evaluated`) before applying fallback evaluation semantics.
- Coverage evaluation normalization now also accepts camelCase legacy aliases (`isEvaluated`, `coverageEvaluated`) before applying fallback evaluation semantics.
- Lag source-array normalization now also accepts snake_case `lag_sources` before canonical lag-source processing and max-lag derivation.
- Lag source-array normalization now also accepts camelCase `lagSources` before canonical lag-source processing and max-lag derivation.
- Quality score normalization now also accepts legacy score aliases (`quality_score`, `qualityScore`) before weighted quality fallback derivation.
- Quality findings normalization now also accepts object-map `findingsByType` payloads (type->count dictionaries), coercing them into canonical `{type,count}` arrays before finding-count and weighted-score derivation.
- Failure-rate run fallback now also reads root-level `runs` when `metrics.runs` is absent, preserving historical trend derivation for legacy snapshot layouts.
- Lag fallback now also reads root-level `lag` when `metrics.lag` is absent, preserving legacy lag projection/source metadata and max-lag derivation.
- Coverage fallback now also reads root-level `coverage` when `metrics.coverage` is absent, preserving legacy expected/seen source sets and explicit coverage-ratio semantics.
- Quality fallback now also reads root-level `quality` when `metrics.quality` is absent, preserving legacy quality score/finding payloads.
- Outcomes fallback now also reads root-level `outcomes` when `metrics.outcomes` is absent, preserving legacy outcome telemetry and derived validated-signal totals.
- Failure-rate field fallback now also reads root-level failure fields (`failureRate|failure_rate`, `failureRateCurrent|failure_rate_current`, `failureRateScope|failure_rate_scope`) when `metrics.*` fields are absent, preserving legacy trend/current/scope semantics.
- Core counter fallback now also reads root-level counter fields (`newSignals|new_signals`, `skippedSignals|skipped_signals`, `suppressedSignals|suppressed_signals`, `dispatchedSignals|dispatched_signals`, and error aliases) when `metrics.*` fields are absent, preserving canonical counters and current-cycle failure semantics.
- Alert fallback now also reads root-level alert keys (`maxLagWarning|max_lag_warning`, `failureRateWarning|failure_rate_warning`, `coverageWarning|coverage_warning`) when `.alerts` is absent, preserving explicit legacy alert override semantics.
- Root container hardening now coerces `metrics` and `alerts` to object-only containers before field lookup, preventing jq indexing crashes when legacy snapshots provide scalar/array container values.
- Sub-container hardening now also enforces object-only selection for `metrics.lag|coverage|quality|outcomes|runs`, falling back to root object variants when `metrics.*` fields are malformed scalars/arrays.
- Root payload hardening now also coerces non-object health snapshot payloads (scalar/array JSON) to `{}` before normalization, so `status` emits canonical defaults rather than failing on object indexing.
- Lag source-container hardening now requires array-shaped `lag.sources|lag_sources|lagSources` containers before map iteration; malformed scalar/object containers normalize to `[]` instead of throwing jq iteration errors.
- Lag source-container compatibility now preserves scalar `lag.sources|lag_sources|lagSources` containers (`string|number|boolean`) as single canonical source rows (wrapping before row normalization), retaining explicit legacy source identifiers while still preventing non-array iteration failures.
- Lag source-container compatibility now also preserves single-object `lag.sources|lag_sources|lagSources` containers by wrapping them as one-item source arrays before row normalization, retaining legacy source metadata and max-lag derivation when snapshots encode one source as an object instead of an array.
- Lag source-container compatibility now also expands source-keyed lag object maps (`{sourceKey: rowOrLag}`) into canonical per-source rows before normalization, preserving per-source lag metadata and correct derived `maxSourceLagSeconds` semantics.
- Lag source-container compatibility now also unwraps nested object-wrapped lag payloads (`{sources: ...}`), normalizing nested array/scalar/object forms into canonical lag rows before max-lag derivation.
- Lag source-container compatibility now also filters explicit boolean `false` entries during object-map expansion, preventing placeholder source rows for sources marked inactive in legacy flag-style lag maps.
- Lag source-array compatibility now also drops explicit boolean `false` scalar rows, preventing inactive-source flags from appearing as placeholder canonical lag-source rows.
- Lag source-array compatibility now ignores boolean scalar rows altogether (`true|false`), preventing flag-only legacy array entries from appearing as canonical lag sources.
- Max-lag fallback compatibility now derives `maxSourceLagSeconds` only from normalized lag rows with non-null canonical `source`, preventing malformed/source-less rows from inflating max-lag status/alerts.
- Invalid-JSON hardening now catches health snapshot parse failures in `status` and emits a canonical default payload, preventing malformed snapshot content from failing operator status commands.
- Missing-snapshot hardening now also emits that canonical default payload when `health.json` is absent, keeping `status` machine-readable instead of returning plain text.
- Coverage source hardening now accepts scalar `expectedSources|expected_sources` and `seenSources|seen_sources` containers as one-item source sets before normalization/ratio derivation, preserving single-source legacy snapshot semantics.
- Coverage source hardening now ignores scalar boolean coverage source containers (`true|false`) in both direct and nested (`{sources: ...}`) forms, preventing phantom `"true"`/`"false"` canonical source tokens.
- Coverage source hardening now also filters boolean/null entries within direct coverage source arrays before canonicalization, preventing boolean source-token leakage from array payloads.
- Coverage source hardening now also extracts valid `.source` scalar values from object entries within coverage source arrays, dropping invalid object rows instead of stringifying object payloads into source tokens.
- Coverage source hardening now also accepts object-shaped `expectedSources|expected_sources` and `seenSources|seen_sources` containers, extracting source keys (or explicit `.source`) into canonical source sets before normalization/ratio derivation.
- Coverage source hardening now also filters object-container `.source` values to string/number types only, ignoring boolean/null/non-scalar `.source` payloads to prevent phantom source tokens.
- Coverage source hardening now also falls back to `.sources` when `.source` is present but invalid, preserving valid nested source sets and preventing generic fallback from emitting phantom `"source"` keys.
- Coverage source hardening now also prefers non-empty `.sources` sets over `.source` when both are present, preventing multi-source payloads from collapsing to a single source token.
- Coverage source hardening now also restricts coverage array-object extraction to explicit `.sources`/`.source` payloads; unsupported object rows are ignored rather than passed through generic key extraction, preventing metadata-key leakage (for example `"note"`) into canonical source sets.
- Coverage source hardening now also unwraps nested object-wrapped source payloads (`{sources: ...}`) for `expectedSources|expected_sources` and `seenSources|seen_sources`, normalizing nested array/scalar/object forms before ratio derivation.
- Coverage source hardening now also normalizes invalid nested wrapper payloads (for example `{sources: null}`) to empty source sets rather than falling back to wrapper keys, preventing phantom `"sources"` canonical entries.
- Coverage source hardening now also applies scalar truthy filtering for object-map source extraction, so explicitly false map entries are not counted as covered sources during ratio/warning computation.
- Coverage source hardening now also preserves unknown scalar labels during object-map source extraction (excluding only explicit false/null values), so legacy non-standard source tokens like `"enabled"` and `"active"` are retained in canonical source sets.
- Coverage source hardening now also evaluates object-map entries per key for mixed maps (scalar + non-scalar), so explicit false/null scalar flags remain filtered even when sibling source entries are nested objects.
- Coverage source hardening now also excludes blank-string scalar flags during object-map source extraction, preventing whitespace-only placeholders from being treated as canonical source keys.
- Core counter normalization now also accepts snake_case legacy keys (`new_signals`, `skipped_signals`, `suppressed_signals`, `dispatched_signals`) before emitting canonical counter fields.
- Lag normalization now also accepts snake_case lag keys (`projection_lag_seconds`, `max_source_lag_seconds`, `last_sync_at`, `lag_seconds`) before emitting canonical camelCase lag fields.
- Quality normalization now also accepts snake_case quality keys (`findings_by_type`, `finding_count`) before emitting canonical camelCase quality fields.
- `status` now normalizes `failureRateCurrent` using shared boolean coercion (including string booleans and numeric strings), with fallback to `errors > 0` only when legacy values are absent/unusable.
- Failure-rate compatibility now also accepts snake_case legacy keys (`failure_rate_current`, `failure_rate_scope`) before emitting canonical camelCase status fields.
- Boolean precedence for `failureRateCurrent` now preserves explicit `false` values (null-only fallback), preventing `errors > 0` fallback from overriding intentional false payloads.
- `teamforge-sync.sh status` also normalizes legacy coverage fields (`expectedSources`, `seenSources`, `evaluated`, `ratio`) for snapshot compatibility.
- Coverage normalization now also accepts snake_case coverage source keys (`expected_sources`, `seen_sources`) before emitting canonical camelCase status output.
- For legacy evaluated coverage snapshots lacking `ratio`, `status` now derives ratio from expected/seen source overlap instead of defaulting to `0`.
- If a legacy snapshot has `evaluated=false` but a stale ratio value, `status` now forces `ratio=null` to keep non-evaluated semantics explicit.
- If legacy snapshots omit `alerts`, `status` now backfills `maxLagWarning`, `failureRateWarning`, and `coverageWarning` from normalized metrics + configured thresholds.
- `status` now also normalizes legacy `quality`/`outcomes` payloads and missing failure history fields: `findingsByType` is canonicalized to `{type,count}` objects (including legacy string arrays), `findingCount`/`score` are backfilled when absent, outcomes emit deterministic defaults, and `failureRate` is derived from `metrics.runs` when missing.
- Outcomes normalization now also accepts snake_case legacy aliases (`no_change`, `avg_time_to_resolution_seconds`, `recurrence_signals`, `validated_signals`) before emitting canonical outcomes fields.
- `status` now also canonicalizes `quality.findingsByType.type` tokens to trimmed lowercase strings (empty -> `unknown`) before grouping and weighted score calculation, so legacy case/whitespace drift cannot bypass canonical finding penalties.
- `status` now normalizes sparse core counters (`newSignals|skippedSignals|suppressedSignals|dispatchedSignals|errors`) and canonicalizes lag payloads (`sources`, derived `maxSourceLagSeconds`) before alert fallback evaluation, so sparse legacy snapshots cannot surface null metric scalars.
- Numeric normalization now coerces string-encoded legacy values and clamps invalid ranges across counters, lag values, quality/failure metrics, and outcomes so malformed snapshots cannot emit out-of-range values or mixed numeric/string types.
- Coverage normalization now coerces mixed-type source arrays into canonical string sets and normalizes `coverage.evaluated` legacy type variants (string/number/boolean) before ratio/coverage-warning evaluation.
- Coverage source-set normalization now also trims and lowercases source tokens before dedupe/ratio evaluation so legacy whitespace/case drift cannot produce false coverage deficits.
- Coverage ratio normalization now coerces legacy ratio values and clamps evaluated ratios to `[0,1]`, preventing out-of-range ratio payloads from distorting status/alerts.
- Alert normalization now coerces legacy typed alert values (`maxLagWarning`, `failureRateWarning`, `coverageWarning`) from string/number forms into booleans, using computed fallback semantics only when fields are absent/unusable.
- Alert normalization now also accepts snake_case alert keys (`max_lag_warning`, `failure_rate_warning`, `coverage_warning`) and preserves explicit false values during key-precedence selection.
- Boolean normalization now treats unknown legacy string values as unusable and falls back to computed semantics (instead of forcing false), while trimming whitespace for recognized boolean tokens; this applies to alert fields and `coverage.evaluated`.
- Boolean normalization now also parses numeric strings before token matching (for example `"3"` -> true) for better legacy compatibility.
- Failure-rate scope normalization now enforces a trimmed non-empty string contract for `failureRateScope`, defaulting malformed/non-string values to `"historical_lifetime_runs"`.
- Failure-rate scope normalization now also lowercases trimmed scope values so mixed-case legacy payloads normalize to canonical scope tokens.
- Lag normalization now coerces lag field types in status output and clamps negative lag numeric values (`projectionLagSeconds`, `maxSourceLagSeconds`, per-source `lagSeconds`) to `0`.
- Lag normalization now canonicalizes lag source labels as trimmed lowercase tokens and trims lag text metadata fields (`entity`, `lastSyncAt`) so legacy case/whitespace drift cannot fragment source rows in status output.
- Lag normalization now also accepts scalar rows in legacy `lag.sources` arrays by coercing them into canonical source records instead of assuming object-only entries.
- `coverageWarning` is only evaluated when `newSignals > 0`.
- No-new-signal cycles set `coverage.evaluated=false` and `coverage.ratio=null` (not assessed).
- If `newSignals == 0`, sync-path quality findings are forced empty and quality score is forced to `100`.

## Verification

Syntax:

- `bash -n scripts/teamforge-sync.sh`
- `bash -n scripts/task-registry.sh`
- `bash -n tests/test_task_registry_reconcile_inbox.sh`
- `bash -n tests/test_teamforge_reconcile_inbox_hook.sh`

Regression tests:

- `./tests/test_task_registry_reconcile_inbox.sh`
- `./tests/test_teamforge_reconcile_inbox_hook.sh`
- `./tests/test_teamforge_status_failure_rate_backfill.sh`
- `./tests/test_teamforge_clockify_policy.sh`
- `./tests/test_teamforge_export_cmd_manifest.sh`

Live checks:

- `./scripts/task-registry.sh reconcile-inbox`
- `./scripts/teamforge-sync.sh sync --no-dispatch`
- `./scripts/teamforge-sync.sh status`
- `./scripts/task-registry.sh stats`

## Outcome

- Registry queue drift resolved to zero pending in current window.
- Clean cycles no longer flap coverage/failure alerts.
- Replay-heavy cycles no longer collapse quality score when there is no actionable new signal.
