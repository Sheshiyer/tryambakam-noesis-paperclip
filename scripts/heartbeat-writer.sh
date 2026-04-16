#!/usr/bin/env bash
# Thoughtseed Labs Heartbeat Writer
# Appends structured entries to agent HEARTBEAT.md files and logs/cycles.jsonl.
#
# Usage:
#   ./scripts/heartbeat-writer.sh <agent_id> <step_id> <outcome> <duration_seconds> [tokens_used]
#
# Arguments:
#   agent_id         - Agent identifier (e.g., jarvis, atlas, clawd)
#   step_id          - Step identifier (e.g., step-3, cycle-1700000000, idle)
#   outcome          - One of: completed, blocked, failed, timeout, idle
#   duration_seconds - How long the cycle took in seconds
#   tokens_used      - (Optional) Token count for the cycle
#
# Outputs:
#   - Appends markdown entry to agents/{agent_id}/HEARTBEAT.md
#   - Appends JSON line to logs/cycles.jsonl
#   - Optionally POSTs to Paperclip heartbeat API

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# ---- Logging (to stderr) ----

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [heartbeat-writer] [$level] $*" >&2
}

# ---- Validate args ----

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <agent_id> <step_id> <outcome> <duration_seconds> [tokens_used]" >&2
  exit 1
fi

AGENT_ID="$1"
STEP_ID="$2"
OUTCOME="$3"
DURATION="$4"
TOKENS="${5:-0}"

# Validate outcome
case "$OUTCOME" in
  completed|blocked|failed|timeout|idle)
    ;;
  *)
    log "warn" "Unknown outcome '$OUTCOME', defaulting to 'failed'"
    OUTCOME="failed"
    ;;
esac

AGENT_DIR="$REPO_ROOT/agents/$AGENT_ID"
HEARTBEAT_FILE="$AGENT_DIR/HEARTBEAT.md"
LOG_DIR="$REPO_ROOT/logs"
CYCLE_LOG="$LOG_DIR/cycles.jsonl"

# ---- Ensure directories exist ----

mkdir -p "$LOG_DIR"

# ---- Timestamp ----

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ---- Append to HEARTBEAT.md ----

if [[ -f "$HEARTBEAT_FILE" ]]; then
  {
    echo ""
    echo "| $NOW | $STEP_ID | $OUTCOME | ${DURATION}s | tokens=$TOKENS |"
  } >> "$HEARTBEAT_FILE"
  log "info" "Appended heartbeat entry for $AGENT_ID: $STEP_ID=$OUTCOME (${DURATION}s, ${TOKENS} tokens)"
else
  log "warn" "HEARTBEAT.md not found for $AGENT_ID at $HEARTBEAT_FILE -- creating"
  {
    echo "# ${AGENT_ID} -- Heartbeat"
    echo ""
    echo "| Timestamp | Step | Outcome | Duration | Notes |"
    echo "|-----------|------|---------|----------|-------|"
    echo "| $NOW | $STEP_ID | $OUTCOME | ${DURATION}s | tokens=$TOKENS |"
  } > "$HEARTBEAT_FILE"
fi

# ---- Append JSON line to cycles.jsonl ----

python3 -c "
import json
entry = {
    'timestamp': '$NOW',
    'agent_id': '$AGENT_ID',
    'step_id': '$STEP_ID',
    'outcome': '$OUTCOME',
    'duration': int('$DURATION'),
    'tokens': int('$TOKENS')
}
print(json.dumps(entry))
" >> "$CYCLE_LOG"

log "info" "Appended cycle log entry to $CYCLE_LOG"

# ---- Optional: POST to Paperclip heartbeat API ----

if [[ "${PAPERCLIP_HEARTBEAT:-false}" == "true" ]]; then
  PAPERCLIP_API="${PAPERCLIP_API_URL:-http://127.0.0.1:3100/api}"
  PAPERCLIP_COMPANY="${PAPERCLIP_COMPANY_ID:-d89420ba-ce5a-45f6-bd0a-e735d2e02740}"

  curl -s -X POST "${PAPERCLIP_API}/companies/${PAPERCLIP_COMPANY}/heartbeat" \
    -H "Content-Type: application/json" \
    -d "{
      \"agent_id\": \"$AGENT_ID\",
      \"step_id\": \"$STEP_ID\",
      \"outcome\": \"$OUTCOME\",
      \"duration\": $DURATION,
      \"timestamp\": \"$NOW\"
    }" >/dev/null 2>&1 || {
    log "warn" "Failed to POST heartbeat to Paperclip API"
  }
fi
