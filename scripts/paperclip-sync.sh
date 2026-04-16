#!/usr/bin/env bash
# Thoughtseed Labs -- Paperclip Sync
# Syncs Paperclip issues to agent INBOX.md and reports heartbeats back.
#
# Usage:
#   ./scripts/paperclip-sync.sh sync-issues       # Pull unresolved issues, dispatch new ones
#   ./scripts/paperclip-sync.sh sync-heartbeats    # Report agent heartbeats to Paperclip

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# ---- Configuration (from manifest.yaml or env) ----

PAPERCLIP_API="${PAPERCLIP_API_URL:-http://127.0.0.1:3100/api}"
PAPERCLIP_COMPANY="${PAPERCLIP_COMPANY_ID:-d89420ba-ce5a-45f6-bd0a-e735d2e02740}"
TASK_REGISTRY="$REPO_ROOT/scripts/task-registry.sh"
DISPATCH="$REPO_ROOT/scripts/dispatch-task.sh"
REGISTRY_FILE="$REPO_ROOT/.thoughtseed/task-registry.json"
TEAMFORGE_SLICES_DIR="${TEAMFORGE_SLICES_DIR:-$REPO_ROOT/.thoughtseed/teamforge/slices}"
TEAMFORGE_ENRICHMENT_MAX_ITEMS="${TEAMFORGE_ENRICHMENT_MAX_ITEMS:-3}"
TEAMFORGE_ENRICHMENT_MAX_CHARS="${TEAMFORGE_ENRICHMENT_MAX_CHARS:-1200}"
DRY_RUN=false

# Read from manifest.yaml if available
MANIFEST="$REPO_ROOT/manifest.yaml"
if [[ -f "$MANIFEST" ]]; then
  api_url=$(grep "api_url:" "$MANIFEST" | head -1 | sed 's/.*api_url: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs 2>/dev/null || true)
  if [[ -n "$api_url" ]]; then
    PAPERCLIP_API="$api_url"
  fi
  company_id=$(grep "company_id:" "$MANIFEST" | head -1 | sed 's/.*company_id: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | xargs 2>/dev/null || true)
  if [[ -n "$company_id" ]]; then
    PAPERCLIP_COMPANY="$company_id"
  fi
fi

normalize_api_base() {
  local base="${1%/}"
  if [[ "$base" == */api ]]; then
    echo "$base"
  else
    echo "$base/api"
  fi
}

PAPERCLIP_API="$(normalize_api_base "$PAPERCLIP_API")"

# ---- Dependency Check ----

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed." >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "ERROR: curl is required but not installed." >&2
  exit 1
fi

# ---- Logging ----

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [paperclip-sync] [$level] $*" >&2
}

trim_to_limit() {
  local text="$1"
  local limit="$2"
  if (( ${#text} <= limit )); then
    printf '%s' "$text"
    return
  fi
  printf '%s [truncated to %s chars]' "${text:0:limit}" "$limit"
}

extract_sync_key_from_text() {
  local text="$1"
  local hit
  hit="$(echo "$text" | grep -Eio 'sync[_ -]?key[[:space:]]*[:=][[:space:]]*[A-Za-z0-9:._|-]+' | head -1 || true)"
  if [[ -z "$hit" ]]; then
    echo ""
    return
  fi
  echo "$hit" | sed -E 's/.*[:=][[:space:]]*//'
}

resolve_teamforge_slice_file() {
  local role="$1"
  local candidate="$TEAMFORGE_SLICES_DIR/${role}.json"
  local fallback="$TEAMFORGE_SLICES_DIR/jarvis.json"
  if [[ -f "$candidate" ]]; then
    echo "$candidate"
    return
  fi
  if [[ -f "$fallback" ]]; then
    echo "$fallback"
    return
  fi
  echo ""
}

build_teamforge_enrichment_context() {
  local target_agent="$1"
  local issue_id="$2"
  local issue_title="$3"
  local issue_priority="$4"
  local issue_tag="$5"

  local slice_file
  slice_file="$(resolve_teamforge_slice_file "$target_agent")"
  if [[ -z "$slice_file" ]]; then
    echo ""
    return
  fi

  if ! jq empty "$slice_file" >/dev/null 2>&1; then
    log "warn" "Invalid TeamForge slice JSON: $slice_file"
    echo ""
    return
  fi

  local context
  context="$(jq -r \
    --arg issue_id "$issue_id" \
    --arg issue_title "$issue_title" \
    --arg issue_priority "$issue_priority" \
    --arg issue_tag "$issue_tag" \
    --arg role "$target_agent" \
    --argjson max_items "$TEAMFORGE_ENRICHMENT_MAX_ITEMS" '
    .items
    | sort_by((-(.score // 0)), (.detectedAt // ""), (.syncKey // ""))
    | .[0:$max_items]
    | if length == 0 then ""
      else
        (
          "TeamForge context (deterministic enrichment)",
          "- Target role: " + ($role | tostring),
          "- Source issue: " + $issue_id,
          "- Issue title: " + $issue_title,
          "- Issue priority: " + $issue_priority,
          "- Route tag: " + $issue_tag,
          (
            .[] |
            "- [" + ((.scoredSeverity // "info") | ascii_upcase) + "|" + ((.score // 0) | tostring) + "] "
            + (.eventType // "unknown-event")
            + " :: " + (.summary // .entityId // "n/a")
            + " | source=" + (.source // "unknown")
            + " | owner=" + (.routeOwner // "jarvis")
            + " | sync_key=" + (.syncKey // "n/a")
          )
        ) | join("\n")
      end
  ' "$slice_file")"

  trim_to_limit "$context" "$TEAMFORGE_ENRICHMENT_MAX_CHARS"
}

# ---- Tag inference from issue content ----

infer_tag() {
  local title="$1"
  local description="${2:-}"
  local combined
  combined="$(echo "$title $description" | tr '[:upper:]' '[:lower:]')"

  if echo "$combined" | grep -qE 'bug|error|crash|fix|broken'; then
    echo "code"
  elif echo "$combined" | grep -qE 'design|logo|visual|ui|ux|graphic'; then
    echo "design"
  elif echo "$combined" | grep -qE 'research|analyze|investigate|study'; then
    echo "research"
  elif echo "$combined" | grep -qE 'content|write|blog|article|copy'; then
    echo "content"
  elif echo "$combined" | grep -qE 'video|clip|motion|animate'; then
    echo "video"
  elif echo "$combined" | grep -qE 'strategy|plan|roadmap'; then
    echo "strategy"
  elif echo "$combined" | grep -qE 'test|qa|quality|review'; then
    echo "qa"
  elif echo "$combined" | grep -qE 'trend|signal|monitor'; then
    echo "trend"
  else
    echo "ops"
  fi
}

# ---- Sync Issues ----

sync_issues() {
  log "info" "Fetching issues from Paperclip: ${PAPERCLIP_API}/companies/${PAPERCLIP_COMPANY}/issues"

  local response
  response=$(curl -s -f "${PAPERCLIP_API}/companies/${PAPERCLIP_COMPANY}/issues" 2>/dev/null) || {
    log "error" "Failed to fetch issues from Paperclip API"
    exit 1
  }

  if [[ -z "$response" ]] || [[ "$response" == "null" ]]; then
    log "info" "No issues returned from Paperclip"
    exit 0
  fi

  local agent_map_file
  agent_map_file="$(mktemp)"

  local agents_response
  agents_response=$(curl -s -f "${PAPERCLIP_API}/companies/${PAPERCLIP_COMPANY}/agents" 2>/dev/null || true)
  if [[ -n "$agents_response" ]] && [[ "$agents_response" != "null" ]]; then
    echo "$agents_response" | jq -r '.[]? | select(.id and .urlKey) | [.id, .urlKey] | @tsv' > "$agent_map_file" 2>/dev/null || true
  fi

  # Ensure task registry exists
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    "$TASK_REGISTRY" init 2>/dev/null
  fi

  local issue_count
  issue_count=$(echo "$response" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo "0")
  log "info" "Found $issue_count issues"

  local dispatched=0
  local skipped=0
  local dry_run_previews=0

  while IFS= read -r issue; do
    local issue_id issue_identifier title description priority resolved status assignee_agent_id target_agent
    local tag issue_sync_key

    issue_id=$(echo "$issue" | jq -r '.id // .issue_id // empty')
    issue_identifier=$(echo "$issue" | jq -r '.identifier // empty')
    title=$(echo "$issue" | jq -r '.title // .name // "Untitled issue"')
    description=$(echo "$issue" | jq -r '.description // .body // ""')
    priority=$(echo "$issue" | jq -r '.priority // "medium"')
    resolved=$(echo "$issue" | jq -r '.resolved // .status // "open"')
    status=$(echo "$issue" | jq -r '.status // "todo"')
    assignee_agent_id=$(echo "$issue" | jq -r '.assigneeAgentId // empty')

    # Skip resolved and blocked issues.
    if [[ "$resolved" == "true" ]] || [[ "$resolved" == "resolved" ]] || [[ "$resolved" == "closed" ]]; then
      continue
    fi
    if [[ "$status" == "done" ]] || [[ "$status" == "cancelled" ]] || [[ "$status" == "blocked" ]] || [[ "$status" == "resolved" ]] || [[ "$status" == "closed" ]]; then
      continue
    fi

    if [[ -z "$issue_id" ]]; then
      continue
    fi

    # Check if already in task registry.
    local already_exists
    already_exists=$(jq --arg id "$issue_id" --arg identifier "$issue_identifier" '[.tasks[] | select(.source == "paperclip") | select((.title | contains($id)) or (($identifier != "") and (.title | contains($identifier))))] | length' "$REGISTRY_FILE" 2>/dev/null || echo "0")

    if [[ "$already_exists" -gt 0 ]]; then
      skipped=$(( skipped + 1 ))
      continue
    fi

    # Infer tag from issue content.
    tag=$(infer_tag "$title" "$description")
    issue_sync_key="$(extract_sync_key_from_text "$title $description")"

    # Prefer explicit Paperclip assignee when it maps to a local agent.
    target_agent=""
    if [[ -n "$assignee_agent_id" ]] && [[ -s "$agent_map_file" ]]; then
      target_agent=$(awk -F $'\t' -v assignee="$assignee_agent_id" '$1 == assignee { print $2; exit }' "$agent_map_file" 2>/dev/null || true)
      if [[ -n "$target_agent" ]] && [[ ! -d "$REPO_ROOT/agents/$target_agent" ]]; then
        log "warn" "Paperclip assignee maps to unknown local agent '$target_agent' for issue ${issue_identifier:-$issue_id}; falling back to tag routing"
        target_agent=""
      fi
    fi

    # Normalize priority
    case "$priority" in
      critical|high|medium|low) ;;
      urgent) priority="critical" ;;
      normal) priority="medium" ;;
      *) priority="medium" ;;
    esac

    # Build TeamForge enrichment context before dispatch so dry-run can preview.
    local enrichment_context
    enrichment_context="$(build_teamforge_enrichment_context "${target_agent:-jarvis}" "${issue_identifier:-$issue_id}" "$title" "$priority" "$tag")"

    # Dispatch to assignee when available; otherwise fall back to tag routing.
    if [[ -n "$target_agent" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_previews=$(( dry_run_previews + 1 ))
        log "info" "DRY-RUN dispatch preview: [${issue_identifier:-$issue_id}] $title (assignee: $target_agent, tag: $tag, priority: $priority)"
        if [[ -n "$enrichment_context" ]]; then
          log "info" "DRY-RUN context preview for ${issue_identifier:-$issue_id}: $(echo "$enrichment_context" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g')"
        fi
        continue
      else
        log "info" "Dispatching: [${issue_identifier:-$issue_id}] $title (assignee: $target_agent, tag: $tag, priority: $priority)"
        if [[ -n "$issue_sync_key" ]]; then
          "$DISPATCH" "[Paperclip:$issue_id] $title" --agent "$target_agent" --tag "$tag" --priority "$priority" --source "paperclip" --sync-key "$issue_sync_key" --source-ref "paperclip:${issue_id}" --details "$enrichment_context" 2>/dev/null || {
            log "warn" "Failed to dispatch issue $issue_id"
            continue
          }
        else
          "$DISPATCH" "[Paperclip:$issue_id] $title" --agent "$target_agent" --tag "$tag" --priority "$priority" --source "paperclip" --source-ref "paperclip:${issue_id}" --details "$enrichment_context" 2>/dev/null || {
            log "warn" "Failed to dispatch issue $issue_id"
            continue
          }
        fi
      fi
    else
      if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_previews=$(( dry_run_previews + 1 ))
        log "info" "DRY-RUN dispatch preview: [${issue_identifier:-$issue_id}] $title (tag: $tag, priority: $priority)"
        if [[ -n "$enrichment_context" ]]; then
          log "info" "DRY-RUN context preview for ${issue_identifier:-$issue_id}: $(echo "$enrichment_context" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g')"
        fi
        continue
      else
        log "info" "Dispatching: [${issue_identifier:-$issue_id}] $title (tag: $tag, priority: $priority)"
        if [[ -n "$issue_sync_key" ]]; then
          "$DISPATCH" "[Paperclip:$issue_id] $title" --tag "$tag" --priority "$priority" --source "paperclip" --sync-key "$issue_sync_key" --source-ref "paperclip:${issue_id}" --details "$enrichment_context" 2>/dev/null || {
            log "warn" "Failed to dispatch issue $issue_id"
            continue
          }
        else
          "$DISPATCH" "[Paperclip:$issue_id] $title" --tag "$tag" --priority "$priority" --source "paperclip" --source-ref "paperclip:${issue_id}" --details "$enrichment_context" 2>/dev/null || {
            log "warn" "Failed to dispatch issue $issue_id"
            continue
          }
        fi
      fi
    fi

    dispatched=$(( dispatched + 1 ))
  done < <(echo "$response" | jq -c '.[]? // empty' 2>/dev/null)

  rm -f "$agent_map_file"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "info" "Sync complete (dry-run): previews=$dry_run_previews, skipped=$skipped"
    echo "Issues synced (dry-run): previews=$dry_run_previews, skipped=$skipped (already tracked)"
  else
    log "info" "Sync complete: dispatched=$dispatched, skipped=$skipped"
    echo "Issues synced: dispatched=$dispatched, skipped=$skipped (already tracked)"
  fi
}

# ---- Sync Heartbeats ----

sync_heartbeats() {
  log "info" "Reporting heartbeats to Paperclip"

  local agents_dir="$REPO_ROOT/agents"
  local reported=0

  for agent_dir in "$agents_dir"/*/; do
    if [[ ! -d "$agent_dir" ]]; then
      continue
    fi

    local agent_id
    agent_id="$(basename "$agent_dir")"
    local heartbeat_file="$agent_dir/HEARTBEAT.md"

    if [[ ! -f "$heartbeat_file" ]]; then
      continue
    fi

    # Get last cycle info
    local last_entry
    last_entry=$(grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}' "$heartbeat_file" | tail -1 || true)

    if [[ -z "$last_entry" ]]; then
      continue
    fi

    local timestamp
    timestamp=$(echo "$last_entry" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z?' | head -1 || true)
    local outcome
    outcome=$(echo "$last_entry" | grep -oiE 'completed|blocked|failed|timeout|idle' | head -1 || echo "unknown")

    # POST to Paperclip
    curl -s -X POST "${PAPERCLIP_API}/companies/${PAPERCLIP_COMPANY}/heartbeat" \
      -H "Content-Type: application/json" \
      -d "{
        \"agent_id\": \"$agent_id\",
        \"outcome\": \"$outcome\",
        \"timestamp\": \"${timestamp:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}\"
      }" >/dev/null 2>&1 || {
      log "warn" "Failed to POST heartbeat for $agent_id"
      continue
    }

    reported=$(( reported + 1 ))
  done

  log "info" "Heartbeat sync complete: reported=$reported agents"
  echo "Heartbeats reported: $reported agents"
}

# ---- Entry Point ----

cmd="${1:-help}"
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "ERROR: Unknown option '$1'" >&2
      exit 1
      ;;
  esac
done

case "$cmd" in
  sync-issues)
    sync_issues
    ;;
  sync-heartbeats)
    sync_heartbeats
    ;;
  help|*)
    echo "Thoughtseed Labs Paperclip Sync"
    echo ""
    echo "Usage: $0 {sync-issues|sync-heartbeats} [--dry-run]"
    echo ""
    echo "  sync-issues      Pull unresolved Paperclip issues, dispatch new ones to agents"
    echo "  sync-heartbeats  Report agent heartbeat status back to Paperclip API"
    echo "  --dry-run        For sync-issues: preview deterministic TeamForge enrichment without dispatching"
    echo ""
    echo "Config:"
    echo "  PAPERCLIP_API_URL     API base URL (default: http://127.0.0.1:3100/api)"
    echo "  PAPERCLIP_COMPANY_ID  Company ID (default: from manifest.yaml)"
    ;;
esac
