#!/usr/bin/env bash
# Thoughtseed Labs -- Paperclip Local Reconciliation
# Reconciles local task-registry statuses for source=paperclip tasks
# against current Paperclip issue statuses.
#
# Usage:
#   ./scripts/paperclip-reconcile-local.sh
#   ./scripts/paperclip-reconcile-local.sh --dry-run

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PAPERCLIP_API="${PAPERCLIP_API_URL:-http://127.0.0.1:3100/api}"
PAPERCLIP_COMPANY="${PAPERCLIP_COMPANY_ID:-d89420ba-ce5a-45f6-bd0a-e735d2e02740}"
TASK_REGISTRY="$REPO_ROOT/scripts/task-registry.sh"
REGISTRY_FILE="$REPO_ROOT/.thoughtseed/task-registry.json"

normalize_api_base() {
  local base="${1%/}"
  if [[ "$base" == */api ]]; then
    echo "$base"
  else
    echo "$base/api"
  fi
}

PAPERCLIP_API="$(normalize_api_base "$PAPERCLIP_API")"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [paperclip-reconcile] [$level] $*" >&2
}

pending_paperclip_count() {
  local file="$1"
  awk '
    BEGIN { in_pending = 0; count = 0 }
    /^## Pending/ { in_pending = 1; next }
    /^## Processed/ { in_pending = 0; next }
    in_pending && /\[Paperclip:[0-9A-Za-z-]+\]/ { count++ }
    END { print count }
  ' "$file"
}

prune_pending_terminal_issues() {
  local input_file="$1"
  local output_file="$2"
  local terminal_ids_csv="$3"

  awk -v terminal_ids_csv="$terminal_ids_csv" '
    BEGIN {
      split(terminal_ids_csv, terminal_ids, ",")
      for (idx in terminal_ids) {
        if (terminal_ids[idx] != "") {
          terminal[terminal_ids[idx]] = 1
        }
      }
      in_pending = 0
      in_entry = 0
      drop_entry = 0
      entry = ""
    }

    function flush_entry() {
      if (in_entry) {
        if (!drop_entry) {
          printf "%s", entry
        }
        entry = ""
        in_entry = 0
        drop_entry = 0
      }
    }

    {
      line = $0

      if (line ~ /^## Pending/) {
        flush_entry()
        in_pending = 1
        print line
        next
      }

      if (line ~ /^## Processed/) {
        flush_entry()
        in_pending = 0
        print line
        next
      }

      if (in_pending) {
        if (line ~ /^### \[/) {
          flush_entry()
          in_entry = 1
          entry = line ORS
          drop_entry = 0
          next
        }

        if (in_entry) {
          entry = entry line ORS
          if (line ~ /\[Paperclip:[0-9A-Za-z-]+\]/) {
            issue_id = line
            sub(/^.*\[Paperclip:/, "", issue_id)
            sub(/\].*$/, "", issue_id)
            if (issue_id in terminal) {
              drop_entry = 1
            }
          }
          next
        }
      }

      print line
    }

    END {
      flush_entry()
    }
  ' "$input_file" > "$output_file"
}

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed." >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "ERROR: curl is required but not installed." >&2
  exit 1
fi

if [[ ! -x "$TASK_REGISTRY" ]]; then
  echo "ERROR: task-registry script missing or not executable at $TASK_REGISTRY" >&2
  exit 1
fi

if [[ ! -f "$REGISTRY_FILE" ]]; then
  log "info" "No local task registry found at $REGISTRY_FILE; nothing to reconcile"
  exit 0
fi

log "info" "Fetching issues from ${PAPERCLIP_API}/companies/${PAPERCLIP_COMPANY}/issues"

issues_response=$(curl -s -f "${PAPERCLIP_API}/companies/${PAPERCLIP_COMPANY}/issues" 2>/dev/null) || {
  log "error" "Failed to fetch issues from Paperclip API"
  exit 1
}

if [[ -z "$issues_response" ]] || [[ "$issues_response" == "null" ]]; then
  log "info" "No issues returned from Paperclip"
  exit 0
fi

issue_status_map=$(echo "$issues_response" | jq 'reduce .[]? as $issue ({}; .[$issue.id] = ($issue.status // ""))')
terminal_issue_ids_csv=$(echo "$issues_response" | jq -r '[.[]? | select((.status // "") == "done" or (.status // "") == "cancelled" or (.status // "") == "resolved" or (.status // "") == "closed" or (.status // "") == "blocked") | .id] | join(",")')

reconcile_rows=$(jq -r --argjson statusMap "$issue_status_map" '
  .tasks[]?
  | select(.source == "paperclip")
  | . as $task
  | (if (.title | test("\\[Paperclip:[^\\]]+\\]"))
      then (.title | capture("\\[Paperclip:(?<issue>[^\\]]+)\\]").issue)
      else ""
    end) as $issueId
  | select($issueId != "")
  | ($statusMap[$issueId] // "") as $remoteStatus
  | (if ($remoteStatus == "blocked") then "blocked"
     elif ($remoteStatus == "done" or $remoteStatus == "cancelled" or $remoteStatus == "resolved" or $remoteStatus == "closed") then "completed"
     else ""
     end) as $targetStatus
  | select($targetStatus != "")
  | select(.status != $targetStatus)
  | [.id, $targetStatus, $issueId, $remoteStatus, .status] | @tsv
' "$REGISTRY_FILE")

updated_total=0
updated_completed=0
updated_blocked=0
inbox_files_updated=0
inbox_pending_refs_removed=0

if [[ -z "$reconcile_rows" ]]; then
  log "info" "No local Paperclip task status updates required"
else
  while IFS=$'\t' read -r task_id target_status issue_id remote_status current_status; do
    if [[ "$DRY_RUN" == "true" ]]; then
      log "info" "DRY-RUN: task=$task_id issue=$issue_id $current_status -> $target_status (remote=$remote_status)"
    else
      "$TASK_REGISTRY" update "$task_id" --status "$target_status" >/dev/null
      log "info" "Updated task=$task_id issue=$issue_id $current_status -> $target_status (remote=$remote_status)"
    fi

    updated_total=$((updated_total + 1))
    if [[ "$target_status" == "completed" ]]; then
      updated_completed=$((updated_completed + 1))
    elif [[ "$target_status" == "blocked" ]]; then
      updated_blocked=$((updated_blocked + 1))
    fi
  done <<< "$reconcile_rows"
fi

if [[ -n "$terminal_issue_ids_csv" ]]; then
  for inbox_file in "$REPO_ROOT"/agents/*/INBOX.md; do
    [[ -f "$inbox_file" ]] || continue

    before_refs=$(pending_paperclip_count "$inbox_file")

    temp_file="$(mktemp)"
    prune_pending_terminal_issues "$inbox_file" "$temp_file" "$terminal_issue_ids_csv"
    after_refs=$(pending_paperclip_count "$temp_file")

    removed_refs=$((before_refs - after_refs))
    if [[ "$removed_refs" -gt 0 ]]; then
      inbox_files_updated=$((inbox_files_updated + 1))
      inbox_pending_refs_removed=$((inbox_pending_refs_removed + removed_refs))

      if [[ "$DRY_RUN" == "true" ]]; then
        log "info" "DRY-RUN: would prune $removed_refs terminal Paperclip pending entr$( [[ "$removed_refs" -eq 1 ]] && echo "y" || echo "ies" ) from $inbox_file"
        rm -f "$temp_file"
      else
        mv "$temp_file" "$inbox_file"
        log "info" "Pruned $removed_refs terminal Paperclip pending entr$( [[ "$removed_refs" -eq 1 ]] && echo "y" || echo "ies" ) from $inbox_file"
      fi
    else
      rm -f "$temp_file"
    fi
  done
fi

echo "Reconciliation: updated=$updated_total completed=$updated_completed blocked=$updated_blocked inbox_files_updated=$inbox_files_updated inbox_pending_refs_removed=$inbox_pending_refs_removed dry_run=$DRY_RUN"
