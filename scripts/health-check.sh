#!/usr/bin/env bash
# Thoughtseed Labs -- Agent Health Check & Status Aggregator
#
# Reads all agents' HEARTBEAT.md files, parses last cycle entry, and outputs
# an ASCII status table. Flags agents that haven't run in > 2x their interval.
#
# Usage:
#   ./scripts/health-check.sh          # Status table for all agents
#   ./scripts/health-check.sh atlas    # Check specific agent
#   ./scripts/health-check.sh --fix    # Auto-create missing files from templates

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
AGENTS_DIR="$REPO_ROOT/agents"

FIX_MODE=false
TARGET_AGENT=""
TOTAL_AGENTS=0
HEALTHY_AGENTS=0

# ---- Parse arguments ----

for arg in "$@"; do
  case "$arg" in
    --fix) FIX_MODE=true ;;
    -*) echo "Unknown flag: $arg" >&2; exit 1 ;;
    *) TARGET_AGENT="$arg" ;;
  esac
done

# ---- Helpers ----

log() {
  echo "$*" >&2
}

iso_now_epoch() {
  date +%s
}

# Parse ISO timestamp to epoch (macOS compatible)
iso_to_epoch() {
  local ts="$1"
  # Try python3 for reliable parsing
  python3 -c "
import datetime, sys
ts = '$ts'.strip()
try:
    dt = datetime.datetime.fromisoformat(ts.replace('Z', '+00:00'))
    print(int(dt.timestamp()))
except:
    print(0)
" 2>/dev/null || echo "0"
}

# Get agent interval from MANIFEST.yaml in seconds
get_agent_interval() {
  local agent_id="$1"
  local manifest="$AGENTS_DIR/$agent_id/MANIFEST.yaml"
  local interval=900  # default 15m

  if [[ -f "$manifest" ]]; then
    local interval_str
    interval_str=$(grep -A5 "^loop:" "$manifest" | grep "interval:" | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs 2>/dev/null || true)
    case "$interval_str" in
      "5m") interval=300 ;;
      "10m") interval=600 ;;
      "15m") interval=900 ;;
    esac
  fi
  echo "$interval"
}

# Count cycles today from HEARTBEAT.md
count_cycles_today() {
  local heartbeat_file="$1"
  local today
  today=$(date -u +"%Y-%m-%d")
  local count
  count=$(grep -c "$today" "$heartbeat_file" 2>/dev/null) || true
  echo "${count:-0}"
}

# Count blocked cycles today
count_blocked_today() {
  local heartbeat_file="$1"
  local today
  today=$(date -u +"%Y-%m-%d")
  local count
  count=$(grep "$today" "$heartbeat_file" 2>/dev/null | grep -ci "blocked\|failed" 2>/dev/null) || true
  echo "${count:-0}"
}

# Get last cycle info from HEARTBEAT.md
get_last_cycle() {
  local heartbeat_file="$1"

  if [[ ! -f "$heartbeat_file" ]]; then
    echo "never|--|--"
    return
  fi

  # Try to find the last line with a timestamp pattern
  local last_entry
  last_entry=$(grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}' "$heartbeat_file" | tail -1 || true)

  if [[ -z "$last_entry" ]]; then
    echo "never|--|--"
    return
  fi

  # Extract timestamp
  local timestamp
  timestamp=$(echo "$last_entry" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z?' | head -1 || true)

  # Extract outcome
  local outcome
  outcome=$(echo "$last_entry" | grep -oiE 'completed|blocked|failed|timeout|idle' | head -1 || echo "--")

  echo "${timestamp:-never}|${outcome:---}"
}

# ---- Fix missing files ----

fix_agent_files() {
  local agent_id="$1"
  local agent_dir="$AGENTS_DIR/$agent_id"
  local agent_upper
  agent_upper="$(echo "$agent_id" | tr '[:lower:]' '[:upper:]')"

  local required_files=(MANIFEST.yaml IDENTITY.md SOUL.md CONTEXT.md TASKS.md INBOX.md HEARTBEAT.md TOOLS.md USER.md MEMORY.md AGENTS.md EVOLVE.md SELF.md)

  for f in "${required_files[@]}"; do
    if [[ ! -f "$agent_dir/$f" ]]; then
      case "$f" in
        MANIFEST.yaml)
          cat > "$agent_dir/$f" <<YAML
agent:
  id: "$agent_id"
  name: "$agent_upper"
  tier: 2
  role: "Agent"
  reports_to: jarvis

loop:
  enabled: true
  interval: "15m"
  max_step_timeout: "14m"
  on_blocked: log_and_skip
  on_failure: log_skip_continue
  retry_blocked_after: 3
YAML
          ;;
        HEARTBEAT.md)
          cat > "$agent_dir/$f" <<MD
# $agent_upper -- Heartbeat

| Timestamp | Step | Outcome | Duration | Notes |
|-----------|------|---------|----------|-------|
| _awaiting first cycle_ | -- | -- | -- | -- |
MD
          ;;
        TASKS.md)
          cat > "$agent_dir/$f" <<MD
# $agent_upper -- Tasks

## Active Tasks

_No tasks yet._

## Completed Tasks
MD
          ;;
        INBOX.md)
          cat > "$agent_dir/$f" <<MD
# $agent_upper -- Inbox

## Pending

## Processed
MD
          ;;
        *)
          echo "# $agent_upper -- $(echo "$f" | sed 's/\.md$//')" > "$agent_dir/$f"
          ;;
      esac
      log "  FIXED: Created $f for $agent_id"
    fi
  done
}

# ---- Check a single agent ----

check_agent() {
  local agent_id="$1"
  local agent_dir="$AGENTS_DIR/$agent_id"
  local heartbeat_file="$agent_dir/HEARTBEAT.md"

  TOTAL_AGENTS=$(( TOTAL_AGENTS + 1 ))

  if [[ "$FIX_MODE" == "true" ]]; then
    fix_agent_files "$agent_id"
  fi

  # Count missing required files
  local missing=0
  for f in MANIFEST.yaml IDENTITY.md SOUL.md TASKS.md INBOX.md HEARTBEAT.md CONTEXT.md; do
    if [[ ! -f "$agent_dir/$f" ]]; then
      missing=$(( missing + 1 ))
    fi
  done

  local last_cycle_info
  last_cycle_info=$(get_last_cycle "$heartbeat_file")
  local last_ts
  last_ts=$(echo "$last_cycle_info" | cut -d'|' -f1)
  local last_outcome
  last_outcome=$(echo "$last_cycle_info" | cut -d'|' -f2)

  local steps_today
  steps_today=$(count_cycles_today "$heartbeat_file")
  local blocked_today
  blocked_today=$(count_blocked_today "$heartbeat_file")

  # Check staleness
  local flag=""
  if [[ "$last_ts" != "never" ]]; then
    local last_epoch
    last_epoch=$(iso_to_epoch "$last_ts")
    local now_epoch
    now_epoch=$(iso_now_epoch)
    local interval
    interval=$(get_agent_interval "$agent_id")
    local elapsed=$(( now_epoch - last_epoch ))
    local threshold=$(( interval * 2 ))

    if (( elapsed > threshold )); then
      flag=" [STALE]"
    else
      HEALTHY_AGENTS=$(( HEALTHY_AGENTS + 1 ))
    fi
  fi

  if [[ $missing -gt 0 ]]; then
    flag="${flag} [${missing} missing files]"
  fi

  # Truncate timestamp for display
  local display_ts="$last_ts"
  if [[ ${#display_ts} -gt 19 ]]; then
    display_ts="${display_ts:0:19}"
  fi

  printf "| %-10s | %-19s | %-10s | %6s | %7s | %s\n" \
    "$agent_id" "$display_ts" "$last_outcome" "$steps_today" "$blocked_today" "$flag"
}

# ---- Main ----

main() {
  echo ""
  echo "+---------------------------------------------------------------------------------+"
  echo "|                    Thoughtseed Labs Agent Health Check                           |"
  echo "+---------------------------------------------------------------------------------+"
  printf "| %-10s | %-19s | %-10s | %6s | %7s | %s\n" "AGENT" "LAST_CYCLE" "OUTCOME" "STEPS" "BLOCKED" "FLAGS"
  printf "| %-10s | %-19s | %-10s | %6s | %7s | %s\n" "----------" "-------------------" "----------" "------" "-------" "-----"

  if [[ -n "$TARGET_AGENT" ]] && [[ "$TARGET_AGENT" != "--fix" ]]; then
    if [[ ! -d "$AGENTS_DIR/$TARGET_AGENT" ]]; then
      echo "ERROR: agent '$TARGET_AGENT' not found" >&2
      exit 1
    fi
    check_agent "$TARGET_AGENT"
  else
    for agent_dir in "$AGENTS_DIR"/*/; do
      if [[ -d "$agent_dir" ]]; then
        local agent_id
        agent_id="$(basename "$agent_dir")"
        check_agent "$agent_id"
      fi
    done
  fi

  echo "+---------------------------------------------------------------------------------+"
  printf "| Result: %d/%d healthy                                                           |\n" "$HEALTHY_AGENTS" "$TOTAL_AGENTS"
  echo "+---------------------------------------------------------------------------------+"
  echo ""

  if [[ "$FIX_MODE" == "true" ]]; then
    echo "(--fix mode: missing files were auto-created)" >&2
  fi

  if [[ "$HEALTHY_AGENTS" -lt "$TOTAL_AGENTS" ]]; then
    exit 1
  fi
  exit 0
}

main
