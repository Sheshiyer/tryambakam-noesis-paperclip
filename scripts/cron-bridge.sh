#!/usr/bin/env bash
set -euo pipefail

# Thoughtseed Labs — Cron Bridge
# Reads cron/jobs.json (ported from samsclawra) and executes jobs
# that are due based on their schedule (cron expression or interval).
#
# Usage:
#   ./scripts/cron-bridge.sh status          — Show all jobs and their state
#   ./scripts/cron-bridge.sh run-due         — Execute jobs that are due now
#   ./scripts/cron-bridge.sh run-job <name>  — Execute a specific job by name
#   ./scripts/cron-bridge.sh list            — List job names and schedules

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
JOBS_FILE="$REPO_ROOT/cron/jobs.json"
LOG_DIR="$REPO_ROOT/logs"
CRON_LOG="$LOG_DIR/cron-bridge.log"
PAPERCLIP_API="${PAPERCLIP_API:-http://127.0.0.1:3100/api}"
PAPERCLIP_CID="${PAPERCLIP_CID:-d89420ba-ce5a-45f6-bd0a-e735d2e02740}"

mkdir -p "$LOG_DIR"

log() {
  local msg="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [cron-bridge] $*"
  echo "$msg" >> "$CRON_LOG"
  echo "$msg"
}

# ---- Commands ----

cmd_list() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  Thoughtseed Labs — Cron Jobs (from samsclawra)            ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  printf "%-40s %-8s %-20s %s\n" "NAME" "ENABLED" "SCHEDULE" "DELIVERY"
  printf "%-40s %-8s %-20s %s\n" "----" "-------" "--------" "--------"

  jq -r '.jobs[] | [
    .name,
    (if .enabled then "✅" else "❌" end),
    (if .schedule.kind == "cron" then "cron: " + .schedule.expr
     elif .schedule.kind == "every" then "every " + ((.schedule.everyMs / 60000 | floor | tostring) + "m")
     else .schedule.kind end),
    (.delivery.mode + (if .delivery.channel then " → " + .delivery.channel else "" end))
  ] | @tsv' "$JOBS_FILE" | while IFS=$'\t' read -r name enabled schedule delivery; do
    printf "%-40s %-8s %-20s %s\n" "$name" "$enabled" "$schedule" "$delivery"
  done
  echo ""
  echo "Total: $(jq '.jobs | length' "$JOBS_FILE") jobs"
}

cmd_status() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  Cron Job Status                                           ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  printf "%-35s %-8s %-12s %-10s %s\n" "NAME" "STATUS" "LAST_RUN" "ERRORS" "DURATION"
  printf "%-35s %-8s %-12s %-10s %s\n" "----" "------" "--------" "------" "--------"

  jq -r '.jobs[] | [
    .name,
    (.state.lastStatus // "never"),
    (if .state.lastRunAtMs then (.state.lastRunAtMs / 1000 | strftime("%m-%d %H:%M")) else "never" end),
    (.state.consecutiveErrors // 0 | tostring),
    (if .state.lastDurationMs then ((.state.lastDurationMs / 1000 | floor | tostring) + "s") else "-" end)
  ] | @tsv' "$JOBS_FILE" | while IFS=$'\t' read -r name status lastrun errors duration; do
    printf "%-35s %-8s %-12s %-10s %s\n" "$name" "$status" "$lastrun" "$errors" "$duration"
  done
}

cmd_run_job() {
  local job_name="$1"

  # Find the job in jobs.json
  local job
  job=$(jq --arg n "$job_name" '.jobs[] | select(.name == $n)' "$JOBS_FILE")

  if [[ -z "$job" ]]; then
    echo "❌ Job not found: $job_name"
    echo "Available jobs:"
    jq -r '.jobs[].name' "$JOBS_FILE"
    exit 1
  fi

  local agent_id
  agent_id=$(echo "$job" | jq -r '.agentId')
  local payload
  payload=$(echo "$job" | jq -r '.payload // empty')

  log "Executing job: $job_name (agent: $agent_id)"

  # Map samsclawra agent IDs to Paperclip agent IDs
  # All samsclawra cron jobs are assigned to noesis-vishwakarma
  local paperclip_agent_id
  paperclip_agent_id=$(/usr/bin/curl -s "$PAPERCLIP_API/companies/$PAPERCLIP_CID/agents" 2>/dev/null | \
    python3 -c "import json,sys; agents=json.load(sys.stdin); print(next((a['id'] for a in agents if a['name']=='Noesis Vishwakarma'), 'not-found'))" 2>/dev/null || echo "not-found")

  if [[ "$paperclip_agent_id" == "not-found" ]]; then
    log "⚠️ Could not map agent $agent_id to Paperclip — falling back to dispatch"
    # Dispatch as a task instead
    if [[ -x "$REPO_ROOT/scripts/dispatch-task.sh" ]]; then
      "$REPO_ROOT/scripts/dispatch-task.sh" "Cron: $job_name" --tag ops --priority P2
    fi
  else
    log "Triggering heartbeat for Noesis Vishwakarma ($paperclip_agent_id)"
    paperclipai heartbeat run \
      --agent-id "$paperclip_agent_id" \
      --source automation \
      --trigger callback \
      --timeout-ms 120000 \
      --json 2>&1 | tail -5
  fi

  # Update state in jobs.json
  local now_ms
  now_ms=$(date +%s)000
  jq --arg n "$job_name" --arg ms "$now_ms" '
    .jobs |= map(if .name == $n then
      .state.lastRunAtMs = ($ms | tonumber) |
      .state.lastStatus = "dispatched"
    else . end)
  ' "$JOBS_FILE" > "$JOBS_FILE.tmp" && mv "$JOBS_FILE.tmp" "$JOBS_FILE"

  log "✅ Job $job_name dispatched"
}

cmd_run_due() {
  local now_s
  now_s=$(date +%s)
  local count=0

  log "Checking for due jobs at $(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # For cron jobs, check if current time matches the cron expression
  # For interval jobs, check if enough time has passed since last run
  jq -r '.jobs[] | select(.enabled == true) | [
    .name,
    .schedule.kind,
    (.schedule.expr // ""),
    (.schedule.everyMs // 0 | tostring),
    (.state.lastRunAtMs // 0 | tostring),
    (.schedule.tz // "UTC")
  ] | @tsv' "$JOBS_FILE" | while IFS=$'\t' read -r name kind expr every_ms last_run_ms tz; do
    local should_run=false

    if [[ "$kind" == "every" ]]; then
      # Interval-based: check if enough time has elapsed
      local last_s=$((${last_run_ms%000} + 0))
      local interval_s=$((${every_ms} / 1000))
      local elapsed=$((now_s - last_s))

      if [[ $elapsed -ge $interval_s ]]; then
        should_run=true
      fi
    fi
    # Note: cron expression matching requires a cron parser — for now,
    # cron jobs should be triggered by the system crontab or loop-runner.
    # This bridge handles interval-based jobs and manual triggers.

    if [[ "$should_run" == "true" ]]; then
      log "Job due: $name (interval: ${every_ms}ms, elapsed: ${elapsed}s)"
      cmd_run_job "$name"
      count=$((count + 1))
    fi
  done

  log "Due check complete. $count jobs triggered."
}

# ---- Main ----

if [[ ! -f "$JOBS_FILE" ]]; then
  echo "❌ Jobs file not found: $JOBS_FILE"
  echo "Port jobs from samsclawra: cp /Volumes/.../samsclawra/cron/jobs.json $JOBS_FILE"
  exit 1
fi

case "${1:-help}" in
  list)      cmd_list ;;
  status)    cmd_status ;;
  run-due)   cmd_run_due ;;
  run-job)   cmd_run_job "${2:?Usage: $0 run-job <job-name>}" ;;
  help|*)
    echo "Usage: $0 {list|status|run-due|run-job <name>}"
    echo ""
    echo "  list      — Show all jobs and their schedules"
    echo "  status    — Show execution state of all jobs"
    echo "  run-due   — Execute interval jobs that are overdue"
    echo "  run-job   — Execute a specific job by name"
    ;;
esac
