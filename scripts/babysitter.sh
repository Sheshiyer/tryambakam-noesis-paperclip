#!/usr/bin/env bash
# Thoughtseed Labs -- Babysitter Daemon
#
# Monitors loop-runner health and auto-restarts on crash.
#
# Usage:
#   ./scripts/babysitter.sh start     # Start babysitter daemon
#   ./scripts/babysitter.sh stop      # Stop babysitter
#   ./scripts/babysitter.sh status    # Show babysitter and loop-runner status

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PID_FILE="$REPO_ROOT/.thoughtseed/babysitter.pid"
LOOP_PID_FILE="$REPO_ROOT/.thoughtseed/loop-runner.pid"
LOG_DIR="$REPO_ROOT/logs"
LOG_FILE="$LOG_DIR/babysitter.log"
RUNTIME_ROOT_GUARD="$REPO_ROOT/scripts/runtime-root-guard.sh"
RESPAWN_COUNT_FILE="/tmp/thoughtseed-respawn-count"
LAST_CHECK_FILE="/tmp/thoughtseed-babysitter-lastcheck"
LAST_RESPAWN_FILE="/tmp/thoughtseed-babysitter-last-respawn"
CHECK_INTERVAL=30
MAX_RESPAWNS=3
RESPAWN_COOLDOWN_SECONDS=180
SUPERVISOR_MODE="legacy"
HOST_WAIT_LOGGED=0

assert_runtime_root() {
  if [[ ! -x "$RUNTIME_ROOT_GUARD" ]]; then
    echo "Runtime root guard missing or not executable: $RUNTIME_ROOT_GUARD" >&2
    exit 1
  fi
  "$RUNTIME_ROOT_GUARD" assert
}

check_runtime_root() {
  if [[ ! -x "$RUNTIME_ROOT_GUARD" ]]; then
    echo "Runtime root guard missing or not executable: $RUNTIME_ROOT_GUARD" >&2
    return 1
  fi
  "$RUNTIME_ROOT_GUARD" check
}

# ---- Load config ----

load_config() {
  if [[ -f "$REPO_ROOT/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$REPO_ROOT/.env"
    set +a
  fi
  MAX_RESPAWNS="${MAX_RESPAWNS:-3}"
  RESPAWN_COOLDOWN_SECONDS="${RESPAWN_COOLDOWN_SECONDS:-180}"
  SUPERVISOR_MODE="${THOUGHTSEED_SUPERVISOR_MODE:-$SUPERVISOR_MODE}"
}

# ---- Ensure directories ----

mkdir -p "$LOG_DIR" "$(dirname "$PID_FILE")"

# ---- Helpers ----

log() {
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "[$timestamp] $*" >> "$LOG_FILE"
  echo "[$timestamp] $*" >&2
}

cleanup_pid_file() {
  if [[ -f "$PID_FILE" ]]; then
    local owner_pid
    owner_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ "$owner_pid" == "$$" ]]; then
      rm -f "$PID_FILE"
    fi
  fi
}

claim_pid_file() {
  mkdir -p "$LOG_DIR" "$(dirname "$PID_FILE")"

  local existing_pid=""
  if [[ -f "$PID_FILE" ]]; then
    existing_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "$existing_pid" ]] && is_process_alive "$existing_pid"; then
      if [[ "$existing_pid" != "$$" ]]; then
        echo "Babysitter already running (PID $existing_pid)"
        exit 1
      fi
    else
      rm -f "$PID_FILE"
    fi
  fi

  printf '%s\n' "$$" > "$PID_FILE"
  trap cleanup_pid_file EXIT INT TERM
}

get_respawn_count() {
  if [[ -f "$RESPAWN_COUNT_FILE" ]]; then
    cat "$RESPAWN_COUNT_FILE"
  else
    echo "0"
  fi
}

set_respawn_count() {
  echo "$1" > "$RESPAWN_COUNT_FILE"
}

get_last_respawn_ts() {
  if [[ -f "$LAST_RESPAWN_FILE" ]]; then
    cat "$LAST_RESPAWN_FILE"
  else
    echo "0"
  fi
}

set_last_respawn_ts() {
  echo "$1" > "$LAST_RESPAWN_FILE"
}

is_process_alive() {
  local pid="$1"
  if [[ -z "$pid" ]]; then
    return 1
  fi
  if kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  ps -ax -o pid= 2>/dev/null | grep -Eq "^[[:space:]]*$pid$"
}

loop_runner_pid() {
  if [[ -f "$LOOP_PID_FILE" ]]; then
    cat "$LOOP_PID_FILE"
  else
    echo ""
  fi
}

is_loop_runner_alive() {
  local pid
  pid="$(loop_runner_pid)"
  if [[ -n "$pid" ]] && is_process_alive "$pid"; then
    return 0
  fi
  return 1
}

# ---- Signal-safe sleep ----

sleep_resilient() {
  local total_seconds="$1"
  local started now elapsed remaining
  started=$(date +%s)

  while true; do
    now=$(date +%s)
    elapsed=$((now - started))
    remaining=$((total_seconds - elapsed))
    if (( remaining <= 0 )); then
      break
    fi
    # SIGCHLD from restarted subprocesses can interrupt sleep. Under `set -e`,
    # tolerate interrupted sleeps to keep the daemon alive.
    sleep "$remaining" || true
  done
}

# ---- Commands ----

start_babysitter() {
  load_config
  assert_runtime_root

  if [[ -f "$PID_FILE" ]]; then
    local existing_pid
    existing_pid=$(cat "$PID_FILE")
    if is_process_alive "$existing_pid"; then
      echo "Babysitter already running (PID $existing_pid)"
      exit 1
    else
      log "Stale PID file found, cleaning up"
      rm -f "$PID_FILE"
    fi
  fi

  echo "Starting babysitter daemon..."
  log "Babysitter starting (max_respawns=$MAX_RESPAWNS, check_interval=${CHECK_INTERVAL}s)"

  set_respawn_count 0
  set_last_respawn_ts 0

  nohup bash "$0" _run >> "$LOG_FILE" 2>&1 &
  local daemon_pid=$!
  echo "$daemon_pid" > "$PID_FILE"
  echo "Babysitter started (PID $daemon_pid). Logs: $LOG_FILE"
}

stop_babysitter() {
  if [[ ! -f "$PID_FILE" ]]; then
    echo "No PID file found. Babysitter not running."
    exit 0
  fi

  local pid
  pid=$(cat "$PID_FILE")
  if is_process_alive "$pid"; then
    echo "Stopping babysitter (PID $pid)..."
    kill "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "Stopped."
  else
    echo "PID $pid not running. Cleaning up stale PID file."
    rm -f "$PID_FILE"
  fi
}

show_status() {
  load_config
  if ! check_runtime_root; then
    return 1
  fi

  local babysitter_status="STOPPED"
  local babysitter_pid="--"
  local loop_status="STOPPED"
  local loop_pid="--"
  local respawn_count
  respawn_count="$(get_respawn_count)"
  local last_check="unknown"

  if [[ -f "$PID_FILE" ]]; then
    babysitter_pid=$(cat "$PID_FILE")
    if is_process_alive "$babysitter_pid"; then
      babysitter_status="RUNNING"
    else
      babysitter_status="DEAD (stale PID)"
    fi
  fi

  if [[ -f "$LOOP_PID_FILE" ]]; then
    loop_pid=$(cat "$LOOP_PID_FILE")
    if is_process_alive "$loop_pid"; then
      loop_status="RUNNING"
    else
      loop_status="DEAD (stale PID)"
    fi
  fi

  if [[ -f "$LAST_CHECK_FILE" ]]; then
    local last_ts
    last_ts=$(cat "$LAST_CHECK_FILE")
    local now_ts
    now_ts=$(date +%s)
    local diff=$(( now_ts - last_ts ))
    last_check="${diff}s ago"
  fi

  echo ""
  echo "Babysitter: $babysitter_status (PID $babysitter_pid)"
  echo "Loop Runner: $loop_status (PID $loop_pid)"
  echo "Respawn Count: $respawn_count/$MAX_RESPAWNS"
  echo "Supervisor Mode: $SUPERVISOR_MODE"
  echo "Last Check: $last_check"
  echo ""
}

# ---- Main daemon loop ----

run_daemon() {
  load_config
  assert_runtime_root
  claim_pid_file

  log "Babysitter daemon loop started (mode=$SUPERVISOR_MODE)"

  while true; do
    date +%s > "$LAST_CHECK_FILE"

    if ! is_loop_runner_alive; then
      if [[ "$SUPERVISOR_MODE" == "host" ]]; then
        if [[ "$HOST_WAIT_LOGGED" -eq 0 ]]; then
          log "Loop-runner not running; waiting for host-native supervisor restart"
          HOST_WAIT_LOGGED=1
        fi
      else
        local respawn_count
        respawn_count="$(get_respawn_count)"
        local now_ts
        now_ts=$(date +%s)
        local last_respawn_ts
        last_respawn_ts="$(get_last_respawn_ts)"
        local since_last_respawn=$(( now_ts - last_respawn_ts ))

        if [[ "$respawn_count" -ge "$MAX_RESPAWNS" ]] && (( since_last_respawn < RESPAWN_COOLDOWN_SECONDS )); then
          log "Max respawns reached ($respawn_count/$MAX_RESPAWNS); retrying after cooldown (${RESPAWN_COOLDOWN_SECONDS}s)"
        else
          if [[ "$respawn_count" -ge "$MAX_RESPAWNS" ]] && (( since_last_respawn >= RESPAWN_COOLDOWN_SECONDS )); then
            log "Respawn cooldown elapsed; resetting respawn counter ($respawn_count -> 0)"
            respawn_count=0
          fi
          respawn_count=$(( respawn_count + 1 ))
          set_respawn_count "$respawn_count"
          set_last_respawn_ts "$now_ts"
          log "Loop-runner crashed, respawning (attempt $respawn_count/$MAX_RESPAWNS)"
          "$REPO_ROOT/scripts/loop-runner.sh" start 2>/dev/null || {
            log "Failed to restart loop-runner"
          }
        fi
      fi
    else
      HOST_WAIT_LOGGED=0
      local current_count
      current_count="$(get_respawn_count)"
      if [[ "$current_count" -gt 0 ]]; then
        log "Loop-runner stable, resetting respawn counter from $current_count to 0"
        set_respawn_count 0
        set_last_respawn_ts 0
      fi
    fi

    sleep_resilient "$CHECK_INTERVAL"
  done
}

# ---- Entry Point ----

case "${1:-help}" in
  start)
    start_babysitter
    ;;
  stop)
    stop_babysitter
    ;;
  status)
    show_status
    ;;
  run)
    run_daemon
    ;;
  _run)
    run_daemon
    ;;
  help|*)
    echo "Thoughtseed Labs Babysitter"
    echo ""
    echo "Usage: $0 {start|stop|status|run}"
    echo ""
    echo "  start   Start babysitter daemon (monitors loop-runner)"
    echo "  stop    Stop the babysitter"
    echo "  status  Show babysitter and loop-runner status"
    echo "  run     Run babysitter in foreground (host supervisor mode)"
    ;;
esac
