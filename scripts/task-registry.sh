#!/usr/bin/env bash
# Thoughtseed Labs Task Registry -- Global CRUD for .thoughtseed/task-registry.json
#
# Usage:
#   ./scripts/task-registry.sh init
#   ./scripts/task-registry.sh add "title" --tag TAG --priority PRIORITY --agent AGENT
#   ./scripts/task-registry.sh update TASK_ID --status STATUS
#   ./scripts/task-registry.sh list [--status STATUS] [--agent AGENT]
#   ./scripts/task-registry.sh get TASK_ID
#   ./scripts/task-registry.sh find-active-by-sync-key SYNC_KEY
#   ./scripts/task-registry.sh reconcile-inbox
#   ./scripts/task-registry.sh stats

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REGISTRY_DIR="$REPO_ROOT/.thoughtseed"
REGISTRY_FILE="$REGISTRY_DIR/task-registry.json"

# ---- Dependency Check ----

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed. Install with: brew install jq" >&2
  exit 1
fi

# ---- Helpers ----

iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

random4() {
  LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c 4
}

generate_task_id() {
  local ts
  ts="$(date +%s)"
  local rand
  rand="$(random4)"
  echo "task-${ts}-${rand}"
}

VALID_STATUSES="pending in_progress completed blocked failed archived"
VALID_PRIORITIES="critical high medium low"

validate_status() {
  local status="$1"
  if ! echo "$VALID_STATUSES" | grep -qw "$status"; then
    echo "ERROR: Invalid status '$status'. Must be one of: $VALID_STATUSES" >&2
    exit 1
  fi
}

validate_priority() {
  local priority="$1"
  if ! echo "$VALID_PRIORITIES" | grep -qw "$priority"; then
    echo "ERROR: Invalid priority '$priority'. Must be one of: $VALID_PRIORITIES" >&2
    exit 1
  fi
}

# ---- Ensure Registry Exists ----

ensure_registry() {
  mkdir -p "$REGISTRY_DIR"
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    init_registry
  fi
}

# ---- Update Metadata Counts ----

update_metadata() {
  local tmp_file="${REGISTRY_FILE}.tmp"
  local now
  now="$(iso_now)"

  jq --arg now "$now" '
    .metadata.total = (.tasks | length) |
    .metadata.pending = ([.tasks[] | select(.status == "pending")] | length) |
    .metadata.in_progress = ([.tasks[] | select(.status == "in_progress")] | length) |
    .metadata.completed = ([.tasks[] | select(.status == "completed")] | length) |
    .metadata.blocked = ([.tasks[] | select(.status == "blocked")] | length) |
    .metadata.failed = ([.tasks[] | select(.status == "failed")] | length) |
    .metadata.archived = ([.tasks[] | select(.status == "archived")] | length) |
    .metadata.last_updated = $now
  ' "$REGISTRY_FILE" > "$tmp_file"

  mv "$tmp_file" "$REGISTRY_FILE"
}

# ---- Atomic Write Helper ----

atomic_write() {
  local content="$1"
  local target="$2"
  local tmp_file="${target}.tmp"
  echo "$content" > "$tmp_file"
  mv "$tmp_file" "$target"
}

# ---- Subcommands ----

init_registry() {
  mkdir -p "$REGISTRY_DIR"
  local now
  now="$(iso_now)"
  local content
  content=$(jq -n --arg now "$now" '{
    tasks: [],
    metadata: {
      total: 0,
      pending: 0,
      in_progress: 0,
      completed: 0,
      blocked: 0,
      failed: 0,
      archived: 0,
      last_updated: $now
    }
  }')
  atomic_write "$content" "$REGISTRY_FILE"
  echo "Task registry initialized at $REGISTRY_FILE" >&2
}

cmd_init() {
  init_registry
}

cmd_add() {
  ensure_registry

  local title=""
  local tag=""
  local priority="medium"
  local agent=""
  local department=""
  local source="manual"
  local depends_on=""
  local details=""
  local source_sync_key=""
  local source_ref=""
  local signal_severity=""
  local score_rationale=""

  if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
    title="$1"
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag) tag="$2"; shift 2 ;;
      --priority) priority="$2"; shift 2 ;;
      --agent) agent="$2"; shift 2 ;;
      --department) department="$2"; shift 2 ;;
      --source) source="$2"; shift 2 ;;
      --depends-on) depends_on="$2"; shift 2 ;;
      --details) details="$2"; shift 2 ;;
      --sync-key) source_sync_key="$2"; shift 2 ;;
      --source-ref) source_ref="$2"; shift 2 ;;
      --signal-severity) signal_severity="$2"; shift 2 ;;
      --score-rationale) score_rationale="$2"; shift 2 ;;
      *) echo "ERROR: Unknown argument '$1'" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$title" ]]; then
    echo "ERROR: Title is required. Usage: task-registry.sh add \"title\" --tag TAG --priority PRIORITY" >&2
    exit 1
  fi

  validate_priority "$priority"

  local task_id
  task_id="$(generate_task_id)"
  local now
  now="$(iso_now)"

  local tags_json="[]"
  if [[ -n "$tag" ]]; then
    tags_json=$(echo "$tag" | tr ',' '\n' | jq -R . | jq -s .)
  fi

  local tmp_file="${REGISTRY_FILE}.tmp"

  jq --arg id "$task_id" \
     --arg title "$title" \
     --arg agent "$agent" \
     --arg department "$department" \
     --arg priority "$priority" \
     --argjson tags "$tags_json" \
     --arg now "$now" \
     --arg source "$source" \
     --arg depends_on "$depends_on" \
     --arg details "$details" \
     --arg source_sync_key "$source_sync_key" \
     --arg source_ref "$source_ref" \
     --arg signal_severity "$signal_severity" \
     --arg score_rationale "$score_rationale" \
  '.tasks += [{
    id: $id,
    title: $title,
    assigned_agent: $agent,
    department: $department,
    status: "pending",
    priority: $priority,
    tags: $tags,
    created_at: $now,
    updated_at: $now,
    created_by: "dispatch",
    source: $source,
    depends_on: (if $depends_on == "" then null else $depends_on end),
    details: (if $details == "" then null else $details end),
    source_sync_key: (if $source_sync_key == "" then null else $source_sync_key end),
    source_ref: (if $source_ref == "" then null else $source_ref end),
    signal_severity: (if $signal_severity == "" then null else $signal_severity end),
    score_rationale: (if $score_rationale == "" then null else $score_rationale end)
  }]' "$REGISTRY_FILE" > "$tmp_file"

  mv "$tmp_file" "$REGISTRY_FILE"
  update_metadata

  echo "$task_id"
  echo "Task added: $task_id -- $title" >&2
}

cmd_update() {
  ensure_registry

  local task_id=""
  local new_status=""

  if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
    task_id="$1"
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) new_status="$2"; shift 2 ;;
      *) echo "ERROR: Unknown argument '$1'" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$task_id" ]]; then
    echo "ERROR: Task ID is required." >&2
    exit 1
  fi

  if [[ -z "$new_status" ]]; then
    echo "ERROR: --status is required." >&2
    exit 1
  fi

  validate_status "$new_status"

  local exists
  exists=$(jq --arg id "$task_id" '[.tasks[] | select(.id == $id)] | length' "$REGISTRY_FILE")
  if [[ "$exists" -eq 0 ]]; then
    echo "ERROR: Task '$task_id' not found." >&2
    exit 1
  fi

  local now
  now="$(iso_now)"
  local tmp_file="${REGISTRY_FILE}.tmp"

  jq --arg id "$task_id" \
     --arg status "$new_status" \
     --arg now "$now" \
  '(.tasks[] | select(.id == $id)) |= (.status = $status | .updated_at = $now)' \
  "$REGISTRY_FILE" > "$tmp_file"

  mv "$tmp_file" "$REGISTRY_FILE"
  update_metadata

  echo "Task $task_id updated to status: $new_status" >&2
}

cmd_list() {
  ensure_registry

  local filter_status=""
  local filter_agent=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) filter_status="$2"; shift 2 ;;
      --agent) filter_agent="$2"; shift 2 ;;
      *) echo "ERROR: Unknown argument '$1'" >&2; exit 1 ;;
    esac
  done

  local jq_filter='.tasks[]'
  if [[ -n "$filter_status" ]]; then
    validate_status "$filter_status"
    jq_filter="$jq_filter | select(.status == \"$filter_status\")"
  fi
  if [[ -n "$filter_agent" ]]; then
    jq_filter="$jq_filter | select(.assigned_agent == \"$filter_agent\")"
  fi

  printf "%-28s %-35s %-12s %-10s %-10s %s\n" "ID" "TITLE" "AGENT" "STATUS" "PRIORITY" "TAGS"
  printf "%-28s %-35s %-12s %-10s %-10s %s\n" "---" "---" "---" "---" "---" "---"

  jq -r "[$jq_filter] | .[] | [.id, .title, .assigned_agent, .status, .priority, (.tags | join(\",\"))] | @tsv" \
    "$REGISTRY_FILE" 2>/dev/null | while IFS=$'\t' read -r id title agent status priority tags; do
    if [[ ${#title} -gt 33 ]]; then
      title="${title:0:30}..."
    fi
    printf "%-28s %-35s %-12s %-10s %-10s %s\n" "$id" "$title" "$agent" "$status" "$priority" "$tags"
  done
}

cmd_get() {
  ensure_registry

  local task_id="${1:-}"
  if [[ -z "$task_id" ]]; then
    echo "ERROR: Task ID is required." >&2
    exit 1
  fi

  local result
  result=$(jq --arg id "$task_id" '.tasks[] | select(.id == $id)' "$REGISTRY_FILE")

  if [[ -z "$result" ]]; then
    echo "ERROR: Task '$task_id' not found." >&2
    exit 1
  fi

  echo "$result" | jq .
}

cmd_find_active_by_sync_key() {
  ensure_registry

  local sync_key="${1:-}"
  if [[ -z "$sync_key" ]]; then
    echo "ERROR: Sync key is required." >&2
    exit 1
  fi

  jq --arg sync_key "$sync_key" '
    [
      .tasks[]
      | select((.source_sync_key // "") == $sync_key)
      | select(.status == "pending" or .status == "in_progress" or .status == "blocked")
    ]
  ' "$REGISTRY_FILE"
}

cmd_stats() {
  ensure_registry

  local total pending in_progress completed blocked failed archived last_updated
  total=$(jq '.metadata.total' "$REGISTRY_FILE")
  pending=$(jq '.metadata.pending' "$REGISTRY_FILE")
  in_progress=$(jq '.metadata.in_progress' "$REGISTRY_FILE")
  completed=$(jq '.metadata.completed' "$REGISTRY_FILE")
  blocked=$(jq '.metadata.blocked // 0' "$REGISTRY_FILE")
  failed=$(jq '.metadata.failed // 0' "$REGISTRY_FILE")
  archived=$(jq '.metadata.archived // 0' "$REGISTRY_FILE")
  last_updated=$(jq -r '.metadata.last_updated' "$REGISTRY_FILE")

  echo "Task Registry Stats"
  echo "==================="
  echo "Total: $total | Pending: $pending | In Progress: $in_progress | Completed: $completed | Blocked: $blocked | Failed: $failed | Archived: $archived"
  echo "Last updated: $last_updated"
}

collect_processed_inbox_ids_json() {
  local pattern="$REPO_ROOT"/agents/*/INBOX.md
  if ! ls $pattern >/dev/null 2>&1; then
    echo "[]"
    return
  fi

  local ids
  ids="$(awk '
    /^## Pending/ {section="pending"; next}
    /^## Processed/ {section="processed"; next}
    section == "processed" {
      if ($0 ~ /Task-ID:[[:space:]]*task-[A-Za-z0-9-]+/) {
        line = $0
        sub(/^.*Task-ID:[[:space:]]*/, "", line)
        sub(/[[:space:]].*$/, "", line)
        if (line ~ /^task-[A-Za-z0-9-]+$/) {
          print line
        }
      }
    }
  ' $pattern 2>/dev/null | sort -u)"

  if [[ -z "$ids" ]]; then
    echo "[]"
  else
    printf '%s\n' "$ids" | jq -R . | jq -s .
  fi
}

collect_processed_inbox_sync_keys_json() {
  local pattern="$REPO_ROOT"/agents/*/INBOX.md
  if ! ls $pattern >/dev/null 2>&1; then
    echo "[]"
    return
  fi

  local keys
  keys="$(awk '
    /^## Pending/ {section="pending"; next}
    /^## Processed/ {section="processed"; next}
    section == "processed" {
      if ($0 ~ /Sync-Key:[[:space:]]*/) {
        line = $0
        sub(/^.*Sync-Key:[[:space:]]*/, "", line)
        sub(/[[:space:]].*$/, "", line)
        if (line != "") {
          print line
        }
      }
    }
  ' $pattern 2>/dev/null | sort -u)"

  if [[ -z "$keys" ]]; then
    echo "[]"
  else
    printf '%s\n' "$keys" | jq -R . | jq -s .
  fi
}

cmd_reconcile_inbox() {
  ensure_registry

  local processed_ids_json
  local processed_sync_keys_json
  processed_ids_json="$(collect_processed_inbox_ids_json)"
  processed_sync_keys_json="$(collect_processed_inbox_sync_keys_json)"

  local matched_inbox matched_sync_key matched_duplicate matched_total
  matched_inbox=$(jq --argjson ids "$processed_ids_json" '
    [
      .tasks[]
      | select(.status == "pending" or .status == "in_progress" or .status == "blocked")
      | select((.id as $id | $ids | index($id)) != null)
    ]
    | length
  ' "$REGISTRY_FILE")

  matched_sync_key=$(jq --argjson keys "$processed_sync_keys_json" '
    [
      .tasks[]
      | select(.status == "pending" or .status == "in_progress" or .status == "blocked")
      | select((.source // "") == "review-intent")
      | select((.source_sync_key // "") != "")
      | select((.source_sync_key as $k | $keys | index($k)) != null)
    ]
    | length
  ' "$REGISTRY_FILE")

  matched_duplicate=$(jq '
    . as $root
    | [
        $root.tasks[]
        | select(.status == "pending" or .status == "in_progress" or .status == "blocked")
        | select((.source // "") == "review-intent")
        | select((.source_sync_key // "") != "")
        | .id as $id
        | .source_sync_key as $k
        | select(
            $root.tasks
            | any(
                (.id != $id)
                and ((.source_sync_key // "") == $k)
                and (.status == "completed" or .status == "archived")
              )
          )
      ]
    | length
  ' "$REGISTRY_FILE")

  matched_total=$(jq --argjson ids "$processed_ids_json" --argjson keys "$processed_sync_keys_json" '
    . as $root
    | [
        .tasks[]
        | select(.status == "pending" or .status == "in_progress" or .status == "blocked")
        | select(
            ((.id as $id | ($ids | index($id)) != null))
            or (
              ((.source // "") == "review-intent")
              and ((.source_sync_key // "") != "")
              and (
                .id as $id
                | .source_sync_key as $k
                | (
                    (($keys | index($k)) != null)
                    or (
                      $root.tasks
                      | any(
                          (.id != $id)
                          and ((.source_sync_key // "") == $k)
                          and (.status == "completed" or .status == "archived")
                        )
                    )
                  )
              )
            )
          )
      ]
    | length
  ' "$REGISTRY_FILE")

  if [[ "$matched_total" -eq 0 ]]; then
    echo "No active registry tasks matched processed inbox items, processed sync keys, or duplicate review-intent sync keys." >&2
    return 0
  fi

  local now
  now="$(iso_now)"
  local tmp_file="${REGISTRY_FILE}.tmp"

  jq --argjson ids "$processed_ids_json" --argjson keys "$processed_sync_keys_json" --arg now "$now" '
    . as $root
    | .tasks |= map(
        if (
          (.status == "pending" or .status == "in_progress" or .status == "blocked")
          and ((.id as $id | $ids | index($id)) != null)
        ) then
          .status = "completed"
          | .updated_at = $now
        elif (
          (.status == "pending" or .status == "in_progress" or .status == "blocked")
          and ((.source // "") == "review-intent")
          and ((.source_sync_key // "") != "")
          and (
            .id as $id
            | .source_sync_key as $k
            | (
                (($keys | index($k)) != null)
                or (
                  $root.tasks
                  | any(
                      (.id != $id)
                      and ((.source_sync_key // "") == $k)
                      and (.status == "completed" or .status == "archived")
                    )
                )
              )
          )
        ) then
          .status = "completed"
          | .updated_at = $now
        else
          .
        end
      )
  ' "$REGISTRY_FILE" > "$tmp_file"

  mv "$tmp_file" "$REGISTRY_FILE"
  update_metadata

  local total
  total="$matched_total"
  echo "Reconciled $total active registry tasks (inbox=$matched_inbox sync_key_inbox=$matched_sync_key duplicate_review_intent=$matched_duplicate; overlaps possible)." >&2
}

# ---- Entry Point ----

case "${1:-help}" in
  init) cmd_init ;;
  add) shift; cmd_add "$@" ;;
  update) shift; cmd_update "$@" ;;
  list) shift; cmd_list "$@" ;;
  get) shift; cmd_get "$@" ;;
  find-active-by-sync-key) shift; cmd_find_active_by_sync_key "$@" ;;
  reconcile-inbox) cmd_reconcile_inbox ;;
  stats) cmd_stats ;;
  help|*)
    echo "Thoughtseed Labs Task Registry"
    echo ""
    echo "Usage: $0 {init|add|update|list|get|find-active-by-sync-key|reconcile-inbox|stats}"
    echo ""
    echo "  init                                      Create empty registry"
    echo "  add \"title\" --tag TAG --priority PRI      Add a task"
    echo "  update TASK_ID --status STATUS             Update task status"
    echo "  list [--status STATUS] [--agent AGENT]     List tasks"
    echo "  get TASK_ID                                Show task details"
    echo "  find-active-by-sync-key KEY                List active tasks for one sync key"
    echo "  reconcile-inbox                            Mark active tasks completed when inbox shows processed"
    echo "  stats                                      Show metadata counts"
    echo ""
    echo "Valid statuses: $VALID_STATUSES"
    echo "Valid priorities: $VALID_PRIORITIES"
    ;;
esac
