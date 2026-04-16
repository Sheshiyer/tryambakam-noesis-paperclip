#!/usr/bin/env bash
# Thoughtseed Labs Loop Runner — Local Orchestrator Daemon
# Triggers agent cycles on schedule based on manifest.yaml tier intervals.
# Uses codex CLI for agent execution.
#
# Usage:
#   ./scripts/loop-runner.sh run                        # Run in foreground (daemon mode)
#   ./scripts/loop-runner.sh run --once --agent atlas    # Single cycle for one agent
#   ./scripts/loop-runner.sh status                     # Check if daemon is running
#   ./scripts/loop-runner.sh stop                       # Stop the running daemon
#   ./scripts/loop-runner.sh start                      # Start in background

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SCRIPT_DIR="$REPO_ROOT/scripts"
PID_FILE="$REPO_ROOT/.thoughtseed/loop-runner.pid"
LOG_DIR="$REPO_ROOT/logs"
LOG_FILE="$LOG_DIR/loop-runner.log"
PAPERCLIP_CYCLE_SCRIPT="$SCRIPT_DIR/paperclip-cycle.sh"

CODEX_BIN="${CODEX_BIN:-$(command -v codex 2>/dev/null || echo "codex")}"

# ---- Defaults ----

MAX_CONCURRENT=2
CHECK_INTERVAL=60
WORKING_HOURS_ONLY=false
START_HOUR=9
END_HOUR=17
LOG_LEVEL="info"
PAPERCLIP_CYCLE_ENABLED=true
PAPERCLIP_CYCLE_INTERVAL=120
PAPERCLIP_CYCLE_WITH_HEARTBEATS=false
LAST_PAPERCLIP_CYCLE=0

# Tier intervals in seconds
TIER_1_INTERVAL=300     # 5 minutes  -- Chief (JARVIS)
TIER_2_LEAD_INTERVAL=600   # 10 minutes -- Department leads
TIER_2_MEMBER_INTERVAL=900  # 15 minutes -- Members

# ---- Load configuration ----

load_config() {
  if [[ -f "$REPO_ROOT/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$REPO_ROOT/.env"
    set +a
  fi

  MAX_CONCURRENT="${LOOP_MAX_CONCURRENT:-$MAX_CONCURRENT}"
  CHECK_INTERVAL="${LOOP_CHECK_INTERVAL:-$CHECK_INTERVAL}"
  WORKING_HOURS_ONLY="${LOOP_WORKING_HOURS_ONLY:-$WORKING_HOURS_ONLY}"
  START_HOUR="${LOOP_START_HOUR:-$START_HOUR}"
  END_HOUR="${LOOP_END_HOUR:-$END_HOUR}"

  # Read intervals from manifest.yaml if available
  local manifest="$REPO_ROOT/manifest.yaml"
  if [[ -f "$manifest" ]]; then
    local t1 t2l t2m
    t1=$(grep -A5 "intervals:" "$manifest" | grep "tier_1:" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs 2>/dev/null || true)
    t2l=$(grep -A5 "intervals:" "$manifest" | grep "tier_2_lead:" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs 2>/dev/null || true)
    t2m=$(grep -A5 "intervals:" "$manifest" | grep "tier_2_member:" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs 2>/dev/null || true)
    case "$t1" in
      *m) TIER_1_INTERVAL=$(( ${t1%m} * 60 )) ;;
    esac
    case "$t2l" in
      *m) TIER_2_LEAD_INTERVAL=$(( ${t2l%m} * 60 )) ;;
    esac
    case "$t2m" in
      *m) TIER_2_MEMBER_INTERVAL=$(( ${t2m%m} * 60 )) ;;
    esac

    # Paperclip sync settings from manifest.
    local issues_to_inbox heartbeat_reporting
    issues_to_inbox=$(grep -A10 "^  paperclip:" "$manifest" | grep "issues_to_inbox:" | head -1 | awk '{print $2}' 2>/dev/null || true)
    heartbeat_reporting=$(grep -A10 "^  paperclip:" "$manifest" | grep "heartbeat_reporting:" | head -1 | awk '{print $2}' 2>/dev/null || true)
    if [[ "$issues_to_inbox" == "false" ]]; then
      PAPERCLIP_CYCLE_ENABLED=false
    fi
    if [[ "$heartbeat_reporting" == "true" ]]; then
      PAPERCLIP_CYCLE_WITH_HEARTBEATS=true
    fi
  fi

  # Explicit environment overrides win over manifest defaults.
  PAPERCLIP_CYCLE_ENABLED="${LOOP_PAPERCLIP_CYCLE_ENABLED:-$PAPERCLIP_CYCLE_ENABLED}"
  PAPERCLIP_CYCLE_INTERVAL="${LOOP_PAPERCLIP_CYCLE_INTERVAL:-$PAPERCLIP_CYCLE_INTERVAL}"
  PAPERCLIP_CYCLE_WITH_HEARTBEATS="${LOOP_PAPERCLIP_CYCLE_WITH_HEARTBEATS:-$PAPERCLIP_CYCLE_WITH_HEARTBEATS}"
}

# ---- Logging ----

log() {
  local level="$1"
  shift
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "[$timestamp] [$level] $*" >> "$LOG_FILE"
  if [[ "$level" != "debug" ]] || [[ "$LOG_LEVEL" == "debug" ]]; then
    echo "[$timestamp] [$level] $*"
  fi
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
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
      if [[ "$existing_pid" != "$$" ]]; then
        echo "Loop runner already running (PID $existing_pid)"
        exit 1
      fi
    else
      rm -f "$PID_FILE"
    fi
  fi

  printf '%s\n' "$$" > "$PID_FILE"
  trap cleanup_pid_file EXIT INT TERM
}

# ---- Agent Discovery ----

declare -A AGENT_TIERS
declare -A AGENT_LAST_RUN
declare -A AGENT_INTERVALS
declare -A AGENT_PIDS

discover_agents() {
  log "info" "Discovering agents from manifest..."

  local chief
  chief=$(grep -A1 "chief:" "$REPO_ROOT/manifest.yaml" | grep "agent:" | awk '{print $2}' | head -1 2>/dev/null || true)

  if [[ -n "$chief" ]]; then
    AGENT_TIERS["$chief"]="tier_1"
    AGENT_INTERVALS["$chief"]=$TIER_1_INTERVAL
    AGENT_LAST_RUN["$chief"]=0
    log "info" "  Chief: $chief (${TIER_1_INTERVAL}s interval)"
  fi

  for agent_dir in "$REPO_ROOT"/agents/*/; do
    local agent_id
    agent_id="$(basename "$agent_dir")"

    if [[ "${AGENT_TIERS[$agent_id]:-}" == "tier_1" ]]; then
      continue
    fi

    local manifest="$agent_dir/MANIFEST.yaml"
    if [[ ! -f "$manifest" ]]; then
      log "warn" "  No MANIFEST.yaml for $agent_id, skipping"
      continue
    fi

    local interval
    interval=$(grep -A5 "^loop:" "$manifest" | grep "interval:" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs 2>/dev/null || true)

    case "$interval" in
      "5m")
        AGENT_TIERS["$agent_id"]="tier_1"
        AGENT_INTERVALS["$agent_id"]=$TIER_1_INTERVAL
        ;;
      "10m")
        AGENT_TIERS["$agent_id"]="tier_2_lead"
        AGENT_INTERVALS["$agent_id"]=$TIER_2_LEAD_INTERVAL
        ;;
      "15m"|*)
        AGENT_TIERS["$agent_id"]="tier_2_member"
        AGENT_INTERVALS["$agent_id"]=$TIER_2_MEMBER_INTERVAL
        ;;
    esac

    AGENT_LAST_RUN["$agent_id"]=0
    log "info" "  Agent: $agent_id (${AGENT_INTERVALS[$agent_id]}s interval, ${AGENT_TIERS[$agent_id]})"
  done

  local agent_count=0
  local discovered_agent_id
  for discovered_agent_id in "${!AGENT_TIERS[@]}"; do
    agent_count=$((agent_count + 1))
  done
  log "info" "Discovered ${agent_count} agents"
}

# ---- Working Hours Check ----

is_within_working_hours() {
  if [[ "$WORKING_HOURS_ONLY" != "true" ]]; then
    return 0
  fi
  local current_hour
  current_hour=$(date +"%H")
  if (( current_hour >= START_HOUR && current_hour < END_HOUR )); then
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
    # Background child exits can interrupt sleep (SIGCHLD). Under `set -e`,
    # that non-zero exit would kill the daemon unless we explicitly tolerate it.
    sleep "$remaining" || true
  done
}

# ---- Timeout Wrapper (macOS/Linux compatible) ----

run_with_timeout() {
  local seconds="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
    return $?
  fi

  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$seconds" "$@"
    return $?
  fi

  # Fallback: run without an external timeout binary.
  if [[ "${TIMEOUT_FALLBACK_WARNED:-0}" -eq 0 ]]; then
    log "warn" "No timeout/gtimeout binary available; using python timeout fallback"
    TIMEOUT_FALLBACK_WARNED=1
  fi

  python3 -c '
import subprocess
import sys

timeout_seconds = int(sys.argv[1])
cmd = sys.argv[2:]

proc = subprocess.Popen(cmd)
try:
    proc.wait(timeout=timeout_seconds)
    raise SystemExit(proc.returncode)
except subprocess.TimeoutExpired:
    proc.kill()
    try:
        proc.wait(timeout=5)
    except Exception:
        pass
    raise SystemExit(124)
' "$seconds" "$@"
}

# ---- Structured Output Recovery ----

recover_structured_output_from_stderr() {
  local output_file="$1"
  local error_file="$2"

  if [[ -s "$output_file" ]] || [[ ! -s "$error_file" ]]; then
    return
  fi

  if ! grep -q "===THOUGHTSEED_OUTPUT_START===" "$error_file"; then
    return
  fi

  local recovered_file="${output_file}.recovered"
  python3 - "$error_file" "$recovered_file" <<'PY'
import sys

src = sys.argv[1]
dst = sys.argv[2]

with open(src, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

start_marker = "===THOUGHTSEED_OUTPUT_START==="
end_marker = "===THOUGHTSEED_OUTPUT_END==="

last_start = text.rfind(start_marker)
if last_start == -1:
    open(dst, "w").close()
    raise SystemExit(0)

last_end = text.find(end_marker, last_start)
if last_end == -1:
    open(dst, "w").close()
    raise SystemExit(0)

block = text[last_start:last_end + len(end_marker)]

# Guardrail: ignore prompt-template blocks that contain parser placeholders.
disallowed_markers = [
    "[Write the COMPLETE updated TASKS.md content here.",
    "[Write the COMPLETE updated INBOX.md content here.",
    "[ONLY if you have new pitfalls or learnings to add."
]
if any(marker in block for marker in disallowed_markers):
    open(dst, "w").close()
    raise SystemExit(0)

with open(dst, "w", encoding="utf-8") as f:
    f.write(block)
PY

  if [[ -s "$recovered_file" ]]; then
    mv "$recovered_file" "$output_file"
    log "warn" "Recovered structured output from stderr fallback: $(basename "$error_file")"
  else
    rm -f "$recovered_file"
  fi
}

# ---- Agent Invocation ----

RUNNING_AGENTS=0
TIMEOUT_FALLBACK_WARNED=0

invoke_agent() {
  local agent_id="$1"

  if (( RUNNING_AGENTS >= MAX_CONCURRENT )); then
    log "debug" "Skipping $agent_id -- max concurrent ($MAX_CONCURRENT) reached"
    return
  fi

  log "info" ">>> Triggering cycle for $agent_id (${AGENT_TIERS[$agent_id]})"

  local ts
  ts=$(date +%s)
  local prompt_file="/tmp/thoughtseed-prompt-${agent_id}-${ts}.txt"
  local output_file="/tmp/thoughtseed-output-${agent_id}-${ts}.txt"
  local error_file="/tmp/thoughtseed-error-${agent_id}-${ts}.txt"

  # Lock check with PID-aware stale lock recovery (macOS compatible).
  local lock_dir="/tmp/thoughtseed-lock-${agent_id}"
  local lock_pid_file="$lock_dir/pid"
  if mkdir "$lock_dir" 2>/dev/null; then
    printf '%s\n' "$$" > "$lock_pid_file" 2>/dev/null || true
  else
    local existing_pid=""
    if [[ -f "$lock_pid_file" ]]; then
      existing_pid="$(cat "$lock_pid_file" 2>/dev/null || true)"
    fi

    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
      log "debug" "Skipping $agent_id -- already running (lock PID $existing_pid)"
      return
    fi

    log "warn" "Removing stale lock for $agent_id: $lock_dir"
    rm -rf "$lock_dir" 2>/dev/null || true
    if ! mkdir "$lock_dir" 2>/dev/null; then
      log "debug" "Skipping $agent_id -- lock busy after stale-lock cleanup"
      return
    fi
    printf '%s\n' "$$" > "$lock_pid_file" 2>/dev/null || true
  fi

  # Assemble prompt
  if ! "$SCRIPT_DIR/agent-prompt-assembler.sh" "$agent_id" > "$prompt_file" 2>>"$LOG_FILE"; then
    log "error" "Failed to assemble prompt for $agent_id"
    rm -rf "$lock_dir" 2>/dev/null || true
    rm -f "$prompt_file"
    return
  fi

  # Get timeout from agent MANIFEST.yaml (default 240s = 4min)
  local manifest="$REPO_ROOT/agents/$agent_id/MANIFEST.yaml"
  local timeout_val=240
  if [[ -f "$manifest" ]]; then
    local timeout_str
    timeout_str=$(grep -A10 "^loop:" "$manifest" | grep "max_step_timeout:" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs 2>/dev/null || echo "")
    case "$timeout_str" in
      *m) timeout_val=$(( ${timeout_str%m} * 60 )) ;;
      *s) timeout_val=${timeout_str%s} ;;
    esac
  fi

  AGENT_LAST_RUN["$agent_id"]=$(date +%s)

  local start_time
  start_time=$(date +%s)
  RUNNING_AGENTS=$((RUNNING_AGENTS + 1))

  (
    set +e

    # Run codex in non-interactive mode and capture only the final message.
    run_with_timeout "$timeout_val" "$CODEX_BIN" exec --model gpt-5.4 --full-auto -C "$REPO_ROOT" --output-last-message "$output_file" - < "$prompt_file" 2>"$error_file"
    local exit_code=$?
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Persist stderr context to the loop log for failed/empty runs.
    if [[ -s "$error_file" ]]; then
      sed 's/^/[codex-stderr] /' "$error_file" >> "$LOG_FILE"
    fi

    # `--output-last-message` may be empty on timeout while stderr still carries
    # valid THOUGHTSEED markers. Recover it before parser handoff.
    recover_structured_output_from_stderr "$output_file" "$error_file"

    set -e

    # Parse output
    local parsed_file="/tmp/thoughtseed-parsed-${agent_id}-$(date +%s).json"
    "$SCRIPT_DIR/agent-output-parser.sh" "$output_file" > "$parsed_file"

    # Write back results to agent files
    "$SCRIPT_DIR/write-back.sh" "$agent_id" "$parsed_file"

    # Determine outcome from exit code
    local outcome="completed"
    if [[ $exit_code -eq 124 ]]; then
      outcome="timeout"
    elif [[ $exit_code -ne 0 ]]; then
      outcome="failed"
    fi

    # Write heartbeat entry
    "$SCRIPT_DIR/heartbeat-writer.sh" "$agent_id" "cycle-${ts}" "$outcome" "$duration"

    # Clean up temp files
    rm -f "$prompt_file" "$output_file" "$error_file" "$parsed_file"

    # Release lock (remove PID file + lock directory).
    rm -rf "$lock_dir" 2>/dev/null || true
  ) &

  local child_pid=$!
  printf '%s\n' "$child_pid" > "$lock_pid_file" 2>/dev/null || true
  AGENT_PIDS["$agent_id"]=$child_pid
  log "info" "  Agent $agent_id running as PID $child_pid (timeout: ${timeout_val}s)"
}

# ---- Reap Finished Background Agents ----

reap_finished_agents() {
  for agent_id in "${!AGENT_PIDS[@]}"; do
    local pid=${AGENT_PIDS[$agent_id]}
    if ! kill -0 "$pid" 2>/dev/null; then
      # Child non-zero exits are handled in their own cycle logs; do not crash the daemon.
      wait "$pid" 2>/dev/null || true
      unset "AGENT_PIDS[$agent_id]"
      RUNNING_AGENTS=$((RUNNING_AGENTS - 1))
      if (( RUNNING_AGENTS < 0 )); then
        RUNNING_AGENTS=0
      fi
      log "debug" "Reaped finished agent $agent_id (was PID $pid)"
    fi
  done
}

# ---- Paperclip Cycle Integration ----

run_paperclip_cycle_once() {
  if [[ "$PAPERCLIP_CYCLE_ENABLED" != "true" ]]; then
    log "debug" "Paperclip cycle disabled"
    return 0
  fi

  if [[ ! -x "$PAPERCLIP_CYCLE_SCRIPT" ]]; then
    log "warn" "Paperclip cycle script not executable: $PAPERCLIP_CYCLE_SCRIPT"
    return 1
  fi

  local cycle_args=()
  if [[ "$PAPERCLIP_CYCLE_WITH_HEARTBEATS" == "true" ]]; then
    cycle_args+=(--with-heartbeats)
  fi

  log "info" "Running Paperclip cycle (with_heartbeats=$PAPERCLIP_CYCLE_WITH_HEARTBEATS)"
  "$PAPERCLIP_CYCLE_SCRIPT" "${cycle_args[@]}" >> "$LOG_FILE" 2>&1
}

run_paperclip_cycle_if_due() {
  local now="$1"

  if [[ "$PAPERCLIP_CYCLE_ENABLED" != "true" ]]; then
    return
  fi

  local elapsed=$(( now - LAST_PAPERCLIP_CYCLE ))
  if (( elapsed < PAPERCLIP_CYCLE_INTERVAL )); then
    return
  fi

  LAST_PAPERCLIP_CYCLE="$now"
  if ! run_paperclip_cycle_once; then
    log "warn" "Paperclip cycle failed"
  fi
}

# ---- Single Agent Run ----

run_once() {
  local agent_id="$1"
  if [[ ! -d "$REPO_ROOT/agents/$agent_id" ]]; then
    log "error" "Agent not found: $agent_id"
    exit 1
  fi

  # Force-register this agent if not already discovered
  if [[ -z "${AGENT_TIERS[$agent_id]:-}" ]]; then
    AGENT_TIERS["$agent_id"]="manual"
    AGENT_INTERVALS["$agent_id"]=0
    AGENT_LAST_RUN["$agent_id"]=0
  fi

  log "info" "Running single cycle for agent: $agent_id"
  invoke_agent "$agent_id"

  # Wait for it to finish
  if [[ -n "${AGENT_PIDS[$agent_id]:-}" ]]; then
    wait "${AGENT_PIDS[$agent_id]}" 2>/dev/null || true
  fi
  log "info" "Single cycle complete for $agent_id"
}

# ---- Main Loop ----

run_loop() {
  log "info" "=== Thoughtseed Labs Loop Runner started ==="
  log "info" "Config: max_concurrent=$MAX_CONCURRENT, working_hours=$WORKING_HOURS_ONLY ($START_HOUR-$END_HOUR)"
  log "info" "Check interval: ${CHECK_INTERVAL}s"

  while true; do
    if ! is_within_working_hours; then
      log "debug" "Outside working hours, sleeping..."
      sleep_resilient "$CHECK_INTERVAL"
      continue
    fi

    reap_finished_agents

    local now
    now=$(date +%s)

    run_paperclip_cycle_if_due "$now"

    for agent_id in "${!AGENT_TIERS[@]}"; do
      local last_run=${AGENT_LAST_RUN[$agent_id]}
      local interval=${AGENT_INTERVALS[$agent_id]}
      local elapsed=$(( now - last_run ))

      if (( elapsed >= interval )); then
        invoke_agent "$agent_id"
      fi
    done

    sleep_resilient "$CHECK_INTERVAL"
  done
}

# ---- Daemon Control ----

start_daemon() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Loop runner already running (PID $(cat "$PID_FILE"))"
    exit 1
  fi

  mkdir -p "$LOG_DIR" "$(dirname "$PID_FILE")"

  echo "Starting loop runner daemon..."
  nohup bash "$0" _run >/dev/null 2>&1 &
  echo $! > "$PID_FILE"
  echo "Loop runner started (PID $!). Logs: $LOG_FILE"
}

stop_daemon() {
  if [[ ! -f "$PID_FILE" ]]; then
    echo "No PID file found. Loop runner not running."
    exit 0
  fi

  local pid
  pid=$(cat "$PID_FILE")
  if kill -0 "$pid" 2>/dev/null; then
    echo "Stopping loop runner (PID $pid)..."
    kill "$pid"
    rm -f "$PID_FILE"
    echo "Stopped."
  else
    echo "PID $pid not running. Cleaning up stale PID file."
    rm -f "$PID_FILE"
  fi
}

show_status() {
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Loop runner: RUNNING (PID $(cat "$PID_FILE"))"
    echo "Log file: $LOG_FILE"
    if [[ -f "$LOG_FILE" ]]; then
      echo ""
      echo "Last 5 log entries:"
      tail -5 "$LOG_FILE"
    fi
  else
    echo "Loop runner: STOPPED"
  fi
}

# ---- Entry Point ----

case "${1:-help}" in
  start)
    start_daemon
    ;;
  stop)
    stop_daemon
    ;;
  status)
    show_status
    ;;
  run)
    mkdir -p "$LOG_DIR" "$(dirname "$PID_FILE")"
    load_config
    discover_agents

    # Check for --once --agent flags
    shift
    ONCE_MODE=false
    ONCE_AGENT=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --once) ONCE_MODE=true; shift ;;
        --agent) ONCE_AGENT="$2"; shift 2 ;;
        *) shift ;;
      esac
    done

    if [[ "$ONCE_MODE" == "true" && -n "$ONCE_AGENT" ]]; then
      run_once "$ONCE_AGENT"
    else
      claim_pid_file
      run_loop
    fi
    ;;
  paperclip-cycle)
    mkdir -p "$LOG_DIR" "$(dirname "$PID_FILE")"
    load_config
    if run_paperclip_cycle_once; then
      echo "Paperclip cycle completed."
    else
      echo "Paperclip cycle failed."
      exit 1
    fi
    ;;
  _run)
    mkdir -p "$LOG_DIR" "$(dirname "$PID_FILE")"
    load_config
    discover_agents
    claim_pid_file
    run_loop
    ;;
  help|*)
    echo "Thoughtseed Labs Loop Runner"
    echo ""
    echo "Usage: $0 {start|stop|status|run|paperclip-cycle}"
    echo ""
    echo "  start                           Start the loop daemon in background"
    echo "  stop                            Stop the running daemon"
    echo "  status                          Check if daemon is running"
    echo "  run                             Run in foreground (daemon mode)"
    echo "  run --once --agent <name>       Run single cycle for one agent"
    echo "  paperclip-cycle                 Run one Paperclip sync+reconcile cycle"
    ;;
esac
