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
RUNTIME_ROOT_GUARD="$SCRIPT_DIR/runtime-root-guard.sh"

CODEX_BIN="${CODEX_BIN:-$(command -v codex 2>/dev/null || echo "codex")}"
CODEX_MODEL="${LOOP_CODEX_MODEL:-gpt-5.4}"
CODEX_REASONING_EFFORT="${LOOP_CODEX_REASONING_EFFORT:-medium}"
# Codex CLI 0.121+ expects `features.notify` to be a boolean. Some legacy
# user configs still set it as an array, which makes `codex exec` exit before
# producing any output. Keep a compatibility override at invocation time.
CODEX_FEATURES_NOTIFY_OVERRIDE="${CODEX_FEATURES_NOTIFY_OVERRIDE:-true}"

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
PAPERCLIP_SIGNAL_LANE_ENABLED=true
PAPERCLIP_SIGNAL_LANE_DISPATCH_ENABLED=true
PAPERCLIP_SIGNAL_LANE_COOLDOWN_MINUTES=180
PAPERCLIP_SIGNAL_LANE_READY_THRESHOLD=70
PAPERCLIP_SIGNAL_LANE_EXPERIMENT_THRESHOLD=50
LAST_PAPERCLIP_CYCLE=0
TIMEOUT_PROMPT_SIZE_STEP_BYTES=50000
TIMEOUT_PROMPT_SIZE_STEP_SECONDS=60
TIMEOUT_MAX_SECONDS=900

# Tier intervals in seconds
TIER_1_INTERVAL=300     # 5 minutes  -- Chief (JARVIS)
TIER_2_LEAD_INTERVAL=600   # 10 minutes -- Department leads
TIER_2_MEMBER_INTERVAL=900  # 15 minutes -- Members

# ---- YAML Helpers ----

YAML_HELPERS_SCRIPT="$SCRIPT_DIR/yaml-helpers.sh"
if [[ ! -f "$YAML_HELPERS_SCRIPT" ]]; then
  echo "YAML helpers script missing: $YAML_HELPERS_SCRIPT" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$YAML_HELPERS_SCRIPT"

is_false_value() {
  yaml_is_false "${1:-}"
}

is_true_value() {
  yaml_is_true "${1:-}"
}

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
    t1=$(yaml_path_get "$manifest" "intervals.tier_1")
    t2l=$(yaml_path_get "$manifest" "intervals.tier_2_lead")
    t2m=$(yaml_path_get "$manifest" "intervals.tier_2_member")
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
    local signal_lane_enabled signal_lane_dispatch_enabled signal_lane_cooldown_minutes
    local signal_lane_ready_threshold signal_lane_experiment_threshold
    issues_to_inbox=$(yaml_path_get "$manifest" "org.paperclip.sync.issues_to_inbox")
    if [[ -z "$issues_to_inbox" ]]; then
      issues_to_inbox=$(yaml_path_get "$manifest" "org.paperclip.issues_to_inbox")
    fi
    heartbeat_reporting=$(yaml_path_get "$manifest" "org.paperclip.sync.heartbeat_reporting")
    if [[ -z "$heartbeat_reporting" ]]; then
      heartbeat_reporting=$(yaml_path_get "$manifest" "org.paperclip.heartbeat_reporting")
    fi
    signal_lane_enabled=$(yaml_path_get "$manifest" "org.signal_lane.enabled")
    if [[ -z "$signal_lane_enabled" ]]; then
      signal_lane_enabled=$(yaml_path_get "$manifest" "signal_lane.enabled")
    fi
    signal_lane_dispatch_enabled=$(yaml_path_get "$manifest" "org.signal_lane.dispatch_enabled")
    if [[ -z "$signal_lane_dispatch_enabled" ]]; then
      signal_lane_dispatch_enabled=$(yaml_path_get "$manifest" "signal_lane.dispatch_enabled")
    fi
    signal_lane_cooldown_minutes=$(yaml_path_get "$manifest" "org.signal_lane.cooldown_minutes")
    if [[ -z "$signal_lane_cooldown_minutes" ]]; then
      signal_lane_cooldown_minutes=$(yaml_path_get "$manifest" "signal_lane.cooldown_minutes")
    fi
    signal_lane_ready_threshold=$(yaml_path_get "$manifest" "org.signal_lane.ready_threshold")
    if [[ -z "$signal_lane_ready_threshold" ]]; then
      signal_lane_ready_threshold=$(yaml_path_get "$manifest" "signal_lane.ready_threshold")
    fi
    signal_lane_experiment_threshold=$(yaml_path_get "$manifest" "org.signal_lane.experiment_threshold")
    if [[ -z "$signal_lane_experiment_threshold" ]]; then
      signal_lane_experiment_threshold=$(yaml_path_get "$manifest" "signal_lane.experiment_threshold")
    fi
    if is_false_value "$issues_to_inbox"; then
      PAPERCLIP_CYCLE_ENABLED=false
    fi
    if is_true_value "$heartbeat_reporting"; then
      PAPERCLIP_CYCLE_WITH_HEARTBEATS=true
    fi
    if is_false_value "$signal_lane_enabled"; then
      PAPERCLIP_SIGNAL_LANE_ENABLED=false
    fi
    if is_false_value "$signal_lane_dispatch_enabled"; then
      PAPERCLIP_SIGNAL_LANE_DISPATCH_ENABLED=false
    fi
    if [[ -n "$signal_lane_cooldown_minutes" ]]; then
      PAPERCLIP_SIGNAL_LANE_COOLDOWN_MINUTES="$signal_lane_cooldown_minutes"
    fi
    if [[ -n "$signal_lane_ready_threshold" ]]; then
      PAPERCLIP_SIGNAL_LANE_READY_THRESHOLD="$signal_lane_ready_threshold"
    fi
    if [[ -n "$signal_lane_experiment_threshold" ]]; then
      PAPERCLIP_SIGNAL_LANE_EXPERIMENT_THRESHOLD="$signal_lane_experiment_threshold"
    fi
  fi

  # Explicit environment overrides win over manifest defaults.
  PAPERCLIP_CYCLE_ENABLED="${LOOP_PAPERCLIP_CYCLE_ENABLED:-$PAPERCLIP_CYCLE_ENABLED}"
  PAPERCLIP_CYCLE_INTERVAL="${LOOP_PAPERCLIP_CYCLE_INTERVAL:-$PAPERCLIP_CYCLE_INTERVAL}"
  PAPERCLIP_CYCLE_WITH_HEARTBEATS="${LOOP_PAPERCLIP_CYCLE_WITH_HEARTBEATS:-$PAPERCLIP_CYCLE_WITH_HEARTBEATS}"
  PAPERCLIP_SIGNAL_LANE_ENABLED="${LOOP_SIGNAL_LANE_ENABLED:-$PAPERCLIP_SIGNAL_LANE_ENABLED}"
  PAPERCLIP_SIGNAL_LANE_DISPATCH_ENABLED="${LOOP_SIGNAL_LANE_DISPATCH_ENABLED:-$PAPERCLIP_SIGNAL_LANE_DISPATCH_ENABLED}"
  PAPERCLIP_SIGNAL_LANE_COOLDOWN_MINUTES="${LOOP_SIGNAL_LANE_COOLDOWN_MINUTES:-$PAPERCLIP_SIGNAL_LANE_COOLDOWN_MINUTES}"
  PAPERCLIP_SIGNAL_LANE_READY_THRESHOLD="${LOOP_SIGNAL_LANE_READY_THRESHOLD:-$PAPERCLIP_SIGNAL_LANE_READY_THRESHOLD}"
  PAPERCLIP_SIGNAL_LANE_EXPERIMENT_THRESHOLD="${LOOP_SIGNAL_LANE_EXPERIMENT_THRESHOLD:-$PAPERCLIP_SIGNAL_LANE_EXPERIMENT_THRESHOLD}"
  TIMEOUT_PROMPT_SIZE_STEP_BYTES="${LOOP_TIMEOUT_PROMPT_SIZE_STEP_BYTES:-$TIMEOUT_PROMPT_SIZE_STEP_BYTES}"
  TIMEOUT_PROMPT_SIZE_STEP_SECONDS="${LOOP_TIMEOUT_PROMPT_SIZE_STEP_SECONDS:-$TIMEOUT_PROMPT_SIZE_STEP_SECONDS}"
  TIMEOUT_MAX_SECONDS="${LOOP_TIMEOUT_MAX_SECONDS:-$TIMEOUT_MAX_SECONDS}"
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

process_is_alive() {
  local pid="$1"
  if [[ -z "$pid" ]]; then
    return 1
  fi
  if kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  ps -ax -o pid= 2>/dev/null | grep -Eq "^[[:space:]]*$pid$"
}

loop_runner_process_pids() {
  local script_path="$SCRIPT_DIR/loop-runner.sh"
  ps -ax -o pid= -o ppid= -o command= 2>/dev/null | awk -v script="$script_path" '
    {
      pid = $1
      ppid = $2
      $1 = ""
      $2 = ""
      sub(/^[[:space:]]+/, "", $0)
      if ($0 ~ ("(^|[[:space:]])" script "([[:space:]]|$)") && $0 ~ /[[:space:]](_run|run)([[:space:]]|$)/) {
        candidate_ppid[pid] = ppid
      }
    }
    END {
      # Keep only top-level runners (not shell children spawned per-agent).
      for (pid in candidate_ppid) {
        ppid = candidate_ppid[pid]
        if (!(ppid in candidate_ppid)) {
          print pid
        }
      }
    }
  '
}

collect_loop_runner_pids() {
  local pid_file_pid=""
  if [[ -f "$PID_FILE" ]]; then
    pid_file_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  fi

  {
    if process_is_alive "$pid_file_pid"; then
      echo "$pid_file_pid"
    fi
    loop_runner_process_pids
  } | awk 'NF && !seen[$0]++'
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

handle_termination() {
  cleanup_pid_file
  exit 0
}

claim_pid_file() {
  mkdir -p "$LOG_DIR" "$(dirname "$PID_FILE")"

  # Detect any existing runner process, even if PID file drifted.
  local existing_runner_pids
  existing_runner_pids="$(loop_runner_process_pids | awk -v self="$$" '$0 != self')"
  if [[ -n "$existing_runner_pids" ]]; then
    echo "Loop runner already running (PID(s): $(echo "$existing_runner_pids" | tr '\n' ' ' | xargs))"
    exit 1
  fi

  local existing_pid=""
  if [[ -f "$PID_FILE" ]]; then
    existing_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if process_is_alive "$existing_pid"; then
      if [[ "$existing_pid" != "$$" ]]; then
        echo "Loop runner already running (PID $existing_pid)"
        exit 1
      fi
    else
      rm -f "$PID_FILE"
    fi
  fi

  printf '%s\n' "$$" > "$PID_FILE"
  trap cleanup_pid_file EXIT
  trap handle_termination INT TERM
}

# ---- Agent Discovery ----

declare -A AGENT_TIERS=()
declare -A AGENT_LAST_RUN=()
declare -A AGENT_INTERVALS=()
declare -A AGENT_PIDS=()

discover_agents() {
  log "info" "Discovering agents from manifest..."

  local chief
  chief=$(yaml_path_get "$REPO_ROOT/manifest.yaml" "org.chief.agent")
  if [[ -z "$chief" ]]; then
    chief=$(yaml_path_get "$REPO_ROOT/manifest.yaml" "chief.agent")
  fi

  if [[ -n "$chief" ]]; then
    AGENT_TIERS["$chief"]="tier_1"
    AGENT_INTERVALS["$chief"]=$TIER_1_INTERVAL
    AGENT_LAST_RUN["$chief"]=0
    log "info" "  Chief: $chief (${TIER_1_INTERVAL}s interval)"
  fi

  local agent_dirs=()
  shopt -s nullglob
  agent_dirs=("$REPO_ROOT"/agents/*/)
  shopt -u nullglob

  for agent_dir in "${agent_dirs[@]}"; do
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
    interval=$(yaml_path_get "$manifest" "loop.interval")

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
import re
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

pattern = r"---FILE_UPDATE:\s*([^-\n]+?)\s*---\n(.*?)---END_FILE_UPDATE---"
matches = re.findall(pattern, block, re.DOTALL)
if not matches:
    open(dst, "w").close()
    raise SystemExit(0)

allowed_files = {"TASKS.md", "HEARTBEAT.md", "INBOX.md", "CONTEXT.md"}
required_files = {"TASKS.md", "HEARTBEAT.md", "INBOX.md", "CONTEXT.md"}
updates = {}

for filename, content in matches:
    fname = filename.strip()
    body = content.strip()
    if fname not in allowed_files:
        open(dst, "w").close()
        raise SystemExit(0)
    if fname in updates:
        open(dst, "w").close()
        raise SystemExit(0)
    updates[fname] = body

if set(updates.keys()) != required_files:
    open(dst, "w").close()
    raise SystemExit(0)

def looks_like_template_placeholder(filename: str, content: str) -> bool:
    trimmed = content.strip()
    if filename in {"TASKS.md", "INBOX.md", "CONTEXT.md"}:
        # Prompt template placeholders are bracket-wrapped directives.
        if trimmed.startswith("[") and trimmed.endswith("]"):
            return True
    if filename == "HEARTBEAT.md":
        # Placeholder heartbeat uses bracketed tokens in these fields.
        if "- Step: [" in trimmed or "- Outcome: [" in trimmed or "- Duration: [" in trimmed:
            return True
    return False

if any(looks_like_template_placeholder(fname, body) for fname, body in updates.items()):
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

    if process_is_alive "$existing_pid"; then
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
    timeout_str=$(yaml_path_get "$manifest" "loop.max_step_timeout")
    case "$timeout_str" in
      *m) timeout_val=$(( ${timeout_str%m} * 60 )) ;;
      *s) timeout_val=${timeout_str%s} ;;
    esac
  fi

  local prompt_size_bytes
  prompt_size_bytes=$(wc -c < "$prompt_file" | tr -d ' ')
  local adaptive_timeout="$timeout_val"
  if (( TIMEOUT_PROMPT_SIZE_STEP_BYTES > 0 && TIMEOUT_PROMPT_SIZE_STEP_SECONDS > 0 )); then
    local timeout_extra_steps=$(( prompt_size_bytes / TIMEOUT_PROMPT_SIZE_STEP_BYTES ))
    if (( timeout_extra_steps > 0 )); then
      adaptive_timeout=$(( adaptive_timeout + (timeout_extra_steps * TIMEOUT_PROMPT_SIZE_STEP_SECONDS) ))
    fi
  fi
  if (( TIMEOUT_MAX_SECONDS > 0 && adaptive_timeout > TIMEOUT_MAX_SECONDS )); then
    adaptive_timeout="$TIMEOUT_MAX_SECONDS"
  fi
  log "info" "  Agent $agent_id prompt size: ${prompt_size_bytes}B, timeout: base=${timeout_val}s adaptive=${adaptive_timeout}s"

  AGENT_LAST_RUN["$agent_id"]=$(date +%s)

  local start_time
  start_time=$(date +%s)
  RUNNING_AGENTS=$((RUNNING_AGENTS + 1))

  (
    set +e

    # Run codex in non-interactive mode and capture only the final message.
    local codex_compat_args=()
    if [[ -n "$CODEX_FEATURES_NOTIFY_OVERRIDE" ]]; then
      codex_compat_args=(-c "features.notify=$CODEX_FEATURES_NOTIFY_OVERRIDE")
    fi
    if [[ -n "$CODEX_REASONING_EFFORT" ]]; then
      codex_compat_args+=(-c "model_reasoning_effort=$CODEX_REASONING_EFFORT")
    fi
    run_with_timeout "$adaptive_timeout" "$CODEX_BIN" exec "${codex_compat_args[@]}" --model "$CODEX_MODEL" --full-auto -C "$REPO_ROOT" --output-last-message "$output_file" - < "$prompt_file" 2>"$error_file"
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
  log "info" "  Agent $agent_id running as PID $child_pid (timeout: ${adaptive_timeout}s)"
}

# ---- Reap Finished Background Agents ----

reap_finished_agents() {
  for agent_id in "${!AGENT_PIDS[@]}"; do
    local pid=${AGENT_PIDS[$agent_id]}
    if ! process_is_alive "$pid"; then
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

  log "info" "Running Paperclip cycle (with_heartbeats=$PAPERCLIP_CYCLE_WITH_HEARTBEATS, signal_lane=$PAPERCLIP_SIGNAL_LANE_ENABLED, signal_lane_dispatch=$PAPERCLIP_SIGNAL_LANE_DISPATCH_ENABLED)"
  PAPERCLIP_CYCLE_SIGNAL_LANE_ENABLED="$PAPERCLIP_SIGNAL_LANE_ENABLED" \
  PAPERCLIP_CYCLE_SIGNAL_LANE_DISPATCH_ENABLED="$PAPERCLIP_SIGNAL_LANE_DISPATCH_ENABLED" \
  PAPERCLIP_CYCLE_SIGNAL_LANE_COOLDOWN_MINUTES="$PAPERCLIP_SIGNAL_LANE_COOLDOWN_MINUTES" \
  PAPERCLIP_CYCLE_SIGNAL_LANE_READY_THRESHOLD="$PAPERCLIP_SIGNAL_LANE_READY_THRESHOLD" \
  PAPERCLIP_CYCLE_SIGNAL_LANE_EXPERIMENT_THRESHOLD="$PAPERCLIP_SIGNAL_LANE_EXPERIMENT_THRESHOLD" \
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
  assert_runtime_root

  local running_pids
  running_pids="$(collect_loop_runner_pids)"
  if [[ -n "$running_pids" ]]; then
    local primary_pid
    primary_pid="$(echo "$running_pids" | head -n 1)"
    printf '%s\n' "$primary_pid" > "$PID_FILE"
    echo "Loop runner already running (PID(s): $(echo "$running_pids" | tr '\n' ' ' | xargs))"
    exit 1
  fi

  # Clean stale PID file before launch.
  rm -f "$PID_FILE" 2>/dev/null || true

  mkdir -p "$LOG_DIR" "$(dirname "$PID_FILE")"

  echo "Starting loop runner daemon..."
  nohup bash "$0" _run >/dev/null 2>&1 &
  echo $! > "$PID_FILE"
  echo "Loop runner started (PID $!). Logs: $LOG_FILE"
}

stop_daemon() {
  local running_pids
  running_pids="$(collect_loop_runner_pids)"
  if [[ -z "$running_pids" ]]; then
    rm -f "$PID_FILE" 2>/dev/null || true
    echo "Loop runner not running."
    exit 0
  fi

  echo "Stopping loop runner (PID(s): $(echo "$running_pids" | tr '\n' ' ' | xargs))..."
  local pid
  while IFS= read -r pid; do
    if process_is_alive "$pid"; then
      kill "$pid" 2>/dev/null || true
    fi
  done <<< "$running_pids"

  local wait_deadline=$(( $(date +%s) + 10 ))
  local remaining_pids
  while true; do
    remaining_pids=""
    while IFS= read -r pid; do
      if process_is_alive "$pid"; then
        remaining_pids="${remaining_pids}${pid}"$'\n'
      fi
    done <<< "$running_pids"

    if [[ -z "$remaining_pids" ]] || (( $(date +%s) >= wait_deadline )); then
      break
    fi
    sleep 1
  done

  rm -f "$PID_FILE" 2>/dev/null || true

  # Re-check live process table so we also catch immediate supervisor respawns.
  local post_stop_pids
  post_stop_pids="$(collect_loop_runner_pids)"
  if [[ -n "$post_stop_pids" ]]; then
    echo "Stopped with warning: runner process(es) still alive: $(echo "$post_stop_pids" | tr '\n' ' ' | xargs)"
    echo "This can happen when an external supervisor auto-restarts loop-runner."
  else
    echo "Stopped."
  fi
}

show_status() {
  if ! check_runtime_root; then
    return 1
  fi

  local running_pids
  running_pids="$(collect_loop_runner_pids)"

  if [[ -n "$running_pids" ]]; then
    local primary_pid
    primary_pid="$(echo "$running_pids" | head -n 1)"
    printf '%s\n' "$primary_pid" > "$PID_FILE"
    echo "Loop runner: RUNNING (PID(s): $(echo "$running_pids" | tr '\n' ' ' | xargs))"
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
    assert_runtime_root
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
    assert_runtime_root
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
    assert_runtime_root
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
