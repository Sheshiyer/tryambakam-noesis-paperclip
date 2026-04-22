#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$REPO_ROOT/.thoughtseed/signal-lane/state.json"
BOARD_FILE="$REPO_ROOT/vault/leadership/signal-lane/signal-board.md"

"$REPO_ROOT/scripts/signal-lane-scan.sh" init >/dev/null

jq -e '.signals and .metadata and .cooldowns' "$STATE_FILE" >/dev/null
test -f "$BOARD_FILE"
