#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"

tmp_enabled="$(mktemp -d)"
tmp_disabled="$(mktemp -d)"
trap 'rm -rf "$tmp_enabled" "$tmp_disabled"' EXIT

mkdir -p "$tmp_enabled/scripts" "$tmp_enabled/.thoughtseed" "$tmp_enabled/logs"
copy_scripts_from_repo "$SOURCE_REPO" "$tmp_enabled/scripts" loop-runner.sh yaml-helpers.sh
chmod +x "$tmp_enabled/scripts/loop-runner.sh"
write_runtime_root_guard_stub "$tmp_enabled/scripts/runtime-root-guard.sh"

cat > "$tmp_enabled/manifest.yaml" <<'YAML'
org:
  paperclip:
    sync:
      issues_to_inbox: "true"
      heartbeat_reporting: " true "
  signal_lane:
    enabled: " false "
    dispatch_enabled: " false "
    cooldown_minutes: "52"
    ready_threshold: "88"
    experiment_threshold: "61"
YAML

enabled_observed="$tmp_enabled/observed.env"
cat > "$tmp_enabled/scripts/paperclip-cycle.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cat > "$enabled_observed" <<ENV
ARGS=\$*
PAPERCLIP_CYCLE_SIGNAL_LANE_ENABLED=\${PAPERCLIP_CYCLE_SIGNAL_LANE_ENABLED:-}
PAPERCLIP_CYCLE_SIGNAL_LANE_DISPATCH_ENABLED=\${PAPERCLIP_CYCLE_SIGNAL_LANE_DISPATCH_ENABLED:-}
PAPERCLIP_CYCLE_SIGNAL_LANE_COOLDOWN_MINUTES=\${PAPERCLIP_CYCLE_SIGNAL_LANE_COOLDOWN_MINUTES:-}
PAPERCLIP_CYCLE_SIGNAL_LANE_READY_THRESHOLD=\${PAPERCLIP_CYCLE_SIGNAL_LANE_READY_THRESHOLD:-}
PAPERCLIP_CYCLE_SIGNAL_LANE_EXPERIMENT_THRESHOLD=\${PAPERCLIP_CYCLE_SIGNAL_LANE_EXPERIMENT_THRESHOLD:-}
ENV
EOF
chmod +x "$tmp_enabled/scripts/paperclip-cycle.sh"

REPO_ROOT="$tmp_enabled" "$tmp_enabled/scripts/loop-runner.sh" paperclip-cycle >/dev/null

test -f "$enabled_observed"
grep -qx 'ARGS=--with-heartbeats' "$enabled_observed"
grep -qx 'PAPERCLIP_CYCLE_SIGNAL_LANE_ENABLED=false' "$enabled_observed"
grep -qx 'PAPERCLIP_CYCLE_SIGNAL_LANE_DISPATCH_ENABLED=false' "$enabled_observed"
grep -qx 'PAPERCLIP_CYCLE_SIGNAL_LANE_COOLDOWN_MINUTES=52' "$enabled_observed"
grep -qx 'PAPERCLIP_CYCLE_SIGNAL_LANE_READY_THRESHOLD=88' "$enabled_observed"
grep -qx 'PAPERCLIP_CYCLE_SIGNAL_LANE_EXPERIMENT_THRESHOLD=61' "$enabled_observed"

mkdir -p "$tmp_disabled/scripts" "$tmp_disabled/.thoughtseed" "$tmp_disabled/logs"
copy_scripts_from_repo "$SOURCE_REPO" "$tmp_disabled/scripts" loop-runner.sh yaml-helpers.sh
chmod +x "$tmp_disabled/scripts/loop-runner.sh"
write_runtime_root_guard_stub "$tmp_disabled/scripts/runtime-root-guard.sh"

cat > "$tmp_disabled/manifest.yaml" <<'YAML'
org:
  paperclip:
    sync:
      issues_to_inbox: " false "
YAML

disabled_observed="$tmp_disabled/observed.disabled"
cat > "$tmp_disabled/scripts/paperclip-cycle.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "invoked" > "$disabled_observed"
EOF
chmod +x "$tmp_disabled/scripts/paperclip-cycle.sh"

REPO_ROOT="$tmp_disabled" "$tmp_disabled/scripts/loop-runner.sh" paperclip-cycle >/dev/null

if [[ -f "$disabled_observed" ]]; then
  echo "Expected paperclip cycle to remain disabled when issues_to_inbox is whitespace-padded quoted false" >&2
  exit 1
fi
