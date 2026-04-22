#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/scripts" "$TMP_ROOT/.thoughtseed" "$TMP_ROOT/agents/atlas"
copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" task-registry.sh
chmod +x "$TMP_ROOT/scripts/task-registry.sh"

cat > "$TMP_ROOT/.thoughtseed/task-registry.json" <<'JSON'
{
  "tasks": [
    {
      "id": "task-1111111111-abcd",
      "title": "Processed in inbox",
      "assigned_agent": "atlas",
      "department": "research",
      "status": "pending",
      "priority": "medium",
      "tags": ["research"],
      "created_at": "2026-04-20T09:00:00Z",
      "updated_at": "2026-04-20T09:00:00Z",
      "created_by": "dispatch",
      "source": "review-intent",
      "depends_on": null,
      "details": null,
      "source_sync_key": "signal:one",
      "source_ref": "/tmp/ref-one",
      "signal_severity": null,
      "score_rationale": null
    },
    {
      "id": "task-2222222222-bcde",
      "title": "Still pending in inbox",
      "assigned_agent": "atlas",
      "department": "research",
      "status": "pending",
      "priority": "medium",
      "tags": ["research"],
      "created_at": "2026-04-20T09:00:00Z",
      "updated_at": "2026-04-20T09:00:00Z",
      "created_by": "dispatch",
      "source": "review-intent",
      "depends_on": null,
      "details": null,
      "source_sync_key": "signal:two",
      "source_ref": "/tmp/ref-two",
      "signal_severity": null,
      "score_rationale": null
    },
    {
      "id": "task-3333333333-cdef",
      "title": "Not in inbox",
      "assigned_agent": "sage",
      "department": "content",
      "status": "pending",
      "priority": "medium",
      "tags": ["content"],
      "created_at": "2026-04-20T09:00:00Z",
      "updated_at": "2026-04-20T09:00:00Z",
      "created_by": "dispatch",
      "source": "review-intent",
      "depends_on": null,
      "details": null,
      "source_sync_key": "signal:three",
      "source_ref": "/tmp/ref-three",
      "signal_severity": null,
      "score_rationale": null
    },
    {
      "id": "task-4444444444-def0",
      "title": "Resolved review-intent baseline",
      "assigned_agent": "atlas",
      "department": "research",
      "status": "completed",
      "priority": "medium",
      "tags": ["research"],
      "created_at": "2026-04-20T09:00:00Z",
      "updated_at": "2026-04-20T09:00:00Z",
      "created_by": "dispatch",
      "source": "review-intent",
      "depends_on": null,
      "details": null,
      "source_sync_key": "signal:dup",
      "source_ref": "/tmp/ref-dup",
      "signal_severity": null,
      "score_rationale": null
    },
    {
      "id": "task-5555555555-ef01",
      "title": "Duplicate review-intent active",
      "assigned_agent": "atlas",
      "department": "research",
      "status": "in_progress",
      "priority": "medium",
      "tags": ["research"],
      "created_at": "2026-04-20T09:00:00Z",
      "updated_at": "2026-04-20T09:00:00Z",
      "created_by": "dispatch",
      "source": "review-intent",
      "depends_on": null,
      "details": null,
      "source_sync_key": "signal:dup",
      "source_ref": "/tmp/ref-dup",
      "signal_severity": null,
      "score_rationale": null
    },
    {
      "id": "task-6666666666-f012",
      "title": "Sync-key matched review-intent active",
      "assigned_agent": "atlas",
      "department": "research",
      "status": "blocked",
      "priority": "medium",
      "tags": ["research"],
      "created_at": "2026-04-20T09:00:00Z",
      "updated_at": "2026-04-20T09:00:00Z",
      "created_by": "dispatch",
      "source": "review-intent",
      "depends_on": null,
      "details": null,
      "source_sync_key": "signal:synconly",
      "source_ref": "/tmp/ref-synconly",
      "signal_severity": null,
      "score_rationale": null
    }
  ],
  "metadata": {
    "total": 6,
    "pending": 3,
    "in_progress": 1,
    "completed": 1,
    "blocked": 1,
    "failed": 0,
    "archived": 0,
    "last_updated": "2026-04-20T09:00:00Z"
  }
}
JSON

cat > "$TMP_ROOT/agents/atlas/INBOX.md" <<'MD'
# ATLAS — Inbox

## Pending

### [2026-04-20T09:10:00Z] From: dispatch | Priority: medium
Still pending in inbox
Task-ID: task-2222222222-bcde

## Processed

### [2026-04-20T09:05:00Z] From: dispatch | Priority: medium | Processed: 2026-04-20T09:07:00Z
Processed in inbox
Task-ID: task-1111111111-abcd
Sync-Key: signal:one

### [2026-04-20T09:06:00Z] From: dispatch | Priority: medium | Processed: 2026-04-20T09:08:00Z
Processed similar signal elsewhere
Task-ID: task-7777777777-0123
Sync-Key: signal:synconly
MD

reconcile_output="$(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/task-registry.sh reconcile-inbox 2>&1 >/dev/null
)"

echo "$reconcile_output" | grep -q "Reconciled 3 active registry tasks"

jq -e '
  ([.tasks[] | select(.id == "task-1111111111-abcd" and .status == "completed")] | length) == 1
  and ([.tasks[] | select(.id == "task-2222222222-bcde" and .status == "pending")] | length) == 1
  and ([.tasks[] | select(.id == "task-3333333333-cdef" and .status == "pending")] | length) == 1
  and ([.tasks[] | select(.id == "task-5555555555-ef01" and .status == "completed")] | length) == 1
  and ([.tasks[] | select(.id == "task-6666666666-f012" and .status == "completed")] | length) == 1
  and .metadata.pending == 2
  and .metadata.in_progress == 0
  and .metadata.blocked == 0
  and .metadata.completed == 4
' "$TMP_ROOT/.thoughtseed/task-registry.json" >/dev/null
