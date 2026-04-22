#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/scripts" "$TMP_ROOT/.thoughtseed/signal-lane"
SEQUENCE_FILE="$TMP_ROOT/sequence.log"
LOCK_DIR="$TMP_ROOT/.locks/paperclip-cycle.lock"

cat > "$TMP_ROOT/manifest.yaml" <<'YAML'
org:
  paperclip:
    issues_to_inbox: true
    heartbeat_reporting: false
  signal_lane:
    enabled: true
    dispatch_enabled: true
    cooldown_minutes: 180
    ready_threshold: 70
    experiment_threshold: 50
YAML

copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" paperclip-cycle.sh

cat > "$TMP_ROOT/scripts/teamforge-sync.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "teamforge-sync" >> "$SEQUENCE_FILE"
EOF

cat > "$TMP_ROOT/scripts/paperclip-sync.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "paperclip-sync:\$1" >> "$SEQUENCE_FILE"
EOF

cat > "$TMP_ROOT/scripts/paperclip-reconcile-local.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "paperclip-reconcile-local" >> "$SEQUENCE_FILE"
EOF

cat > "$TMP_ROOT/scripts/signal-lane-scan.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "signal-lane:\$1" >> "$SEQUENCE_FILE"
EOF

chmod +x "$TMP_ROOT/scripts/"*.sh

REPO_ROOT="$TMP_ROOT" PAPERCLIP_CYCLE_LOCK_DIR="$LOCK_DIR" "$TMP_ROOT/scripts/paperclip-cycle.sh" >/dev/null

EXPECTED=$'teamforge-sync\npaperclip-sync:sync-issues\npaperclip-reconcile-local\nsignal-lane:scan\nsignal-lane:dispatch'
ACTUAL="$(cat "$SEQUENCE_FILE")"

[[ "$ACTUAL" == "$EXPECTED" ]]
