# CLAWD — Context

## Stack
- Skills: coding-agent, prepare-pr, review-pr, merge-pr
- Languages: TypeScript, Python, full-stack
- Infrastructure: Git, GitHub, CI/CD pipelines
- Models: openai/gpt-5.3-codex (primary), gemini-2.5-flash (fallback)

## Constraints
- Always write tests before implementation (TDD)
- Never push directly to main — use PR workflow
- SENTINEL must review all code changes
- Reports to JARVIS — development priorities set at org level
- Heartbeat cycle is 10 minutes
- Always restart pm2 with --update-env
- Database URLs must use localhost, not docker host names

## Known Pitfalls
_Auto-populated from loop cycle failures._

## Decision Pipeline
1. Read task from TASKS.md
2. Assess complexity and estimate time
3. Create branch, implement with tests
4. Submit PR for SENTINEL review
5. Address review feedback
6. Merge when approved
7. If blocked on infrastructure, log to CONTEXT.md and skip

- [2026-04-11T16:08:21Z] `paperclipai` client commands inside agent-runtime shells prefer `PAPERCLIP_API_KEY` over stored board credentials; board-only flows like `agent local-cli` will fail with `403 Board access required` unless run with board auth or with `PAPERCLIP_API_KEY` unset.
- [2026-04-11T18:06:10Z] Paperclip mutating endpoints reject synthetic `X-Paperclip-Run-Id` values with `activity_log_run_id_heartbeat_runs_id_fk`; reuse a real runtime run id (for example `PAPERCLIP_RUN_ID`) and include agent bearer auth for reliable status/comment writes.
- [2026-04-11T18:41:36Z] SENTINEL can still return `empty_output` on narrow QA prompts even with `max_step_timeout` reduced to `2m`; avoid repeated retries, run direct engineering verification when blocked, and escalate runtime remediation to JARVIS.
- [2026-04-11T19:01:08Z] For runtime-critical QA lanes, keep verification in Engineering whenever SENTINEL has 2 consecutive `empty_output` failures or no progress artifact within 60s; only re-delegate after the documented exit criteria in `vault/engineering/2026-04-11-sentinel-qa-runtime-remediation-package.md` are met.

- [2026-04-12T18:28:14Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-12T18:34:18Z] In host-supervisor mode on macOS, `./scripts/host-supervisor.sh status` can show `com.thoughtseed.*` as loaded while script-level PID checks still report `STOPPED` or `DEAD (stale PID)` because sandboxed `kill -0` probes return `operation not permitted`; use `launchctl print gui/$(id -u)/<label>` as the authoritative health signal.

- [2026-04-15T16:33:19Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T16:53:57Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T08:21:32Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T08:30:03Z] Drifted-runtime TeamForge and runtime-root fixtures can remain stale after the live runtime is healthy; verify `./scripts/runtime-root-guard.sh print`, `./scripts/teamforge-sync.sh status`, and `./scripts/teamforge-sync.sh sync --dry-run --no-dispatch` before treating fixture-based failures as current incidents.

- [2026-04-20T08:34:08Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T08:40:39Z] On macOS launchd, immediate `bootout -> bootstrap` during service restarts can intermittently throw `Bootstrap failed: 5: Input/output error`; restart logic should include bounded bootstrap retries with short backoff instead of hard-failing on the first attempt.

- [2026-04-20T09:01:08Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T09:11:52Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T08:57:07Z] TeamForge temp-repo tests must set `REPO_ROOT` explicitly (for example `REPO_ROOT=\"$TMP_ROOT\" .../teamforge-sync.sh`) because inherited shell state can point fixtures at the live repo manifest/state and silently invalidate the test.

- [2026-04-20T09:31:46Z] TeamForge health alerts should gate on actionable/new signals (and explicit run errors), not total fetched/suppressed records; otherwise recurring suppressed floods can keep `coverageWarning`/`failureRateWarning` noisy even when live sync is clean.

- [2026-04-20T09:44:05Z] TeamForge quality findings must also gate on actionable/new records (`isNew == true`), otherwise cursor replays of skipped/suppressed records can repeatedly trigger `timestamp_drift` penalties and collapse `quality.score` without any new work.

- [2026-04-20T09:57:02Z] For shell portability on macOS, avoid BSD-awk-incompatible `match(..., array)` captures in automation parsers; use `sub(...)` extraction when parsing `Task-ID` lines (used by `task-registry.sh reconcile-inbox`).

- [2026-04-20T10:11:22Z] TeamForge now auto-runs inbox reconciliation during non-dry-run sync; keep `--dry-run` side-effect-free by skipping reconciliation in dry mode so diagnostics do not mutate task state.

- [2026-04-20T10:25:44Z] Registry drift cleanup must reconcile processed `Sync-Key` values (not just `Task-ID`) for review-intent lanes, because some duplicate rediscoveries are represented in inbox history only by signal key lineage.

- [2026-04-20T10:28:49Z] `failureRateWarning` should represent current-cycle execution errors, not historical run ratios; keep historical failureRate as a metric, but avoid alert flapping on successful cycles with old failure history.

- [2026-04-20T10:42:51Z] Recurring review-intent signals can rapidly duplicate inbox backlog unless dispatch enforces active `sync-key` dedupe; guard dispatch before registry write and return existing task id when a pending/in-progress/blocked task already exists for that key.

- [2026-04-20T10:55:34Z] For `review-intent` lanes, active-only sync-key dedupe is insufficient if downstream reconciliation completes tasks quickly; dispatch should also reuse existing completed review-intent tasks for the same sync key to avoid recreate-close loops every cycle.

- [2026-04-20T11:00:26Z] Review-intent sync-key reuse must ignore `failed` history: only reuse completed/archived tasks, otherwise stale failures can suppress legitimate redispatch and hide unresolved intent work.

- [2026-04-20T11:13:25Z] `task-registry.sh reconcile-inbox` should close all stale active states (`pending`, `in_progress`, `blocked`) from processed inbox evidence; limiting reconciliation to `pending` leaves in-progress/blocked drift that still pollutes active operator lanes.

- [2026-04-20T11:38:23Z] Reconciliation lane counts can overlap for the same task (`Task-ID` + `Sync-Key` + duplicate lineage); report unique reconciled-task totals to avoid inflated headline metrics while keeping per-lane debug counters.

- [2026-04-20T11:52:14Z] Health coverage should be explicitly marked "not evaluated" on no-new-signal cycles (`coverage.evaluated=false`, `coverage.ratio=null`) so dashboards do not misread `ratio=0` as a real source-coverage failure.

- [2026-04-20T12:05:01Z] Health payloads should expose both historical and current-cycle failure semantics (`failureRate` trend + `failureRateCurrent` flag + explicit `failureRateScope`) to prevent alert triage from conflating long-run history with current-cycle health.

- [2026-04-20T14:04:04Z] `teamforge-sync.sh status` should backfill defaults when reading legacy health snapshots missing new failure fields (`failureRateCurrent`, `failureRateScope`) so dashboards never show ambiguous `null` values after schema evolution.

- [2026-04-20T14:16:49Z] `teamforge-sync.sh status` should also normalize legacy/missing coverage fields (`expectedSources`, `seenSources`, `evaluated`, `ratio`) so schema evolution cannot produce sparse/null coverage objects in operator views.

- [2026-04-20T14:29:27Z] When legacy coverage snapshots are marked/evaluated but missing `ratio`, `status` should derive ratio from normalized `expectedSources` vs `seenSources` (not force `0`), otherwise backfilled outputs understate partial source coverage.

- [2026-04-20T14:42:43Z] Coverage normalization precedence matters: if `evaluated=false`, `status` should force `ratio=null` even when a stale legacy ratio value exists; ratio values are meaningful only when evaluation is enabled.

- [2026-04-20T14:56:14Z] `status` should normalize alert fields for legacy snapshots too (`maxLagWarning`, `failureRateWarning`, `coverageWarning`) using current metrics/threshold defaults when `alerts` is missing, to avoid null/empty alert surfaces after schema drift.

- [2026-04-20T15:35:12Z] `teamforge-sync.sh status` should normalize legacy `quality` and `outcomes` shapes as well: coerce `findingsByType` to canonical `{type,count}` objects (including string-array legacy forms), backfill `findingCount`/`score` when absent, emit deterministic outcomes defaults, and derive `failureRate` from `runs` when the field is missing.

- [2026-04-20T15:49:26Z] `teamforge-sync.sh status` should also normalize legacy core counters and lag payloads: default missing counters to `0`, normalize lag sources, derive `maxSourceLagSeconds` from per-source `lagSeconds` when absent, and compute lag/failure alert fallbacks from these normalized values.

- [2026-04-20T16:03:52Z] `teamforge-sync.sh status` should coerce string-encoded numeric fields and clamp invalid ranges (for counters, lag values, quality/failure metrics, and outcomes) so malformed legacy snapshots cannot emit type-inconsistent or out-of-range values; wrap `tonumber?` bindings with null fallbacks before `as` to avoid empty jq pipelines.

- [2026-04-20T16:17:14Z] Coverage compatibility also needs canonical source-set and evaluated-type coercion: normalize mixed-type `expectedSources`/`seenSources` entries into non-empty strings, and treat legacy string/number evaluated values (`true|1|yes`) as booleans so ratio/coverage-warning semantics remain stable across schema drift.

- [2026-04-20T16:29:49Z] Coverage compatibility also requires ratio coercion/clamping: when `coverage.ratio` is present in legacy snapshots as a string or out-of-range number, normalize it to a numeric `[0,1]` value (for evaluated coverage) before downstream alert/status rendering.

- [2026-04-20T16:42:36Z] Alert compatibility needs explicit typed-bool coercion too: normalize `maxLagWarning`, `failureRateWarning`, and `coverageWarning` values from legacy string/number forms (`true|false|1|0|yes|no`) instead of passing through non-boolean payload types.

- [2026-04-20T16:56:06Z] `failureRateScope` should be normalized as well: trim whitespace and enforce a non-empty string contract, defaulting to `"historical_lifetime_runs"` when legacy snapshots provide malformed/non-string scope values.

- [2026-04-20T17:09:31Z] Lag compatibility should normalize field types and range too: coerce lag source scalars to stable string/null output and clamp negative lag numeric values (`projectionLagSeconds`, `maxSourceLagSeconds`, per-source `lagSeconds`) to `0` before alert evaluation.

- [2026-04-20T17:22:31Z] Legacy `lag.sources` may contain scalar rows (not only objects); `status` normalization should safely coerce scalar entries into canonical source records instead of indexing errors, while still deriving max lag from structured rows when available.

- [2026-04-20T17:37:13Z] Boolean compatibility in `status` should treat unknown legacy string values as unusable and fall back to computed defaults (instead of forcing false), while still trimming whitespace for recognized `true|false|1|0|yes|no` tokens; this applies to alert fields and `coverage.evaluated`.

- [2026-04-20T17:52:21Z] Coverage source-set compatibility should canonicalize legacy `expectedSources`/`seenSources` tokens as trimmed lowercase strings before dedupe/ratio checks so whitespace/case drift cannot trigger false coverage warnings.

- [2026-04-20T18:05:27Z] Quality finding compatibility should canonicalize `findingsByType.type` tokens as trimmed lowercase strings (empty -> `unknown`) before grouping and weighted scoring, otherwise legacy case/whitespace drift can under-penalize canonical finding types.

- [2026-04-20T18:18:18Z] Lag source compatibility should canonicalize `lag.sources[*].source` as trimmed lowercase tokens and trim textual lag metadata fields (`entity`, `lastSyncAt`) so legacy case/whitespace drift cannot fragment source rows in status views.

- [2026-04-20T18:30:42Z] Outcomes compatibility should accept legacy snake_case aliases (`no_change`, `avg_time_to_resolution_seconds`, `recurrence_signals`, `validated_signals`) during `status` backfill so historical snapshots do not silently lose outcome metrics.

- [2026-04-20T18:42:55Z] `failureRateScope` compatibility should normalize case as well (trim + lowercase) so mixed-case legacy scope values do not fragment analytics/grouping semantics.

- [2026-04-21T07:12:37Z] `failureRateCurrent` compatibility should use shared boolean coercion (including string booleans and numeric strings) with fallback to current-cycle errors, rather than numeric-only parsing, so legacy payloads cannot silently invert current-cycle failure semantics.

- [2026-04-21T07:25:18Z] Coverage compatibility should accept snake_case source keys (`expected_sources`, `seen_sources`) in addition to camelCase, so legacy snapshots do not silently revert to default coverage source sets during status backfill.

- [2026-04-21T07:39:16Z] jq `//` fallback drops explicit `false`; boolean field selection in `status` must use null-aware precedence so explicit false values (for alerts, `coverage.evaluated`, and `failureRateCurrent`) are preserved.

- [2026-04-21T07:54:12Z] Failure-rate compatibility should also accept snake_case legacy keys (`failure_rate_current`, `failure_rate_scope`) during `status` backfill so explicit failure-current flags and scope labels are not dropped when snapshots predate camelCase normalization.

- [2026-04-21T08:09:19Z] Failure-rate trend normalization should also accept snake_case `failure_rate` before falling back to `metrics.runs.failed/total`, otherwise legacy snapshots can silently override explicit historical failure values with derived ratios.

- [2026-04-21T08:22:43Z] Core counter normalization should also accept snake_case legacy metric keys (`new_signals`, `skipped_signals`, `suppressed_signals`, `dispatched_signals`) so legacy snapshots do not silently emit zeroed operational counters in `status`.

- [2026-04-21T08:36:19Z] Lag normalization should also accept snake_case legacy lag keys (`projection_lag_seconds`, `max_source_lag_seconds`, `last_sync_at`, `lag_seconds`) so status backfill preserves lag metrics/timestamps instead of dropping to null.

- [2026-04-21T08:50:07Z] Quality normalization should also accept snake_case legacy quality keys (`findings_by_type`, `finding_count`) so status backfill preserves quality findings/counts rather than defaulting to empty/derived values.

- [2026-04-21T09:03:11Z] Failure-rate fallback from `metrics.runs` should also accept snake_case run counters (`total_runs`, `failed_runs`) so legacy run-history payloads still derive correct historical `failureRate`.
- [2026-04-21T10:22:52Z] Failure-rate fallback from `metrics.runs` should also accept camelCase run counters (`totalRuns`, `failedRuns`) so pre-snake legacy run-history payloads still derive correct historical `failureRate` during status backfill.
- [2026-04-21T10:36:13Z] Error normalization in `status` should also accept camelCase error counters (`errorCount`, `errorsCount`) so legacy snapshots preserve current-cycle failure semantics (`failureRateCurrent`, `failureRateWarning`) during backfill.
- [2026-04-21T10:48:20Z] Coverage normalization in `status` should also accept camelCase `coverageRatio` so explicit legacy coverage ratios are preserved instead of always recomputing from expected/seen source overlap.
- [2026-04-21T11:00:46Z] Coverage evaluation normalization in `status` should also accept camelCase aliases (`isEvaluated`, `coverageEvaluated`) so explicit legacy not-evaluated payloads are preserved instead of falling back to `newSignals > 0`.
- [2026-04-21T11:12:53Z] Lag normalization in `status` should also accept camelCase `lagSources` as a source-array alias so legacy lag source rows are preserved for canonical source output and max-lag derivation.
- [2026-04-21T11:25:50Z] Quality normalization in `status` should also accept legacy score aliases (`quality_score`, `qualityScore`) so explicit historical quality scores are preserved instead of always recomputing weighted defaults.
- [2026-04-21T11:38:59Z] Quality normalization in `status` should also accept object-map `findingsByType` payloads (type->count dictionaries) so legacy quality finding counts and weighted score semantics are preserved during backfill.
- [2026-04-21T11:51:45Z] Failure-rate backfill in `status` should also fallback to root-level `runs` when `metrics.runs` is absent, so legacy snapshot layouts still derive historical failure-rate trend correctly.
- [2026-04-21T12:04:50Z] Lag normalization in `status` should also fallback to root-level `lag` when `metrics.lag` is absent, so legacy snapshots preserve lag projection/source metadata and max-lag derivation.
- [2026-04-21T12:18:04Z] Coverage normalization in `status` should also fallback to root-level `coverage` when `metrics.coverage` is absent, so legacy snapshots preserve expected/seen source sets and explicit coverage ratio semantics.
- [2026-04-21T12:31:05Z] Quality normalization in `status` should also fallback to root-level `quality` when `metrics.quality` is absent, so legacy snapshots preserve explicit quality score/finding payloads.
- [2026-04-21T12:43:52Z] Outcomes normalization in `status` should also fallback to root-level `outcomes` when `metrics.outcomes` is absent, so legacy snapshots preserve explicit outcome telemetry and derived validated-signal totals.
- [2026-04-21T12:58:30Z] Failure-rate normalization in `status` should also fallback to root-level failure fields (`failureRate|failure_rate`, `failureRateCurrent|failure_rate_current`, `failureRateScope|failure_rate_scope`) when `metrics.*` is absent, so legacy snapshots preserve explicit trend/current/scope semantics instead of defaulting to run/error-derived values.
- [2026-04-21T13:11:49Z] Core counter normalization in `status` should also fallback to root-level counter fields (`newSignals|new_signals`, `skippedSignals|skipped_signals`, `suppressedSignals|suppressed_signals`, `dispatchedSignals|dispatched_signals`, and error aliases) when `metrics.*` is absent, so legacy snapshots preserve canonical counter output and current-cycle failure alert semantics.
- [2026-04-21T13:24:57Z] Alert normalization in `status` should also fallback to root-level alert keys (`maxLagWarning|max_lag_warning`, `failureRateWarning|failure_rate_warning`, `coverageWarning|coverage_warning`) when `.alerts` is absent, so legacy snapshots preserve explicit alert override semantics instead of always using computed fallback alerts.
- [2026-04-21T13:38:07Z] `status` should coerce root `metrics` and `alerts` containers to objects before field lookup; legacy scalar/array containers otherwise trigger jq indexing errors and abort normalization.
- [2026-04-21T13:51:37Z] `status` should also enforce object-only semantics for `metrics` sub-containers (`lag`, `coverage`, `quality`, `outcomes`, `runs`): when `metrics.*` holds malformed scalar/array values, normalization must ignore those and fallback to root object variants before field indexing.
- [2026-04-21T14:04:43Z] `status` should also guard the root payload shape itself: if the health snapshot JSON is non-object (scalar/array), normalization must coerce to `{}` and emit canonical defaults instead of attempting object indexing.
- [2026-04-21T14:27:53Z] `status` lag normalization should enforce array-only source containers before `map` iteration; legacy scalar/object `lag.sources` values must coerce to `[]` to avoid jq iteration errors.
- [2026-04-21T16:06:57Z] Lag source-container hardening should preserve scalar `lag.sources` containers (`string|number|boolean`) as one canonical source row (wrapped as a single-item list before row coercion), rather than dropping them to `[]`; this keeps explicit legacy source identity while still preventing jq iteration crashes for malformed non-array containers.
- [2026-04-21T16:36:29Z] Lag source-container hardening should also preserve object-shaped `lag.sources` containers as one canonical source row (wrapping the object before row normalization), because legacy snapshots may serialize a single lag source as an object rather than an array; dropping object containers loses source metadata and max-lag derivation.
- [2026-04-21T16:57:48Z] Coverage source-set hardening should also preserve object-shaped `expectedSources|expected_sources` and `seenSources|seen_sources` containers by extracting source keys (or explicit `.source`) before canonicalization; legacy object-map source sets otherwise collapse to defaults/empty lists and silently skew coverage ratio and warning semantics.
- [2026-04-21T17:11:02Z] Lag source-set hardening should also expand source-keyed object maps (`{sourceKey: rowOrLag}`) into canonical source rows before normalization; treating the map as a single row loses per-source lag metadata and breaks derived `maxSourceLagSeconds` semantics.
- [2026-04-21T17:24:03Z] Coverage source-set hardening should also unwrap nested object payloads (`{sources: ...}`) for `expectedSources|expected_sources` and `seenSources|seen_sources`; without explicit nested-source extraction, legacy wrapped containers collapse to placeholder keys and skew coverage ratio/warning semantics.
- [2026-04-21T17:37:49Z] Lag source-set hardening should also unwrap nested object payloads (`lag.sources = {sources: ...}`) before row normalization; without explicit nested-source extraction, wrapped lag payloads degrade into placeholder rows and lose per-source lag metadata/max-lag derivation.
- [2026-04-21T17:51:39Z] Coverage object-map source extraction should filter scalar entries by truthiness (`true/false`, `1/0`, recognized boolean strings) before key selection; otherwise explicitly false map entries are incorrectly treated as covered sources and skew ratio/warning semantics.
- [2026-04-21T18:05:41Z] Lag object-map source expansion should also filter explicit boolean false entries (`source: false`) so legacy flag-style lag maps do not emit placeholder source rows with null lag values; keep numeric/string lag scalars and structured object rows intact for max-lag derivation.
- [2026-04-21T18:19:09Z] Lag scalar-array normalization should also drop explicit boolean `false` entries, because legacy lag arrays can encode inactive sources as flags; retaining them produces placeholder canonical rows that pollute source views without contributing lag metrics.
- [2026-04-21T18:32:38Z] Lag scalar-array normalization should ignore boolean scalar entries entirely (both `true` and `false`), because legacy flag-style lag arrays use booleans as activity markers rather than source identities; surfacing them as sources adds noise without actionable lag data.
- [2026-04-21T18:45:46Z] `maxSourceLagSeconds` fallback should derive only from normalized lag rows with valid canonical `source`; malformed/source-less lag rows may be retained for diagnostics but must not drive max-lag alert semantics.
- [2026-04-21T19:00:20Z] Coverage object-map source extraction should preserve unknown scalar labels (for example `"enabled"`, `"active"`) as included source keys and exclude only explicit false/null values; coercing unknown labels to false undercounts legacy source sets and skews derived coverage ratios.
- [2026-04-21T19:13:43Z] Coverage object-map extraction should evaluate entries per key (not all-or-nothing scalar branching) so mixed maps with nested object entries still filter explicit false/null scalar flags; otherwise keys like `"huly": false` leak into canonical sources whenever any sibling entry is non-scalar.
- [2026-04-21T19:26:07Z] Coverage object-map extraction should treat blank-string scalar values as missing (`null`) and exclude those keys; otherwise placeholder values like `"   "` are counted as covered sources and can inflate expected/seen source sets.
- [2026-04-21T19:39:01Z] Nested coverage wrapper extraction should not fallback to wrapper object keys when `sources` is invalid (`null`/unsupported type); invalid nested wrappers must normalize to empty source sets, otherwise `"sources"` can leak as a phantom canonical source key.
- [2026-04-21T19:52:28Z] Coverage source extraction should treat scalar booleans (`true|false`) as non-source control values in both direct and nested (`{sources: ...}`) containers; coercing them to source tokens creates phantom `"true"`/`"false"` sources and unstable ratio semantics.
- [2026-04-21T20:05:27Z] Coverage object containers with an explicit `.source` field should accept only string/number values; boolean/null/non-scalar `.source` payloads must normalize to empty lists to avoid phantom `"true"`/`"false"` source keys.
- [2026-04-21T20:19:52Z] Coverage object containers that include both `.source` and `.sources` should fallback to `.sources` when `.source` is invalid; otherwise generic key extraction can emit phantom `"source"` canonical tokens and suppress valid nested source sets.
- [2026-04-21T20:32:59Z] Coverage object containers that include both `.source` and `.sources` should prefer non-empty `.sources` sets over `.source` even when `.source` is valid, so multi-source payloads are not collapsed to one token.
- [2026-04-21T20:46:08Z] Direct coverage source arrays should also filter boolean/null entries before canonicalization; otherwise boolean values leak as `"true"`/`"false"` source tokens and skew expected/seen set semantics.
- [2026-04-22T09:09:41Z] Coverage source arrays containing object entries should extract only valid `.source` scalar values from each object; object rows should not be stringified into JSON-blob source tokens.
- [2026-04-21T14:58:26Z] `status` should also recover from invalid JSON parse errors in health snapshots by emitting canonical defaults instead of failing the command; malformed snapshot content should be treated as non-actionable telemetry corruption, not a hard runtime error.
- [2026-04-21T15:20:38Z] Missing health snapshots should also emit canonical JSON defaults (not human-only plain text) so operator tooling always receives machine-readable `status` output even before first sync.
- [2026-04-21T15:44:45Z] Coverage source normalization in `status` should accept scalar legacy source containers (`expectedSources|expected_sources`, `seenSources|seen_sources`) as one-item sets; otherwise single-source snapshots silently degrade to default source baselines and incorrect coverage ratios.

- [2026-04-21T09:15:47Z] Root timestamp normalization in `status` should also accept snake_case `generated_at` so legacy health snapshots preserve snapshot time in canonical `generatedAt` output.
- [2026-04-21T09:27:44Z] Error normalization in `status` should also accept snake_case error counters (`error_count`, `errors_count`) so fallback `failureRateCurrent` and `failureRateWarning` semantics remain correct for legacy payloads.
- [2026-04-21T09:41:01Z] Coverage normalization in `status` should also accept snake_case `coverage_ratio` so explicit legacy ratio payloads are preserved instead of always deriving ratio from expected/seen overlap.
- [2026-04-21T09:54:16Z] Coverage evaluation normalization should also accept legacy evaluated aliases (`is_evaluated`, `coverage_evaluated`) so explicit legacy not-evaluated states do not get overridden by `newSignals` fallback semantics.
- [2026-04-21T10:07:19Z] Lag normalization should also accept snake_case `lag_sources` as the source-array key so legacy lag source rows are not dropped during status backfill.
- [2026-04-21T09:18:30Z] `signal:teamforge_feed_down` can be stale when `.thoughtseed/teamforge/sync-state.json` carries heavy historical failure counts but live ingestion is healthy; verify `lastRunAt`, `lastError`, `latest-feed.json`, `health.json`, and a live `./scripts/teamforge-sync.sh sync --dry-run --no-dispatch` before treating it as an outage.

- [2026-04-20T15:15:00Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T15:37:26Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T17:29:04Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T17:39:21Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T17:50:38Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T18:23:19Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T18:33:36Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T07:20:28Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T07:34:02Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T07:45:55Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T07:55:58Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T08:07:41Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T08:20:39Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T08:31:50Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T08:45:51Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T08:56:26Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T09:07:30Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T09:22:31Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T09:33:26Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T09:55:53Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:06:50Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:19:45Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:26:58Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:36:59Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:48:16Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:59:15Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:09:20Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:19:26Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:31:05Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:42:08Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:53:23Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:04:24Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:15:42Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:26:45Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:38:27Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:49:37Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:59:49Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:09:53Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:20:00Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:30:02Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:40:03Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:50:07Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:01:07Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:34:51Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T15:00:51Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T15:24:18Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T15:47:45Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T16:08:26Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T16:36:44Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:00:06Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:10:58Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:22:09Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:32:44Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:43:47Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:54:33Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:05:42Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:16:29Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:27:18Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:38:06Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:49:34Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:00:18Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:11:20Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:22:05Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:34:32Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:45:10Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:56:09Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:06:43Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:17:47Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:28:23Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:39:23Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:50:03Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:11:24Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:21:35Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:25:03Z] Coverage-array normalization must not fall back to generic object-key extraction for rows lacking `.source`/`.sources`; otherwise metadata keys (for example `note`) leak into canonical source sets and falsely lower coverage ratios.

- [2026-04-22T09:54:28Z] Codex CLI 0.121+ can hard-fail agent cycles before prompt execution when user config stores `features.notify` as an array (`invalid type: sequence, expected a boolean`); loop-runner invocations must pass a compatibility override (`-c features.notify=true`) or equivalent env-based control to keep cycles runnable.

- [2026-04-22T10:02:37Z] Loop-runner PID files can drift when stale long-lived `run` processes survive manual restarts; when status and behavior disagree, verify with `ps -p <pid> -o command`, kill stale runners explicitly, and confirm fresh post-restart logs rather than trusting the PID file alone.

- [2026-04-22T10:17:38Z] On hosts with external supervision, `loop-runner.sh stop` may terminate duplicate/stale runners yet still report one surviving PID because the supervisor respawns the service; daemon control should surface this as a warning rather than falsely claiming a clean full stop.

- [2026-04-22T10:21:43Z] In long-running bash daemons, trapping `TERM`/`INT` to cleanup-only handlers swallows shutdown signals; signal traps must exit after cleanup, otherwise `kill` appears successful but the daemon continues running.

- [2026-04-22T09:32:00Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:42:09Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:52:35Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T10:07:13Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T10:30:13Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T10:41:34Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T10:56:24Z] In bash with `set -u`, associative arrays declared as `declare -A NAME` remain unbound when empty; any `${#NAME[@]}` / `"${!NAME[@]}"` expansion can crash zero-item paths. Use `declare -A NAME=()` for scheduler state maps that may legitimately be empty.

- [2026-04-22T10:56:24Z] Agent discovery loops over globbed directories should use `nullglob` (or explicit directory existence checks) to avoid phantom `*` entries and misleading `No MANIFEST.yaml for *` warnings in zero-agent harnesses.

- [2026-04-22T11:26:12Z] Large-agent loops can self-timeout when the prompt contract forces full `TASKS.md`/`INBOX.md` rewrites every cycle; allowing explicit `NO_CHANGES` markers for unchanged files eliminates unnecessary long-form outputs and restores fast idle-cycle completion.

- [2026-04-22T11:09:39Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T11:20:31Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T11:49:27Z] Marker-delimited write-back parsing is unsafe when update payload text contains delimiter tokens; base64-encoding update content per-file avoids delimiter collisions and preserves exact payload fidelity. Malformed write-back JSON should downgrade to explicit `invalid_json` cycle failures (context+heartbeat) instead of hard-exit crashes.
- [2026-04-22T12:06:46Z] Stderr structured-output recovery should validate recovered payload structure (expected FILE_UPDATE keys, no duplicates/unknowns, non-placeholder shapes) rather than matching exact prompt wording; prompt-text coupling is brittle across template edits and can admit false recoveries.
- [2026-04-22T12:21:54Z] `grep -A`/`awk` manifest parsing can silently miss quoted or re-ordered YAML values; path-based scalar parsing with normalized boolean handling is required for stable loop-runner config ingestion (`issues_to_inbox`, `heartbeat_reporting`, signal-lane flags, intervals, and timeouts).
- [2026-04-22T12:36:08Z] Agent prompt policy rendering must parse `MANIFEST.yaml` by dot-path instead of grep windows; quoted or re-ordered `loop.*` keys (timeout/failure policy/retry threshold) otherwise drift silently and can misguide cycle behavior.
- [2026-04-22T12:51:03Z] When loop-runner or prompt-assembler is staged into temp roots for regression tests, shared helper dependencies (for example `scripts/yaml-helpers.sh`) must be copied alongside the primary script or tests will fail with missing-helper startup errors.
- [2026-04-22T13:04:05Z] Shared YAML parser helpers need a single direct smoke test in addition to downstream integration tests; this catches parser regressions (quote/comment/hash handling) before they fan out into loop-runner/assembler failures.
- [2026-04-22T13:18:38Z] Temp-root regressions should use a shared fixture helper for script-copy/runtime-guard stubs; repeated inline setup across tests increases drift risk whenever core script dependencies change.
- [2026-04-22T13:25:08Z] Boolean normalization helpers must trim surrounding whitespace before evaluating truthy/falsey tokens; quoted manifest values like `" false "` otherwise bypass config gates (for example Paperclip cycle disable and signal-lane toggles).
- [2026-04-22T13:39:09Z] Temp-root registry/teamforge tests should stage scripts via `copy_scripts_from_repo` (not ad-hoc `cp` blocks) so future script dependency changes can be updated once in `tests/lib/fixture-helpers.sh` and stay consistent across suites.
- [2026-04-22T13:52:20Z] TeamForge regression suites (`clockify_policy`, `reconcile_inbox_hook`) should also source `tests/lib/fixture-helpers.sh`; keeping these high-churn tests on manual `cp` blocks increases drift risk whenever shared TeamForge script dependencies are renamed or added.
- [2026-04-22T14:06:02Z] Signal-lane regressions (`signal_lane_gating`, `paperclip_cycle_signal_lane`) should stage baseline scripts through `copy_scripts_from_repo` to keep orchestration test fixtures synchronized with shared script dependency changes.
- [2026-04-22T14:06:02Z] Runtime health checks can temporarily report `10/11` when a peer agent heartbeat is stale (for example `jarvis`) even if touched regression suites pass; treat as a runtime monitoring concern unless tied to the modified code paths.
- [2026-04-22T14:20:38Z] Write-back and TeamForge status compatibility regressions should also source `tests/lib/fixture-helpers.sh`; consolidating script staging there keeps low-level parser/compat suites aligned when core scripts move or gain dependencies.
- [2026-04-22T14:33:25Z] Shared fixture helpers should fail fast with explicit missing-source-script diagnostics; silent or opaque `cp` errors slow down triage when refactors rename scripts used by many temp-root regressions.
- [2026-04-22T14:46:17Z] Fixture helper APIs should also validate invocation shape (`source_repo`, `target_dir`, at least one script) and source scripts-directory presence before attempting copies; explicit guard failures produce faster triage than downstream `cp`/`set -u` noise.
- [2026-04-22T15:02:25Z] Temp-root regressions should use a shared `make_scripts_executable` helper after `copy_scripts_from_repo`; centralizing chmod logic keeps missing-target diagnostics consistent and removes repeated chmod loops from high-churn suites.
