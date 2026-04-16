#!/usr/bin/env bash
# Thoughtseed Labs -- Paperclip Cron Manager
# Manages a user crontab entry that runs the local Paperclip cycle runner.
#
# Usage:
#   ./scripts/paperclip-cron.sh install
#   ./scripts/paperclip-cron.sh uninstall
#   ./scripts/paperclip-cron.sh status
#   ./scripts/paperclip-cron.sh run-now
#
# Optional env:
#   PAPERCLIP_CYCLE_CRON   Cron schedule (default: "*/2 * * * *")
#   PAPERCLIP_CYCLE_CMD    Override command line run by cron
#   PAPERCLIP_CYCLE_LOG    Log file path (default: logs/paperclip-cycle.cron.log)

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CRON_SCHEDULE="${PAPERCLIP_CYCLE_CRON:-*/2 * * * *}"
CRON_LOG="${PAPERCLIP_CYCLE_LOG:-$REPO_ROOT/logs/paperclip-cycle.cron.log}"
MARKER_BEGIN="# THOUGHTSEED_PAPERCLIP_CYCLE_BEGIN"
MARKER_END="# THOUGHTSEED_PAPERCLIP_CYCLE_END"
SCRIPT_PATH="$REPO_ROOT/scripts/paperclip-cycle.sh"
CRON_CMD_DEFAULT="cd \"$REPO_ROOT\" && \"$SCRIPT_PATH\" >> \"$CRON_LOG\" 2>&1"
CRON_CMD="${PAPERCLIP_CYCLE_CMD:-$CRON_CMD_DEFAULT}"

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [paperclip-cron] [$level] $*" >&2
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $cmd" >&2
    exit 1
  fi
}

current_crontab() {
  crontab -l 2>/dev/null || true
}

strip_managed_block() {
  awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
    BEGIN { skip = 0 }
    $0 == begin { skip = 1; next }
    $0 == end { skip = 0; next }
    skip == 0 { print }
  '
}

managed_block_present() {
  current_crontab | awk -v begin="$MARKER_BEGIN" '$0 == begin { found = 1 } END { exit(found ? 0 : 1) }'
}

install_cron() {
  require_cmd crontab
  mkdir -p "$(dirname "$CRON_LOG")"

  local tmp_file
  tmp_file="$(mktemp)"

  current_crontab | strip_managed_block > "$tmp_file"

  {
    cat "$tmp_file"
    echo "$MARKER_BEGIN"
    echo "$CRON_SCHEDULE $CRON_CMD"
    echo "$MARKER_END"
  } | crontab -

  rm -f "$tmp_file"

  log "info" "Installed cron schedule: $CRON_SCHEDULE"
  log "info" "Command: $CRON_CMD"
  echo "Installed Thoughtseed Paperclip cron entry."
}

uninstall_cron() {
  require_cmd crontab

  if ! managed_block_present; then
    log "info" "No managed cron block present; nothing to remove"
    echo "No Thoughtseed Paperclip cron entry found."
    return
  fi

  local tmp_file
  tmp_file="$(mktemp)"
  current_crontab | strip_managed_block > "$tmp_file"
  crontab "$tmp_file"
  rm -f "$tmp_file"

  log "info" "Removed managed Paperclip cron block"
  echo "Removed Thoughtseed Paperclip cron entry."
}

status_cron() {
  require_cmd crontab

  echo "Thoughtseed Paperclip cron status"
  echo "--------------------------------"
  echo "Repo: $REPO_ROOT"
  echo "Script: $SCRIPT_PATH"
  echo "Log: $CRON_LOG"
  echo ""

  if managed_block_present; then
    echo "Managed cron block: PRESENT"
    current_crontab | awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
      $0 == begin { in_block = 1; print; next }
      in_block == 1 { print }
      $0 == end { in_block = 0 }
    '
  else
    echo "Managed cron block: ABSENT"
  fi
}

run_now() {
  if [[ ! -x "$SCRIPT_PATH" ]]; then
    echo "ERROR: Paperclip cycle script not executable: $SCRIPT_PATH" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$CRON_LOG")"
  "$SCRIPT_PATH" --with-heartbeats | tee -a "$CRON_LOG"
}

case "${1:-help}" in
  install)
    install_cron
    ;;
  uninstall|remove)
    uninstall_cron
    ;;
  status)
    status_cron
    ;;
  run-now)
    run_now
    ;;
  help|*)
    cat <<'USAGE'
Thoughtseed Paperclip Cron Manager

Usage:
  paperclip-cron.sh {install|uninstall|status|run-now}

Commands:
  install    Upsert managed crontab block for paperclip-cycle
  uninstall  Remove managed crontab block
  status     Show whether managed block exists
  run-now    Execute paperclip-cycle immediately
USAGE
    ;;
esac
