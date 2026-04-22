#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/scripts" "$TMP_ROOT/.thoughtseed/teamforge/slices" "$TMP_ROOT/agents/sage"
copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" \
  teamforge-sync.sh teamforge-export-local.sh task-registry.sh dispatch-task.sh
make_scripts_executable "$TMP_ROOT/scripts" \
  teamforge-sync.sh teamforge-export-local.sh task-registry.sh dispatch-task.sh

cat > "$TMP_ROOT/manifest.yaml" <<'YAML'
teamforge:
  expected_schema_version: "agent_feed/v1"
  export_cmd: "./scripts/teamforge-export-local.sh"
  feed_limit: 25
  dispatch_enabled: false
  snapshots_path: "vault/leadership/teamforge-feed"
  retention_days: 30
  role_slice_max_items: 25
  quality_drift_threshold_seconds: 21600
  cooldown_info_minutes: 120
  cooldown_warn_minutes: 60
  cooldown_critical_minutes: 0
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

cat > "$TMP_ROOT/.thoughtseed/task-registry.json" <<'JSON'
{
  "tasks": [
    {
      "id": "task-9999999999-abcd",
      "title": "Recovered pending task",
      "assigned_agent": "sage",
      "department": "content",
      "status": "pending",
      "priority": "medium",
      "tags": ["content"],
      "created_at": "2026-04-20T09:00:00Z",
      "updated_at": "2026-04-20T09:00:00Z",
      "created_by": "recovery",
      "source": "inbox-recovery",
      "depends_on": null,
      "details": null,
      "source_sync_key": null,
      "source_ref": null,
      "signal_severity": null,
      "score_rationale": null
    }
  ],
  "metadata": {
    "total": 1,
    "pending": 1,
    "in_progress": 0,
    "completed": 0,
    "blocked": 0,
    "failed": 0,
    "archived": 0,
    "last_updated": "2026-04-20T09:00:00Z"
  }
}
JSON

cat > "$TMP_ROOT/agents/sage/INBOX.md" <<'MD'
# SAGE — Inbox

## Pending

_No pending items._

## Processed

### [2026-04-20T09:10:00Z] From: dispatch | Priority: medium | Processed: 2026-04-20T09:12:00Z
Recovered pending task
Task-ID: task-9999999999-abcd
MD

DB_PATH="$TMP_ROOT/teamforge.db"
sqlite3 "$DB_PATH" <<'SQL'
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
  occurred_at, detected_at, severity, owner_hint, actor_huly_person_id,
  payload_json, metadata_json, refreshed_at
) VALUES (
  'ops:v1:huly:runtime.error:runtime_signal:runtime_1:na:na:na:na:2026_04_20t09_00_00z',
  'agent_feed/v1',
  'huly',
  'runtime.error',
  'runtime_signal',
  'runtime_1',
  '2026-04-20T09:00:00Z',
  '2026-04-20T09:01:00Z',
  'warn',
  'agent:clawd',
  'huly_1',
  '{"summary":"Runtime degraded"}',
  '{"projection":"agent_feed/v1"}',
  '2026-04-20T09:01:00Z'
);
INSERT INTO sync_state (source, entity, last_sync_at, last_cursor) VALUES
  ('agent_feed', 'projection', '2026-04-20T09:01:00Z', NULL),
  ('clockify', 'time_entries', '2026-04-20T09:01:00Z', NULL),
  ('huly', 'issues', '2026-04-20T09:01:00Z', NULL),
  ('slack', 'messages_delta', '2026-04-20T09:01:00Z', NULL);
SQL

(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" TEAMFORGE_DB_PATH="$DB_PATH" ./scripts/teamforge-sync.sh sync --no-dispatch >/dev/null
)

jq -e '
  (.tasks | length) == 1
  and .tasks[0].id == "task-9999999999-abcd"
  and .tasks[0].status == "completed"
  and .metadata.pending == 0
  and .metadata.completed == 1
' "$TMP_ROOT/.thoughtseed/task-registry.json" >/dev/null
