#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

iso_day_offset() {
  python3 - "$1" <<'PY'
import datetime
import sys

offset = int(sys.argv[1])
today = datetime.datetime.now(datetime.timezone.utc).date()
print((today + datetime.timedelta(days=offset)).isoformat())
PY
}

sync_key_slug() {
  python3 - "$1" <<'PY'
import sys

day = sys.argv[1]
print(f"{day}t03_30_00z")
PY
}

RECENT_DAY_ONE="$(iso_day_offset -1)"
RECENT_DAY_TWO="$(iso_day_offset -5)"
OLD_DAY="$(iso_day_offset -20)"
RECENT_SLUG_ONE="$(sync_key_slug "$RECENT_DAY_ONE")"
RECENT_SLUG_TWO="$(sync_key_slug "$RECENT_DAY_TWO")"
OLD_SLUG="$(sync_key_slug "$OLD_DAY")"

mkdir -p "$TMP_ROOT/scripts" "$TMP_ROOT/.thoughtseed/teamforge/slices" "$TMP_ROOT/agents/clawd"
copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" \
  teamforge-sync.sh teamforge-export-local.sh task-registry.sh dispatch-task.sh
make_scripts_executable "$TMP_ROOT/scripts" \
  teamforge-sync.sh teamforge-export-local.sh task-registry.sh dispatch-task.sh

cat > "$TMP_ROOT/manifest.yaml" <<'YAML'
teamforge:
  expected_schema_version: "agent_feed/v1"
  export_cmd: "./scripts/teamforge-export-local.sh"
  feed_limit: 50
  dispatch_enabled: true
  snapshots_path: "vault/leadership/teamforge-feed"
  retention_days: 30
  role_slice_max_items: 25
  quality_drift_threshold_seconds: 21600
  cooldown_info_minutes: 120
  cooldown_warn_minutes: 60
  cooldown_critical_minutes: 0
  clockify_info_active_days: 14
  health_max_lag_warn_seconds: 3600
  health_failure_rate_warn: 0.20
  health_min_coverage_warn: 0.66
YAML

cat > "$TMP_ROOT/.thoughtseed/teamforge/sync-state.json" <<'JSON'
{
  "schemaVersion": "teamforge-sync/v1",
  "expectedFeedSchemaVersion": "agent_feed/v1",
  "cursor": null,
  "lastRunAt": null,
  "lastError": null,
  "latestSnapshotPath": null,
  "runs": {
    "total": 0,
    "success": 0,
    "failed": 0
  },
  "suppression": {
    "total": 0,
    "lastRun": 0
  },
  "seenSyncKeys": {},
  "cooldowns": {},
  "actions": {},
  "outcomes": {
    "resolved": 0,
    "partial": 0,
    "noChange": 0,
    "regressed": 0,
    "validatedSignals": 0,
    "avgTimeToResolutionSeconds": null,
    "recurrenceSignals": 0
  },
  "quality": {
    "score": 100,
    "findingCount": 0
  }
}
JSON

cat > "$TMP_ROOT/.thoughtseed/task-registry.json" <<JSON
{
  "tasks": [
    {
      "id": "task-clockify-recent-a",
      "title": "Clockify recent A",
      "assigned_agent": "clawd",
      "department": "engineering",
      "status": "pending",
      "priority": "medium",
      "tags": ["code"],
      "created_at": "${RECENT_DAY_ONE}T04:00:00Z",
      "updated_at": "${RECENT_DAY_ONE}T04:00:00Z",
      "created_by": "dispatch",
      "source": "teamforge",
      "depends_on": null,
      "details": null,
      "source_sync_key": "ops:v1:clockify:clockify.time_entry.logged:clockify_time_entry:recent_a:user:user:na:na:${RECENT_SLUG_ONE}",
      "source_ref": "clockify:clockify.time_entry.logged",
      "signal_severity": "info",
      "score_rationale": "feed severity=info"
    },
    {
      "id": "task-clockify-recent-b",
      "title": "Clockify recent B",
      "assigned_agent": "clawd",
      "department": "engineering",
      "status": "pending",
      "priority": "medium",
      "tags": ["code"],
      "created_at": "${RECENT_DAY_ONE}T05:00:00Z",
      "updated_at": "${RECENT_DAY_ONE}T05:00:00Z",
      "created_by": "dispatch",
      "source": "teamforge",
      "depends_on": null,
      "details": null,
      "source_sync_key": "ops:v1:clockify:clockify.time_entry.logged:clockify_time_entry:recent_b:user:user:na:na:${RECENT_SLUG_ONE}",
      "source_ref": "clockify:clockify.time_entry.logged",
      "signal_severity": "info",
      "score_rationale": "feed severity=info"
    },
    {
      "id": "task-clockify-recent-c",
      "title": "Clockify recent C",
      "assigned_agent": "clawd",
      "department": "engineering",
      "status": "pending",
      "priority": "medium",
      "tags": ["code"],
      "created_at": "${RECENT_DAY_TWO}T04:00:00Z",
      "updated_at": "${RECENT_DAY_TWO}T04:00:00Z",
      "created_by": "dispatch",
      "source": "teamforge",
      "depends_on": null,
      "details": null,
      "source_sync_key": "ops:v1:clockify:clockify.time_entry.logged:clockify_time_entry:recent_c:user:user:na:na:${RECENT_SLUG_TWO}",
      "source_ref": "clockify:clockify.time_entry.logged",
      "signal_severity": "info",
      "score_rationale": "feed severity=info"
    },
    {
      "id": "task-clockify-old",
      "title": "Clockify old",
      "assigned_agent": "clawd",
      "department": "engineering",
      "status": "pending",
      "priority": "medium",
      "tags": ["code"],
      "created_at": "${OLD_DAY}T04:00:00Z",
      "updated_at": "${OLD_DAY}T04:00:00Z",
      "created_by": "dispatch",
      "source": "teamforge",
      "depends_on": null,
      "details": null,
      "source_sync_key": "ops:v1:clockify:clockify.time_entry.logged:clockify_time_entry:old_a:user:user:na:na:${OLD_SLUG}",
      "source_ref": "clockify:clockify.time_entry.logged",
      "signal_severity": "info",
      "score_rationale": "feed severity=info"
    }
  ],
  "metadata": {
    "total": 4,
    "pending": 4,
    "in_progress": 0,
    "completed": 0,
    "blocked": 0,
    "failed": 0,
    "last_updated": "${RECENT_DAY_ONE}T04:00:00Z"
  }
}
JSON

DB_PATH="$TMP_ROOT/teamforge.db"
sqlite3 "$DB_PATH" <<SQL
CREATE TABLE agent_feed (
  id INTEGER PRIMARY KEY,
  sync_key TEXT NOT NULL,
  schema_version TEXT NOT NULL,
  source TEXT NOT NULL,
  event_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  detected_at TEXT NOT NULL,
  severity TEXT NOT NULL,
  owner_hint TEXT,
  actor_employee_id TEXT,
  actor_clockify_user_id TEXT,
  actor_huly_person_id TEXT,
  actor_slack_user_id TEXT,
  payload_json TEXT NOT NULL,
  metadata_json TEXT,
  refreshed_at TEXT NOT NULL
);
CREATE TABLE sync_state (
  source TEXT NOT NULL,
  entity TEXT NOT NULL,
  last_sync_at TEXT NOT NULL,
  last_cursor TEXT,
  PRIMARY KEY (source, entity)
);
INSERT INTO agent_feed (
  sync_key, schema_version, source, event_type, entity_type, entity_id,
  occurred_at, detected_at, severity, owner_hint, actor_clockify_user_id,
  payload_json, metadata_json, refreshed_at
) VALUES
(
  'ops:v1:clockify:clockify.time_entry.logged:clockify_time_entry:recent_a:user:user:na:na:${RECENT_SLUG_ONE}',
  'agent_feed/v1',
  'clockify',
  'clockify.time_entry.logged',
  'clockify_time_entry',
  'recent_a',
  '${RECENT_DAY_ONE}T03:30:00Z',
  '${RECENT_DAY_ONE}T03:31:00Z',
  'info',
  'agent:clawd',
  'clockify_1',
  '{"summary":"Recent entry A"}',
  '{"projection":"agent_feed/v1"}',
  '${RECENT_DAY_ONE}T03:31:00Z'
),
(
  'ops:v1:clockify:clockify.time_entry.logged:clockify_time_entry:recent_b:user:user:na:na:${RECENT_SLUG_ONE}',
  'agent_feed/v1',
  'clockify',
  'clockify.time_entry.logged',
  'clockify_time_entry',
  'recent_b',
  '${RECENT_DAY_ONE}T11:30:00Z',
  '${RECENT_DAY_ONE}T11:31:00Z',
  'info',
  'agent:clawd',
  'clockify_1',
  '{"summary":"Recent entry B"}',
  '{"projection":"agent_feed/v1"}',
  '${RECENT_DAY_ONE}T11:31:00Z'
),
(
  'ops:v1:clockify:clockify.time_entry.logged:clockify_time_entry:recent_c:user:user:na:na:${RECENT_SLUG_TWO}',
  'agent_feed/v1',
  'clockify',
  'clockify.time_entry.logged',
  'clockify_time_entry',
  'recent_c',
  '${RECENT_DAY_TWO}T03:30:00Z',
  '${RECENT_DAY_TWO}T03:31:00Z',
  'info',
  'agent:clawd',
  'clockify_2',
  '{"summary":"Recent entry C"}',
  '{"projection":"agent_feed/v1"}',
  '${RECENT_DAY_TWO}T03:31:00Z'
),
(
  'ops:v1:clockify:clockify.time_entry.logged:clockify_time_entry:old_a:user:user:na:na:${OLD_SLUG}',
  'agent_feed/v1',
  'clockify',
  'clockify.time_entry.logged',
  'clockify_time_entry',
  'old_a',
  '${OLD_DAY}T03:30:00Z',
  '${OLD_DAY}T03:31:00Z',
  'info',
  'agent:clawd',
  'clockify_3',
  '{"summary":"Old entry"}',
  '{"projection":"agent_feed/v1"}',
  '${OLD_DAY}T03:31:00Z'
),
(
  'ops:v1:huly:runtime.error:runtime_signal:runtime_1:na:na:na:na:${RECENT_SLUG_ONE}',
  'agent_feed/v1',
  'huly',
  'runtime.error',
  'runtime_signal',
  'runtime_1',
  '${RECENT_DAY_ONE}T08:00:00Z',
  '${RECENT_DAY_ONE}T08:01:00Z',
  'warn',
  'agent:clawd',
  NULL,
  '{"summary":"Runtime degraded"}',
  '{"projection":"agent_feed/v1"}',
  '${RECENT_DAY_ONE}T08:01:00Z'
);
INSERT INTO sync_state (source, entity, last_sync_at, last_cursor) VALUES
  ('agent_feed', 'projection', '${RECENT_DAY_ONE}T11:31:00Z', NULL),
  ('clockify', 'time_entries', '${RECENT_DAY_ONE}T11:31:00Z', NULL),
  ('huly', 'issues', '${RECENT_DAY_ONE}T11:31:00Z', NULL),
  ('slack', 'messages_delta', '${RECENT_DAY_ONE}T11:31:00Z', NULL);
SQL

(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" TEAMFORGE_DB_PATH="$DB_PATH" ./scripts/teamforge-sync.sh sync >/dev/null
)

jq -e '
  (.items | length) == 3
  and ([.items[] | select(.eventType == "clockify.time_entry.logged")] | length) == 2
  and ([.items[] | select(.eventType == "runtime.error")] | length) == 1
' "$TMP_ROOT/.thoughtseed/teamforge/latest-feed.json" >/dev/null

jq -e --arg day "$RECENT_DAY_ONE" '
  .items[]
  | select(.eventType == "clockify.time_entry.logged")
  | select(.policy.aggregated == true and .policy.rawCount == 2 and .policy.day == $day)
' "$TMP_ROOT/.thoughtseed/teamforge/latest-feed.json" >/dev/null

if jq -e --arg day "$OLD_DAY" '
  .items[]
  | select(.eventType == "clockify.time_entry.logged" and .policy.day == $day)
' "$TMP_ROOT/.thoughtseed/teamforge/latest-feed.json" >/dev/null; then
  echo "Old Clockify aggregate should not remain visible after retention cutoff" >&2
  exit 1
fi

jq -e '
  .items[]
  | select(.eventType == "runtime.error")
  | select((.policy // null) == null and (.taskId // null) != null)
' "$TMP_ROOT/.thoughtseed/teamforge/latest-feed.json" >/dev/null

jq -e '
  .metadata.pending == 1
  and (.metadata.archived // 0) == 4
  and ([.tasks[] | select(.status == "pending" and ((.source_ref // "") == "huly:runtime.error"))] | length) == 1
  and ([.tasks[] | select(.status == "pending" and ((.source_ref // "") == "clockify:clockify.time_entry.logged"))] | length) == 0
  and ([.tasks[] | select(.status == "archived" and .archive_reason == "clockify_info_non_actionable")] | length) == 3
  and ([.tasks[] | select(.status == "archived" and .archive_reason == "clockify_info_retention_window")] | length) == 1
' "$TMP_ROOT/.thoughtseed/task-registry.json" >/dev/null

jq -e '
  .clockifyPolicy.lastRun.archivedCount == 4
  and .clockifyPolicy.lastRun.archivedRetention == 1
  and .clockifyPolicy.lastRun.archivedNonActionable == 3
  and .clockifyPolicy.lastRun.aggregatesVisible == 2
  and .clockifyPolicy.lastRun.rawClockifyLowSeverity == 4
  and .clockifyPolicy.activeWindowDays == 14
' "$TMP_ROOT/.thoughtseed/teamforge/sync-state.json" >/dev/null

(
  cd "$TMP_ROOT"
  tmp_state="$(mktemp)"
  jq '.cursor = null' .thoughtseed/teamforge/sync-state.json > "$tmp_state"
  mv "$tmp_state" .thoughtseed/teamforge/sync-state.json
  REPO_ROOT="$TMP_ROOT" TEAMFORGE_DB_PATH="$DB_PATH" ./scripts/teamforge-sync.sh sync >/dev/null
)

jq -e '
  .metrics.newSignals == 0
  and .metrics.skippedSignals > 0
  and .metrics.suppressedSignals > 0
  and .metrics.quality.score == 100
  and .metrics.quality.findingCount == 0
  and .metrics.coverage.evaluated == false
  and .metrics.coverage.ratio == null
  and (.metrics.coverage.seenSources | length) == 0
  and .metrics.failureRateCurrent == 0
  and .metrics.failureRateScope == "historical_lifetime_runs"
  and .alerts.coverageWarning == false
  and .alerts.failureRateWarning == false
' "$TMP_ROOT/.thoughtseed/teamforge/health.json" >/dev/null
