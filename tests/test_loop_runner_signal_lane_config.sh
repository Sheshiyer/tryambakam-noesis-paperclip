#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/scripts" "$TMP_ROOT/.thoughtseed" "$TMP_ROOT/logs"
OBSERVED_FILE="$TMP_ROOT/observed.env"

cat > "$TMP_ROOT/manifest.yaml" <<'YAML'
org:
  paperclip:
    sync:
      issues_to_inbox: true
      heartbeat_reporting: false
  signal_lane:
    enabled: false
    dispatch_enabled: false
    cooldown_minutes: 42
    ready_threshold: 91
    experiment_threshold: 63
YAML

copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" loop-runner.sh yaml-helpers.sh
write_runtime_root_guard_stub "$TMP_ROOT/scripts/runtime-root-guard.sh"

cat > "$TMP_ROOT/scripts/paperclip-cycle.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cat > "$OBSERVED_FILE" <<ENV
PAPERCLIP_CYCLE_SIGNAL_LANE_ENABLED=\${PAPERCLIP_CYCLE_SIGNAL_LANE_ENABLED:-}
PAPERCLIP_CYCLE_SIGNAL_LANE_DISPATCH_ENABLED=\${PAPERCLIP_CYCLE_SIGNAL_LANE_DISPATCH_ENABLED:-}
PAPERCLIP_CYCLE_SIGNAL_LANE_COOLDOWN_MINUTES=\${PAPERCLIP_CYCLE_SIGNAL_LANE_COOLDOWN_MINUTES:-}
PAPERCLIP_CYCLE_SIGNAL_LANE_READY_THRESHOLD=\${PAPERCLIP_CYCLE_SIGNAL_LANE_READY_THRESHOLD:-}
PAPERCLIP_CYCLE_SIGNAL_LANE_EXPERIMENT_THRESHOLD=\${PAPERCLIP_CYCLE_SIGNAL_LANE_EXPERIMENT_THRESHOLD:-}
ENV
EOF

chmod +x "$TMP_ROOT/scripts/"*.sh

REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/loop-runner.sh" paperclip-cycle >/dev/null

grep -qx 'PAPERCLIP_CYCLE_SIGNAL_LANE_ENABLED=false' "$OBSERVED_FILE"
grep -qx 'PAPERCLIP_CYCLE_SIGNAL_LANE_DISPATCH_ENABLED=false' "$OBSERVED_FILE"
grep -qx 'PAPERCLIP_CYCLE_SIGNAL_LANE_COOLDOWN_MINUTES=42' "$OBSERVED_FILE"
grep -qx 'PAPERCLIP_CYCLE_SIGNAL_LANE_READY_THRESHOLD=91' "$OBSERVED_FILE"
grep -qx 'PAPERCLIP_CYCLE_SIGNAL_LANE_EXPERIMENT_THRESHOLD=63' "$OBSERVED_FILE"
