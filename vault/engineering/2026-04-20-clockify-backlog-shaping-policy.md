# 2026-04-20 — Clockify Backlog Shaping Policy (TeamForge)

## Decision Applied

Leadership delegated `task-1776674844-a3f2` with policy:

1. Treat low-severity Clockify telemetry as informational (not operator work).
2. Keep active TeamForge visibility for 14 days.
3. Collapse duplicates into one aggregate per `eventType/day/owner`.
4. Auto-archive older/non-actionable Clockify queue items with audit traceability in `sync-state.json` and `task-registry.json`.
5. Preserve high-severity/non-Clockify behavior.

## Implementation

### `scripts/teamforge-sync.sh`

- Added `TEAMFORGE_CLOCKIFY_INFO_ACTIVE_DAYS` (manifest override: `teamforge.clockify_info_active_days`).
- Added per-run + cross-run Clockify daily collapse (`clockifyBucket`) and retention gating by day.
- Low-severity Clockify records are marked `dispatchEligible=false` (no operator task dispatch).
- Added aggregate materialization (`materialize_active_records`) so TeamForge slices/`latest-feed.json` expose one aggregate per day bucket.
- Added archival routine:
  - `apply_clockify_policy_archive_registry`
  - `update_clockify_policy_audit`
- Added/updated `clockifyPolicy` state fields for:
  - `dailySeen`
  - `lastRun` counters
  - cumulative `totals`
  - per-sync-key archive annotations under `actions`.

### `scripts/task-registry.sh`

- Added `archived` as a valid status.
- Metadata now tracks `.metadata.archived`.
- `stats` output includes archived count.

### Manifest + Contract Docs

- `manifest.yaml`: added `teamforge.clockify_info_active_days: 14`.
- `memory/teamforge-ops-feed.md`: documented Clockify flood-shaping behavior and suppression semantics.

### Tests

- Added/updated regression coverage:
  - `tests/test_teamforge_clockify_policy.sh`
  - verified existing `tests/test_teamforge_export_cmd_manifest.sh`

## Live Runtime Result

- Clockify backlog cleared from active queue:
  - `pending_clockify=0`
  - `archived_clockify=197`
- Registry now reports:
  - total: `210`
  - pending: `13` (all non-Clockify)
  - archived: `197`
- TeamForge health on last run:
  - `newSignals=0`, `errors=0`, `quality.score=100`

## High-Severity Visibility Guard

- Policy regression test confirms non-Clockify high-severity (`runtime.error`) still dispatches and remains visible with task linkage.
- Clockify aggregation does not change non-Clockify routing/priority paths.

## Recovery Note

During initial live rollout, a policy-blob edge case left `.thoughtseed/task-registry.json` empty. The issue was fixed in `teamforge-sync.sh` (guarded policy-blob handling + safer `source_ref` predicate), and the registry was reconstructed from:

1. `.thoughtseed/teamforge/sync-state.json` action history (TeamForge-linked tasks), and
2. active pending entries in agent `INBOX.md` files.

Post-recovery sync and tests passed, and the Clockify policy state is now stable.
