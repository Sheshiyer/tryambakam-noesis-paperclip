#!/usr/bin/env bash
# Thoughtseed Labs Task Dispatcher -- Creates tasks and routes them to correct agent INBOX
#
# Usage:
#   ./scripts/dispatch-task.sh "Research competitor pricing" --tag research --priority high
#   ./scripts/dispatch-task.sh "Fix authentication bug" --tag code
#   ./scripts/dispatch-task.sh "Create logo variants" --tag design --priority critical
#   ./scripts/dispatch-task.sh "General task" (routes to jarvis by default)
#   ./scripts/dispatch-task.sh "Investigate alert" --source teamforge --sync-key ops:v1:... --details "Signal context..."

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MANIFEST="$REPO_ROOT/manifest.yaml"
TASK_REGISTRY="$REPO_ROOT/scripts/task-registry.sh"
TASK_REGISTRY_FILE="$REPO_ROOT/.thoughtseed/task-registry.json"

# ---- Dependency Check ----

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed. Install with: brew install jq" >&2
  exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: manifest.yaml not found at $MANIFEST" >&2
  exit 1
fi

if [[ ! -x "$TASK_REGISTRY" ]]; then
  echo "ERROR: task-registry.sh not found or not executable at $TASK_REGISTRY" >&2
  exit 1
fi

# ---- Helpers ----

iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

VALID_PRIORITIES="critical high medium low"
VALID_TAGS="research content code design video product ops strategy trend qa copy brand"

validate_priority() {
  local priority="$1"
  if ! echo "$VALID_PRIORITIES" | grep -qw "$priority"; then
    echo "ERROR: Invalid priority '$priority'. Must be one of: $VALID_PRIORITIES" >&2
    exit 1
  fi
}

resolve_department_for_agent() {
  local agent_id="$1"
  local agent_manifest="$REPO_ROOT/agents/$agent_id/MANIFEST.yaml"

  if [[ ! -f "$agent_manifest" ]]; then
    return 0
  fi

  awk -F: '
    /^[[:space:]]*department:/ {
      value = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/"/, "", value)
      print value
      exit
    }
  ' "$agent_manifest"
}

# ---- Resolve Tag to Department and Lead ----

resolve_routing() {
  local tag="$1"

  local department=""

  local IFS=','
  for t in $tag; do
    t="$(echo "$t" | xargs)"
    if [[ -z "$t" ]]; then continue; fi

    local match
    match=$(awk -v target="$t" '
      /by_tag:/ { intag=1; next }
      intag && /^[[:space:]]+[a-z]/ {
        line = $0
        gsub(/^[[:space:]]+/, "", line)
        n = split(line, kv, ":")
        if (n >= 2) {
          key = kv[1]
          val = kv[2]
          gsub(/[[:space:]]/, "", key)
          gsub(/[[:space:]]/, "", val)
          if (key == target) { print val; exit }
        }
      }
      intag && /^[[:space:]]*$/ { intag=0 }
      intag && /^[[:space:]]*[a-z].*:/ && !/^[[:space:]]+[a-z]/ { intag=0 }
    ' "$MANIFEST")

    if [[ -n "$match" ]]; then
      department="$match"
      break
    fi
  done

  if [[ -z "$department" ]]; then
    echo "jarvis|leadership|jarvis"
    return
  fi

  local lead
  lead=$(awk -v dept="$department" '
    /departments:/ { indepts=1; next }
    indepts && /^[[:space:]]{0,4}[a-z]/ && !/^[[:space:]]/ { indepts=0 }
    indepts && $0 ~ "^[[:space:]]+"dept":" { indept=1; next }
    indept && /^[[:space:]]+lead:/ {
      line = $0
      gsub(/.*lead:[[:space:]]*/, "", line)
      gsub(/[[:space:]]*$/, "", line)
      print line
      exit
    }
    indept && /^[[:space:]]+[a-z]+:/ && !/lead:/ && !/name:/ && !/icon:/ && !/members:/ && !/shared_vault:/ && !/description:/ { indept=0 }
  ' "$MANIFEST")

  if [[ -z "$lead" ]]; then
    echo "jarvis|leadership|jarvis"
    return
  fi

  echo "${lead}|${department}|${lead}"
}

# ---- Write to Agent INBOX ----

write_to_inbox() {
  local agent_id="$1"
  local title="$2"
  local priority="$3"
  local tags="$4"
  local task_id="$5"
  local depends_on="${6:-}"
  local details="${7:-}"
  local sync_key="${8:-}"
  local source_ref="${9:-}"
  local signal_severity="${10:-}"
  local score_rationale="${11:-}"

  local inbox="$REPO_ROOT/agents/$agent_id/INBOX.md"

  mkdir -p "$REPO_ROOT/agents/$agent_id"

  if [[ ! -f "$inbox" ]]; then
    cat > "$inbox" <<'INBOX_TEMPLATE'
# INBOX

> Cross-agent task assignments and messages.

## Pending

## Processed
INBOX_TEMPLATE
    echo "Created INBOX.md for $agent_id" >&2
  fi

  if ! grep -q "^## Pending" "$inbox"; then
    if grep -q "^## Processed" "$inbox"; then
      local tmp_inbox="${inbox}.tmp"
      awk '/^## Processed/ { print "## Pending"; print ""; } { print }' "$inbox" > "$tmp_inbox"
      mv "$tmp_inbox" "$inbox"
    else
      echo "" >> "$inbox"
      echo "## Pending" >> "$inbox"
      echo "" >> "$inbox"
      echo "## Processed" >> "$inbox"
    fi
  fi

  # Remove stale pending placeholder before inserting a new pending entry.
  if grep -q "^_No pending items\\._$" "$inbox"; then
    local tmp_clean="${inbox}.clean"
    grep -v "^_No pending items\\._$" "$inbox" > "$tmp_clean"
    mv "$tmp_clean" "$inbox"
  fi

  local timestamp
  timestamp="$(iso_now)"

  local entry=""
  entry+="### [$timestamp] From: dispatch | Priority: $priority"
  entry+=$'\n'"$title"
  entry+=$'\n'"Task-ID: $task_id"
  entry+=$'\n'"Tags: $tags"
  if [[ -n "$sync_key" ]]; then
    entry+=$'\n'"Sync-Key: $sync_key"
  fi
  if [[ -n "$source_ref" ]]; then
    entry+=$'\n'"Source-Ref: $source_ref"
  fi
  if [[ -n "$signal_severity" ]]; then
    entry+=$'\n'"Signal-Severity: $signal_severity"
  fi
  if [[ -n "$score_rationale" ]]; then
    entry+=$'\n'"Score-Rationale: $score_rationale"
  fi
  if [[ -n "$depends_on" ]]; then
    entry+=$'\n'"Depends-on: $depends_on"
  fi
  if [[ -n "$details" ]]; then
    entry+=$'\n'"Details:"
    entry+=$'\n'"$details"
  fi
  entry+=$'\n'

  local tmp_inbox="${inbox}.tmp"
  local entry_file
  entry_file="$(mktemp)"
  printf '%s\n' "$entry" > "$entry_file"

  {
    local found=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      echo "$line"
      if [[ "$line" == "## Pending"* && $found -eq 0 ]]; then
        found=1
        echo ""
        cat "$entry_file"
      fi
    done < "$inbox"
  } > "$tmp_inbox"
  mv "$tmp_inbox" "$inbox"
  rm -f "$entry_file"
}

# ---- Main ----

main() {
  local title=""
  local tag=""
  local priority="medium"
  local depends_on=""
  local source="manual"
  local agent_override=""
  local details=""
  local sync_key=""
  local source_ref=""
  local signal_severity=""
  local score_rationale=""

  if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
    title="$1"
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag)
        tag="$2"
        shift 2
        ;;
      --priority)
        priority="$2"
        shift 2
        ;;
      --depends-on)
        depends_on="$2"
        shift 2
        ;;
      --source)
        source="$2"
        shift 2
        ;;
      --agent)
        agent_override="$2"
        shift 2
        ;;
      --details)
        details="$2"
        shift 2
        ;;
      --sync-key)
        sync_key="$2"
        shift 2
        ;;
      --source-ref)
        source_ref="$2"
        shift 2
        ;;
      --signal-severity)
        signal_severity="$2"
        shift 2
        ;;
      --score-rationale)
        score_rationale="$2"
        shift 2
        ;;
      *)
        echo "ERROR: Unknown argument '$1'" >&2
        echo "Usage: dispatch-task.sh \"title\" --tag TAG --priority PRIORITY [--depends-on DEP] [--source SRC] [--agent AGENT] [--sync-key KEY] [--details TEXT]" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$title" ]]; then
    echo "ERROR: Title is required." >&2
    echo "Usage: dispatch-task.sh \"title\" --tag TAG --priority PRIORITY [--depends-on DEP] [--agent AGENT]" >&2
    exit 1
  fi

  validate_priority "$priority"

  local target_agent target_department target_lead

  if [[ -n "$agent_override" ]]; then
    target_agent="$agent_override"
    if [[ ! -d "$REPO_ROOT/agents/$target_agent" ]]; then
      echo "ERROR: Unknown target agent '$target_agent' (expected directory at agents/$target_agent)" >&2
      exit 1
    fi

    target_department="$(resolve_department_for_agent "$target_agent")"
    if [[ -z "$target_department" ]]; then
      target_department="leadership"
    fi
    target_lead="$target_agent"

    echo "Routing override: agent='$target_agent' -> department='$target_department'" >&2
  else
    local routing
    routing="$(resolve_routing "$tag")"
    target_agent="$(echo "$routing" | cut -d'|' -f1)"
    target_department="$(echo "$routing" | cut -d'|' -f2)"
    target_lead="$(echo "$routing" | cut -d'|' -f3)"

    echo "Routing: tag='${tag:-none}' -> department='$target_department' -> agent='$target_agent'" >&2
  fi

  if [[ -n "$sync_key" ]]; then
    local active_tasks_json
    active_tasks_json="$("$TASK_REGISTRY" find-active-by-sync-key "$sync_key" 2>/dev/null || echo "[]")"
    local existing_task_id existing_agent existing_department
    existing_task_id="$(jq -r '.[0].id // empty' <<< "$active_tasks_json")"
    if [[ -n "$existing_task_id" ]]; then
      existing_agent="$(jq -r '.[0].assigned_agent // empty' <<< "$active_tasks_json")"
      existing_department="$(jq -r '.[0].department // empty' <<< "$active_tasks_json")"
      if [[ -z "$existing_agent" ]]; then existing_agent="$target_agent"; fi
      if [[ -z "$existing_department" ]]; then existing_department="$target_department"; fi

      echo "Registry: active task already exists for sync_key '$sync_key' -> $existing_task_id" >&2
      echo ""
      echo "Dispatched: $existing_task_id -> $existing_agent ($existing_department)"
      return 0
    fi

    if [[ "$source" == "review-intent" && -f "$TASK_REGISTRY_FILE" ]]; then
      local existing_review_json
      existing_review_json="$(jq --arg key "$sync_key" '
        [ .tasks[]?
          | select((.source_sync_key // "") == $key)
          | select((.source // "") == "review-intent")
          | select(.status == "completed" or .status == "archived")
        ]
        | sort_by(.updated_at // .created_at // "")
        | last
      ' "$TASK_REGISTRY_FILE" 2>/dev/null || echo "null")"

      local existing_review_id existing_review_agent existing_review_department
      existing_review_id="$(jq -r '.id // empty' <<< "$existing_review_json")"
      if [[ -n "$existing_review_id" ]]; then
        existing_review_agent="$(jq -r '.assigned_agent // empty' <<< "$existing_review_json")"
        existing_review_department="$(jq -r '.department // empty' <<< "$existing_review_json")"
        if [[ -z "$existing_review_agent" ]]; then existing_review_agent="$target_agent"; fi
        if [[ -z "$existing_review_department" ]]; then existing_review_department="$target_department"; fi

        echo "Registry: completed review-intent task already exists for sync_key '$sync_key' -> $existing_review_id" >&2
        echo ""
        echo "Dispatched: $existing_review_id -> $existing_review_agent ($existing_review_department)"
        return 0
      fi
    fi
  fi

  local registry_args=("$title" --priority "$priority" --agent "$target_agent" --department "$target_department" --source "$source")
  if [[ -n "$tag" ]]; then
    registry_args+=(--tag "$tag")
  fi
  if [[ -n "$depends_on" ]]; then
    registry_args+=(--depends-on "$depends_on")
  fi
  if [[ -n "$details" ]]; then
    registry_args+=(--details "$details")
  fi
  if [[ -n "$sync_key" ]]; then
    registry_args+=(--sync-key "$sync_key")
  fi
  if [[ -n "$source_ref" ]]; then
    registry_args+=(--source-ref "$source_ref")
  fi
  if [[ -n "$signal_severity" ]]; then
    registry_args+=(--signal-severity "$signal_severity")
  fi
  if [[ -n "$score_rationale" ]]; then
    registry_args+=(--score-rationale "$score_rationale")
  fi

  local task_id
  task_id=$("$TASK_REGISTRY" add "${registry_args[@]}" 2>/dev/null)

  echo "Registry: task $task_id created" >&2

  write_to_inbox "$target_agent" "$title" "$priority" "${tag:-untagged}" "$task_id" "$depends_on" "$details" "$sync_key" "$source_ref" "$signal_severity" "$score_rationale"

  echo "INBOX: Written to agents/$target_agent/INBOX.md" >&2
  echo ""
  echo "Dispatched: $task_id -> $target_agent ($target_department)"
}

main "$@"
