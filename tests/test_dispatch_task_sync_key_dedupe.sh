#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/scripts" "$TMP_ROOT/agents/atlas" "$TMP_ROOT/.thoughtseed"
copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" dispatch-task.sh task-registry.sh
chmod +x "$TMP_ROOT/scripts/dispatch-task.sh" "$TMP_ROOT/scripts/task-registry.sh"

cat > "$TMP_ROOT/manifest.yaml" <<'YAML'
departments:
  research:
    lead: atlas
YAML

cat > "$TMP_ROOT/agents/atlas/INBOX.md" <<'MD'
# ATLAS — Inbox

## Pending

## Processed
MD

dispatch_once() {
  local title="$1"
  (
    cd "$TMP_ROOT"
    REPO_ROOT="$TMP_ROOT" ./scripts/dispatch-task.sh "$title" \
      --agent atlas \
      --tag research \
      --source review-intent \
      --sync-key signal:test_sync_key \
      --details "dedupe check"
  )
}

out1="$(dispatch_once "Review intent: reconcile skill mirror drift")"
id1="$(printf '%s\n' "$out1" | awk '/^Dispatched:/{print $2; exit}')"

out2="$(dispatch_once "Review intent: duplicate signal should not re-dispatch")"
id2="$(printf '%s\n' "$out2" | awk '/^Dispatched:/{print $2; exit}')"

if [[ -z "$id1" || -z "$id2" ]]; then
  echo "Expected dispatch output with task IDs" >&2
  exit 1
fi

if [[ "$id1" != "$id2" ]]; then
  echo "Expected duplicate sync-key dispatch to return existing task id" >&2
  exit 1
fi

(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/task-registry.sh update "$id1" --status completed >/dev/null
)

out3="$(dispatch_once "Review intent: completed sync-key should still not re-dispatch")"
id3="$(printf '%s\n' "$out3" | awk '/^Dispatched:/{print $2; exit}')"

if [[ "$id1" != "$id3" ]]; then
  echo "Expected review-intent sync-key to reuse existing completed task id" >&2
  exit 1
fi

(
  cd "$TMP_ROOT"
  REPO_ROOT="$TMP_ROOT" ./scripts/task-registry.sh update "$id1" --status failed >/dev/null
)

out4="$(dispatch_once "Review intent: failed sync-key should dispatch a new task")"
id4="$(printf '%s\n' "$out4" | awk '/^Dispatched:/{print $2; exit}')"

if [[ -z "$id4" ]]; then
  echo "Expected dispatch output with task ID after failed review-intent task" >&2
  exit 1
fi

if [[ "$id4" == "$id1" ]]; then
  echo "Expected failed review-intent task to allow a new dispatch" >&2
  exit 1
fi

jq -e '
  (.tasks | length) == 2
  and ([.tasks[] | select(.id == $failed_id and .status == "failed")] | length) == 1
  and ([.tasks[] | select(.id == $new_id and .status == "pending")] | length) == 1
  and .metadata.pending == 1
  and .metadata.failed == 1
' --arg failed_id "$id1" --arg new_id "$id4" "$TMP_ROOT/.thoughtseed/task-registry.json" >/dev/null

task_id_line_count="$(grep -c '^Task-ID:' "$TMP_ROOT/agents/atlas/INBOX.md" || true)"
if [[ "$task_id_line_count" -ne 2 ]]; then
  echo "Expected exactly two inbox entries: original plus post-failure redispatch" >&2
  exit 1
fi
