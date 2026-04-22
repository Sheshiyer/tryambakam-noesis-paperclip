#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"

FIXTURE_DIR="$SOURCE_REPO/tests/fixtures/signal-lane/drifted-runtime"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/scripts" "$TMP_ROOT/agents" "$TMP_ROOT/.thoughtseed" "$TMP_ROOT/templates"

cp "$SOURCE_REPO/manifest.yaml" "$TMP_ROOT/manifest.yaml"
copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" \
  task-registry.sh dispatch-task.sh runtime-root-guard.sh signal-lane-scan.sh
cp "$SOURCE_REPO/templates/signal-board.md" "$TMP_ROOT/templates/signal-board.md"

make_scripts_executable "$TMP_ROOT/scripts" \
  task-registry.sh dispatch-task.sh runtime-root-guard.sh signal-lane-scan.sh

printf '%s\n' "$TMP_ROOT" > "$TMP_ROOT/.thoughtseed/canonical-runtime-root.txt"

for agent in atlas clawd sage sentinel jarvis; do
  mkdir -p "$TMP_ROOT/agents/$agent"
done

REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/signal-lane-scan.sh" scan --fixture-dir "$FIXTURE_DIR" >/dev/null
REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/signal-lane-scan.sh" dispatch >/dev/null

FIRST_TOTAL="$(jq '.metadata.total' "$TMP_ROOT/.thoughtseed/task-registry.json")"
[[ "$FIRST_TOTAL" -eq 5 ]]

ACTIVE_RUNTIME="$(REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/task-registry.sh" find-active-by-sync-key "signal:runtime_root_drift" | jq 'length')"
[[ "$ACTIVE_RUNTIME" -eq 1 ]]

REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/signal-lane-scan.sh" dispatch >/dev/null
SECOND_TOTAL="$(jq '.metadata.total' "$TMP_ROOT/.thoughtseed/task-registry.json")"
[[ "$SECOND_TOTAL" -eq "$FIRST_TOTAL" ]]

RUNTIME_TASK_ID="$(REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/task-registry.sh" find-active-by-sync-key "signal:runtime_root_drift" | jq -r '.[0].id')"
REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/task-registry.sh" update "$RUNTIME_TASK_ID" --status completed >/dev/null

REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/signal-lane-scan.sh" dispatch >/dev/null
THIRD_TOTAL="$(jq '.metadata.total' "$TMP_ROOT/.thoughtseed/task-registry.json")"
[[ "$THIRD_TOTAL" -eq "$FIRST_TOTAL" ]]

COOLDOWN_SET="$(jq -r '.cooldowns["signal:runtime_root_drift"] // ""' "$TMP_ROOT/.thoughtseed/signal-lane/state.json")"
[[ -n "$COOLDOWN_SET" ]]
