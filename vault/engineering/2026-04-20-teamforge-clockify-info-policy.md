# TeamForge Clockify Info Policy

Date: 2026-04-20
Owner: CLAWD

## Decision

`clockify.time_entry.logged` is informational telemetry, not operator work.

Active TeamForge surfaces now apply this policy automatically:

- Keep low-severity Clockify telemetry visible for 14 days.
- Collapse visible Clockify telemetry into one aggregate per `eventType + UTC day + routeOwner`.
- Hide older low-severity Clockify telemetry from active feed surfaces.
- Preserve raw auditability in `.thoughtseed/teamforge/sync-state.json`, snapshot history, and `.thoughtseed/task-registry.json`.
- Archive active low-severity Clockify registry tasks instead of leaving them pending.

## Implementation

Changed paths:

- `scripts/teamforge-sync.sh`
- `tests/test_teamforge_clockify_policy.sh`
- `tests/test_teamforge_export_cmd_manifest.sh`

Behavioral details:

- Active feed materialization uses `clockify_info_daily_aggregate` records with `policy.rawCount`, `policy.day`, and `policy.rawSyncKeys`.
- Registry archival reasons are:
  - `clockify_info_non_actionable`
  - `clockify_info_retention_window`
- Higher-severity or non-Clockify events continue to pass through as normal active feed items.
- `clockifyPolicy` counters in `.thoughtseed/teamforge/sync-state.json` record both last-run and cumulative totals.

## Verification

Targeted tests:

- `bash tests/test_teamforge_clockify_policy.sh`
- `bash tests/test_teamforge_export_cmd_manifest.sh`

Live repo verification:

- `./scripts/teamforge-sync.sh sync --no-dispatch`
- Registry after policy application:
  - `teamforgePendingClockify = 0`
  - `teamforgeArchivedClockify = 197`
  - archived reasons:
    - `clockify_info_non_actionable = 33`
    - `clockify_info_retention_window = 164`
- Policy totals in `.thoughtseed/teamforge/sync-state.json`:
  - `totals.archived = 197`
  - `totals.aggregatesVisible = 12`
  - `totals.suppressedDuplicates = 22`
- Non-empty active snapshot proof:
  - `vault/leadership/teamforge-feed/2026/04/20/teamforge-feed-20260420T091130Z-1776676290.json`
  - showed `12` Clockify daily aggregates and `0` non-Clockify items in that cursor window
- Current cursor window after the final sync:
  - `.thoughtseed/teamforge/latest-feed.json` has `0` active items
  - there were no higher-severity/non-Clockify items in the current window before or after the final sync

## Operational Outcome

Future low-severity Clockify floods should batch into daily aggregates automatically and archive out of active queues instead of generating operator backlog.
