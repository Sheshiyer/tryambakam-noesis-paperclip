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

Configurable windows:

- `cooldown_info_minutes` (default `120`)
- `cooldown_warn_minutes` (default `60`)
- `cooldown_critical_minutes` (default `0`)

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

## Data Quality Findings and Remediation

Structured findings output:

- `.thoughtseed/teamforge/quality-findings.json`

Finding types:

- `orphan_owner`: owner hint missing and routing fell to fallback.
- `stale_mapping`: actor IDs exist but owner hint is empty.
- `timestamp_drift`: `detectedAt` and `occurredAt` drift exceeds threshold.

Each finding includes remediation guidance in-line.

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

