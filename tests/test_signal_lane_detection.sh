#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/signal-lane/drifted-runtime"

"$REPO_ROOT/scripts/signal-lane-scan.sh" scan --fixture-dir "$FIXTURE_DIR" >/dev/null

jq -e '.signals[] | select(.signal_type == "runtime_root_drift")' "$REPO_ROOT/.thoughtseed/signal-lane/state.json" >/dev/null
jq -e '.signals[] | select(.signal_type == "teamforge_feed_down")' "$REPO_ROOT/.thoughtseed/signal-lane/state.json" >/dev/null
jq -e '.signals[] | select(.signal_type == "meru_stale_run")' "$REPO_ROOT/.thoughtseed/signal-lane/state.json" >/dev/null
jq -e '.signals[] | select(.signal_type == "skill_mirror_drift")' "$REPO_ROOT/.thoughtseed/signal-lane/state.json" >/dev/null
jq -e '.signals[] | select(.signal_type == "task_registry_drift")' "$REPO_ROOT/.thoughtseed/signal-lane/state.json" >/dev/null
