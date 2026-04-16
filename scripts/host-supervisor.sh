#!/usr/bin/env bash
# Thoughtseed host-native supervisor management.
#
# Supports:
# - macOS launchd (per-user LaunchAgents)
# - Linux systemd --user services
#
# Usage:
#   ./scripts/host-supervisor.sh install
#   ./scripts/host-supervisor.sh start
#   ./scripts/host-supervisor.sh stop
#   ./scripts/host-supervisor.sh restart
#   ./scripts/host-supervisor.sh status
#   ./scripts/host-supervisor.sh uninstall

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG_DIR="$REPO_ROOT/logs"

LAUNCHD_LOOP_LABEL="com.thoughtseed.loop-runner"
LAUNCHD_BABYSITTER_LABEL="com.thoughtseed.babysitter"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"
LAUNCHD_LOG_DIR="$HOME/Library/Logs/thoughtseed"
LAUNCHD_LOOP_PLIST="$LAUNCHD_DIR/${LAUNCHD_LOOP_LABEL}.plist"
LAUNCHD_BABYSITTER_PLIST="$LAUNCHD_DIR/${LAUNCHD_BABYSITTER_LABEL}.plist"

SYSTEMD_LOOP_SERVICE="thoughtseed-loop-runner.service"
SYSTEMD_BABYSITTER_SERVICE="thoughtseed-babysitter.service"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SYSTEMD_LOOP_UNIT="$SYSTEMD_DIR/$SYSTEMD_LOOP_SERVICE"
SYSTEMD_BABYSITTER_UNIT="$SYSTEMD_DIR/$SYSTEMD_BABYSITTER_SERVICE"

SERVICE_PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/sheshnarayaniyer/.nvm/versions/node/v22.16.0/bin"
BASH_BIN="$(command -v bash)"

platform() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    *) echo "unknown" ;;
  esac
}

ensure_dirs() {
  mkdir -p "$LOG_DIR"
}

write_launchd_plists() {
  mkdir -p "$LAUNCHD_DIR"
  mkdir -p "$LAUNCHD_LOG_DIR"
  ensure_dirs

  cat > "$LAUNCHD_LOOP_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LAUNCHD_LOOP_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${BASH_BIN}</string>
    <string>${REPO_ROOT}/scripts/loop-runner.sh</string>
    <string>run</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${REPO_ROOT}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>
  <key>EnvironmentVariables</key>
  <dict>
    <key>REPO_ROOT</key>
    <string>${REPO_ROOT}</string>
    <key>THOUGHTSEED_SUPERVISOR_MODE</key>
    <string>host</string>
    <key>PATH</key>
    <string>${SERVICE_PATH}</string>
  </dict>
  <key>StandardOutPath</key>
  <string>${LAUNCHD_LOG_DIR}/loop-runner.supervisor.out.log</string>
  <key>StandardErrorPath</key>
  <string>${LAUNCHD_LOG_DIR}/loop-runner.supervisor.err.log</string>
</dict>
</plist>
EOF

  cat > "$LAUNCHD_BABYSITTER_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LAUNCHD_BABYSITTER_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${BASH_BIN}</string>
    <string>${REPO_ROOT}/scripts/babysitter.sh</string>
    <string>run</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${REPO_ROOT}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>
  <key>EnvironmentVariables</key>
  <dict>
    <key>REPO_ROOT</key>
    <string>${REPO_ROOT}</string>
    <key>THOUGHTSEED_SUPERVISOR_MODE</key>
    <string>host</string>
    <key>PATH</key>
    <string>${SERVICE_PATH}</string>
  </dict>
  <key>StandardOutPath</key>
  <string>${LAUNCHD_LOG_DIR}/babysitter.supervisor.out.log</string>
  <key>StandardErrorPath</key>
  <string>${LAUNCHD_LOG_DIR}/babysitter.supervisor.err.log</string>
</dict>
</plist>
EOF
}

launchd_bootout_if_loaded() {
  local label="$1"
  launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
}

launchd_start_one() {
  local label="$1"
  local plist_path="$2"
  launchd_bootout_if_loaded "$label"
  launchctl bootstrap "gui/$(id -u)" "$plist_path"
  launchctl enable "gui/$(id -u)/$label" >/dev/null 2>&1 || true
  launchctl kickstart -k "gui/$(id -u)/$label"
}

launchd_stop_one() {
  local label="$1"
  launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
}

launchd_status_one() {
  local label="$1"
  if launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
    echo "$label: loaded"
  else
    echo "$label: not loaded"
  fi
}

write_systemd_units() {
  mkdir -p "$SYSTEMD_DIR"
  ensure_dirs

  cat > "$SYSTEMD_LOOP_UNIT" <<EOF
[Unit]
Description=Thoughtseed Loop Runner
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${REPO_ROOT}
Environment=REPO_ROOT=${REPO_ROOT}
Environment=THOUGHTSEED_SUPERVISOR_MODE=host
Environment=PATH=${SERVICE_PATH}
ExecStart=${BASH_BIN} ${REPO_ROOT}/scripts/loop-runner.sh run
Restart=always
RestartSec=5
KillMode=process

[Install]
WantedBy=default.target
EOF

  cat > "$SYSTEMD_BABYSITTER_UNIT" <<EOF
[Unit]
Description=Thoughtseed Babysitter
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${REPO_ROOT}
Environment=REPO_ROOT=${REPO_ROOT}
Environment=THOUGHTSEED_SUPERVISOR_MODE=host
Environment=PATH=${SERVICE_PATH}
ExecStart=${BASH_BIN} ${REPO_ROOT}/scripts/babysitter.sh run
Restart=always
RestartSec=5
KillMode=process

[Install]
WantedBy=default.target
EOF
}

systemd_reload() {
  systemctl --user daemon-reload
}

systemd_start() {
  systemctl --user enable --now "$SYSTEMD_LOOP_SERVICE" "$SYSTEMD_BABYSITTER_SERVICE"
}

systemd_stop() {
  systemctl --user stop "$SYSTEMD_LOOP_SERVICE" "$SYSTEMD_BABYSITTER_SERVICE" >/dev/null 2>&1 || true
}

systemd_status() {
  systemctl --user --no-pager --full status "$SYSTEMD_LOOP_SERVICE" "$SYSTEMD_BABYSITTER_SERVICE" || true
}

install_services() {
  case "$(platform)" in
    darwin)
      write_launchd_plists
      launchd_start_one "$LAUNCHD_LOOP_LABEL" "$LAUNCHD_LOOP_PLIST"
      launchd_start_one "$LAUNCHD_BABYSITTER_LABEL" "$LAUNCHD_BABYSITTER_PLIST"
      ;;
    linux)
      write_systemd_units
      systemd_reload
      systemd_start
      ;;
    *)
      echo "Unsupported platform for host supervisor install."
      exit 1
      ;;
  esac
}

start_services() {
  case "$(platform)" in
    darwin)
      if [[ ! -f "$LAUNCHD_LOOP_PLIST" || ! -f "$LAUNCHD_BABYSITTER_PLIST" ]]; then
        echo "Launchd plists not found. Run install first."
        exit 1
      fi
      launchd_start_one "$LAUNCHD_LOOP_LABEL" "$LAUNCHD_LOOP_PLIST"
      launchd_start_one "$LAUNCHD_BABYSITTER_LABEL" "$LAUNCHD_BABYSITTER_PLIST"
      ;;
    linux)
      systemd_reload
      systemd_start
      ;;
    *)
      echo "Unsupported platform."
      exit 1
      ;;
  esac
}

stop_services() {
  case "$(platform)" in
    darwin)
      launchd_stop_one "$LAUNCHD_BABYSITTER_LABEL"
      launchd_stop_one "$LAUNCHD_LOOP_LABEL"
      ;;
    linux)
      systemd_stop
      ;;
    *)
      echo "Unsupported platform."
      exit 1
      ;;
  esac
}

restart_services() {
  stop_services
  start_services
}

status_services() {
  case "$(platform)" in
    darwin)
      launchd_status_one "$LAUNCHD_LOOP_LABEL"
      launchd_status_one "$LAUNCHD_BABYSITTER_LABEL"
      ;;
    linux)
      systemd_status
      ;;
    *)
      echo "Unsupported platform."
      exit 1
      ;;
  esac

  echo ""
  "$REPO_ROOT/scripts/loop-runner.sh" status || true
  THOUGHTSEED_SUPERVISOR_MODE=host "$REPO_ROOT/scripts/babysitter.sh" status || true
}

uninstall_services() {
  case "$(platform)" in
    darwin)
      stop_services
      rm -f "$LAUNCHD_LOOP_PLIST" "$LAUNCHD_BABYSITTER_PLIST"
      ;;
    linux)
      systemd_stop
      systemctl --user disable "$SYSTEMD_LOOP_SERVICE" "$SYSTEMD_BABYSITTER_SERVICE" >/dev/null 2>&1 || true
      rm -f "$SYSTEMD_LOOP_UNIT" "$SYSTEMD_BABYSITTER_UNIT"
      systemd_reload
      ;;
    *)
      echo "Unsupported platform."
      exit 1
      ;;
  esac
}

case "${1:-help}" in
  install)
    install_services
    ;;
  start)
    start_services
    ;;
  stop)
    stop_services
    ;;
  restart)
    restart_services
    ;;
  status)
    status_services
    ;;
  uninstall)
    uninstall_services
    ;;
  help|*)
    cat <<EOF
Thoughtseed host supervisor

Usage: $0 {install|start|stop|restart|status|uninstall}

  install    Install and start host-native services for loop-runner + babysitter
  start      Start services
  stop       Stop services
  restart    Restart services
  status     Show supervisor status + script-level status
  uninstall  Stop and remove installed service definitions
EOF
    ;;
esac
