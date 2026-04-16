#!/usr/bin/env bash
# Thoughtseed Labs -- TeamForge Feed Sync
# Pulls TeamForge `agent_feed/v1` snapshots, validates schema, enriches/routs signals,
# writes immutable vault snapshots, materializes per-role slices, and tracks ingestion health.
#
# Usage:
#   ./scripts/teamforge-sync.sh sync [--dry-run] [--no-dispatch] [--input-file /path/feed.json]
#   ./scripts/teamforge-sync.sh replay /path/snapshot.json [--dry-run] [--no-dispatch]
#   ./scripts/teamforge-sync.sh status
#   ./scripts/teamforge-sync.sh quality [--input-file /path/feed.json]

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MANIFEST="$REPO_ROOT/manifest.yaml"
DISPATCH_SCRIPT="$REPO_ROOT/scripts/dispatch-task.sh"
STATE_DIR="$REPO_ROOT/.thoughtseed/teamforge"
STATE_FILE="$STATE_DIR/sync-state.json"
HEALTH_FILE="$STATE_DIR/health.json"
QUALITY_FILE="$STATE_DIR/quality-findings.json"
LATEST_FEED_FILE="$STATE_DIR/latest-feed.json"
SLICES_DIR="$STATE_DIR/slices"
REGISTRY_FILE="$REPO_ROOT/.thoughtseed/task-registry.json"

EXPECTED_SCHEMA_VERSION="${TEAMFORGE_EXPECTED_SCHEMA_VERSION:-agent_feed/v1}"
TEAMFORGE_FEED_URL="${TEAMFORGE_FEED_URL:-}"
TEAMFORGE_EXPORT_FILE="${TEAMFORGE_EXPORT_FILE:-}"
TEAMFORGE_EXPORT_CMD="${TEAMFORGE_EXPORT_CMD:-}"
TEAMFORGE_FEED_LIMIT="${TEAMFORGE_FEED_LIMIT:-500}"
TEAMFORGE_SNAPSHOTS_PATH="${TEAMFORGE_SNAPSHOTS_PATH:-vault/leadership/teamforge-feed}"
TEAMFORGE_RETENTION_DAYS="${TEAMFORGE_RETENTION_DAYS:-30}"
TEAMFORGE_ROLE_SLICE_MAX_ITEMS="${TEAMFORGE_ROLE_SLICE_MAX_ITEMS:-25}"
TEAMFORGE_DISPATCH_ENABLED="${TEAMFORGE_DISPATCH_ENABLED:-true}"
TEAMFORGE_DRIFT_THRESHOLD_SECONDS="${TEAMFORGE_DRIFT_THRESHOLD_SECONDS:-21600}"
TEAMFORGE_COOLDOWN_INFO_MINUTES="${TEAMFORGE_COOLDOWN_INFO_MINUTES:-120}"
TEAMFORGE_COOLDOWN_WARN_MINUTES="${TEAMFORGE_COOLDOWN_WARN_MINUTES:-60}"
TEAMFORGE_COOLDOWN_CRITICAL_MINUTES="${TEAMFORGE_COOLDOWN_CRITICAL_MINUTES:-0}"
TEAMFORGE_HEALTH_MAX_LAG_WARN_SECONDS="${TEAMFORGE_HEALTH_MAX_LAG_WARN_SECONDS:-3600}"
TEAMFORGE_HEALTH_FAILURE_RATE_WARN="${TEAMFORGE_HEALTH_FAILURE_RATE_WARN:-0.20}"
TEAMFORGE_HEALTH_MIN_COVERAGE_WARN="${TEAMFORGE_HEALTH_MIN_COVERAGE_WARN:-0.66}"

DRY_RUN=false
NO_DISPATCH=false
INPUT_FILE=""
CMD="${1:-sync}"
if [[ $# -gt 0 ]]; then
  shift
fi

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [teamforge-sync] [$level] $*" >&2
}

usage() {
  cat <<'USAGE'
Thoughtseed Labs TeamForge Feed Sync

Usage:
  teamforge-sync.sh sync [--dry-run] [--no-dispatch] [--input-file FILE]
  teamforge-sync.sh replay FILE [--dry-run] [--no-dispatch]
  teamforge-sync.sh status
  teamforge-sync.sh quality [--input-file FILE]

Options:
  --dry-run         Evaluate/score/route signals without dispatching tasks or mutating sync cursor
  --no-dispatch     Ingest and materialize artifacts without creating tasks
  --input-file      Read TeamForge export payload from a local JSON file
USAGE
}

require_dep() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: missing dependency '$cmd'" >&2
    exit 1
  fi
}

read_manifest_scalar() {
  local key="$1"
  if [[ ! -f "$MANIFEST" ]]; then
    return 0
  fi
  grep -E "^[[:space:]]*$key:[[:space:]]*" "$MANIFEST" | head -1 | sed -E "s/^[[:space:]]*$key:[[:space:]]*//" | sed -E 's/^"//; s/"$//' | xargs 2>/dev/null || true
}

load_manifest_overrides() {
  local v

  v="$(read_manifest_scalar "expected_schema_version")"
  if [[ -n "$v" ]]; then EXPECTED_SCHEMA_VERSION="$v"; fi

  v="$(read_manifest_scalar "feed_url")"
  if [[ -n "$v" ]]; then TEAMFORGE_FEED_URL="$v"; fi

  v="$(read_manifest_scalar "export_file")"
  if [[ -n "$v" ]]; then TEAMFORGE_EXPORT_FILE="$v"; fi

  v="$(read_manifest_scalar "feed_limit")"
  if [[ -n "$v" ]]; then TEAMFORGE_FEED_LIMIT="$v"; fi

  v="$(read_manifest_scalar "snapshots_path")"
  if [[ -n "$v" ]]; then TEAMFORGE_SNAPSHOTS_PATH="$v"; fi

  v="$(read_manifest_scalar "retention_days")"
  if [[ -n "$v" ]]; then TEAMFORGE_RETENTION_DAYS="$v"; fi

  v="$(read_manifest_scalar "role_slice_max_items")"
  if [[ -n "$v" ]]; then TEAMFORGE_ROLE_SLICE_MAX_ITEMS="$v"; fi

  v="$(read_manifest_scalar "dispatch_enabled")"
  if [[ -n "$v" ]]; then TEAMFORGE_DISPATCH_ENABLED="$v"; fi

  v="$(read_manifest_scalar "quality_drift_threshold_seconds")"
  if [[ -n "$v" ]]; then TEAMFORGE_DRIFT_THRESHOLD_SECONDS="$v"; fi

  v="$(read_manifest_scalar "cooldown_info_minutes")"
  if [[ -n "$v" ]]; then TEAMFORGE_COOLDOWN_INFO_MINUTES="$v"; fi

  v="$(read_manifest_scalar "cooldown_warn_minutes")"
  if [[ -n "$v" ]]; then TEAMFORGE_COOLDOWN_WARN_MINUTES="$v"; fi

  v="$(read_manifest_scalar "cooldown_critical_minutes")"
  if [[ -n "$v" ]]; then TEAMFORGE_COOLDOWN_CRITICAL_MINUTES="$v"; fi

  v="$(read_manifest_scalar "health_max_lag_warn_seconds")"
  if [[ -n "$v" ]]; then TEAMFORGE_HEALTH_MAX_LAG_WARN_SECONDS="$v"; fi

  v="$(read_manifest_scalar "health_failure_rate_warn")"
  if [[ -n "$v" ]]; then TEAMFORGE_HEALTH_FAILURE_RATE_WARN="$v"; fi

  v="$(read_manifest_scalar "health_min_coverage_warn")"
  if [[ -n "$v" ]]; then TEAMFORGE_HEALTH_MIN_COVERAGE_WARN="$v"; fi
}

ensure_state_layout() {
  mkdir -p "$STATE_DIR" "$SLICES_DIR"
  if [[ ! -f "$STATE_FILE" ]]; then
    cat > "$STATE_FILE" <<'JSON'
{
  "schemaVersion": "teamforge-sync/v1",
  "expectedFeedSchemaVersion": "agent_feed/v1",
  "cursor": null,
  "lastRunAt": null,
  "lastError": null,
  "latestSnapshotPath": null,
  "runs": {
    "total": 0,
    "success": 0,
    "failed": 0
  },
  "suppression": {
    "total": 0,
    "lastRun": 0
  },
  "seenSyncKeys": {},
  "cooldowns": {},
  "actions": {},
  "outcomes": {
    "resolved": 0,
    "partial": 0,
    "noChange": 0,
    "regressed": 0,
    "validatedSignals": 0,
    "avgTimeToResolutionSeconds": null,
    "recurrenceSignals": 0
  },
  "quality": {
    "score": 100,
    "findingCount": 0
  }
}
JSON
  fi
}

mark_failed_run() {
  local message="$1"
  local now="$2"
  local tmp
  tmp="$(mktemp)"
  jq --arg msg "$message" --arg now "$now" '
    .lastRunAt = $now
    | .lastError = $msg
    | .runs.total = ((.runs.total // 0) + 1)
    | .runs.failed = ((.runs.failed // 0) + 1)
  ' "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

url_encode() {
  printf '%s' "$1" | jq -sRr @uri
}

resolve_feed_payload() {
  local since_cursor="$1"
  local local_input_file="$2"
  local payload=""

  if [[ -n "$local_input_file" ]]; then
    if [[ ! -f "$local_input_file" ]]; then
      log "error" "Input file not found: $local_input_file"
      return 1
    fi
    cat "$local_input_file"
    return 0
  fi

  if [[ -n "$TEAMFORGE_EXPORT_FILE" ]] && [[ -f "$TEAMFORGE_EXPORT_FILE" ]]; then
    cat "$TEAMFORGE_EXPORT_FILE"
    return 0
  fi

  if [[ -n "$TEAMFORGE_EXPORT_CMD" ]]; then
    payload="$(SINCE_CURSOR="$since_cursor" TEAMFORGE_LIMIT="$TEAMFORGE_FEED_LIMIT" eval "$TEAMFORGE_EXPORT_CMD" 2>/dev/null || true)"
    if [[ -n "$payload" ]]; then
      printf '%s\n' "$payload"
      return 0
    fi
  fi

  if [[ -n "$TEAMFORGE_FEED_URL" ]]; then
    local url="$TEAMFORGE_FEED_URL"
    local sep="?"
    if [[ "$url" == *"?"* ]]; then
      sep="&"
    fi
    url="${url}${sep}limit=$(url_encode "$TEAMFORGE_FEED_LIMIT")"
    if [[ -n "$since_cursor" ]]; then
      url="${url}&sinceCursor=$(url_encode "$since_cursor")"
    fi

    payload="$(curl -sS --fail "$url" 2>/dev/null || true)"
    if [[ -n "$payload" ]]; then
      printf '%s\n' "$payload"
      return 0
    fi
  fi

  return 1
}

score_event() {
  local feed_severity="$1"
  local event_type="$2"
  local source="$3"
  local score=30
  local rationale=()

  case "$feed_severity" in
    critical) score=86; rationale+=("feed severity=critical") ;;
    warn) score=62; rationale+=("feed severity=warn") ;;
    info|"") score=32; rationale+=("feed severity=info") ;;
    *) score=40; rationale+=("feed severity=unknown(${feed_severity})") ;;
  esac

  if echo "$event_type" | grep -qiE 'failed|error|incident|outage|blocked|degraded'; then
    score=$((score + 18))
    rationale+=("high-risk event pattern")
  fi

  if echo "$event_type" | grep -qiE 'standup.miss|heartbeat'; then
    score=$((score + 12))
    rationale+=("operational cadence signal")
  fi

  if [[ "$source" == "slack" ]] && [[ "$feed_severity" == "info" ]]; then
    score=$((score - 8))
    rationale+=("slack-info noise dampening")
  fi

  if (( score < 0 )); then
    score=0
  fi
  if (( score > 100 )); then
    score=100
  fi

  local scored_severity="info"
  if (( score >= 80 )); then
    scored_severity="critical"
  elif (( score >= 48 )); then
    scored_severity="warn"
  fi

  printf '%s|%s|%s\n' "$scored_severity" "$score" "$(IFS='; '; echo "${rationale[*]}")"
}

route_owner_agent() {
  local event_type="$1"
  local scored_severity="$2"
  local owner_hint="$3"

  if [[ "$owner_hint" =~ ^agent: ]]; then
    echo "${owner_hint#agent:}|owner_hint_override"
    return 0
  fi

  if echo "$event_type" | grep -qiE 'standup.miss|heartbeat|quality|drift|sync.failed'; then
    echo "sentinel|rule:ops_reliability"
    return 0
  fi

  if echo "$event_type" | grep -qiE 'clockify|huly.issue|deploy|build|runtime|bug|error'; then
    echo "clawd|rule:engineering_signal"
    return 0
  fi

  if echo "$event_type" | grep -qiE 'content|copy|marketing|client|research'; then
    echo "sage|rule:content_signal"
    return 0
  fi

  if [[ "$scored_severity" == "critical" ]]; then
    echo "jarvis|fallback:critical_global"
    return 0
  fi

  echo "jarvis|fallback:default"
}

tag_for_owner() {
  local owner="$1"
  case "$owner" in
    clawd) echo "code" ;;
    sentinel) echo "qa" ;;
    sage) echo "content" ;;
    *) echo "ops" ;;
  esac
}

priority_for_severity() {
  local scored_severity="$1"
  case "$scored_severity" in
    critical) echo "critical" ;;
    warn) echo "high" ;;
    *) echo "medium" ;;
  esac
}

cooldown_seconds_for() {
  local scored_severity="$1"
  local minutes="$TEAMFORGE_COOLDOWN_INFO_MINUTES"
  case "$scored_severity" in
    critical) minutes="$TEAMFORGE_COOLDOWN_CRITICAL_MINUTES" ;;
    warn) minutes="$TEAMFORGE_COOLDOWN_WARN_MINUTES" ;;
    info) minutes="$TEAMFORGE_COOLDOWN_INFO_MINUTES" ;;
  esac
  echo $((minutes * 60))
}

summarize_item() {
  local item_json="$1"
  local summary
  summary="$(echo "$item_json" | jq -r '
    .payloadJson.summary
    // .payloadJson.title
    // .payloadJson.message
    // .payloadJson.text
    // .metadataJson.summary
    // .entityId
    // "no-summary"
  ' 2>/dev/null || echo "no-summary")"
  echo "$summary" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | sed -E 's/^ +| +$//'
}

trim_to_limit() {
  local text="$1"
  local limit="$2"
  local len="${#text}"
  if (( len <= limit )); then
    printf '%s' "$text"
    return
  fi
  printf '%s [truncated to %s chars]' "${text:0:limit}" "$limit"
}

write_snapshot_file() {
  local payload_json="$1"
  local now_iso="$2"
  local snapshot_base="$REPO_ROOT/$TEAMFORGE_SNAPSHOTS_PATH"
  local day_path
  day_path="$(date -u +"%Y/%m/%d")"
  local target_dir="$snapshot_base/$day_path"
  mkdir -p "$target_dir"

  local ts_slug
  ts_slug="$(date -u +"%Y%m%dT%H%M%SZ")"
  local nonce
  nonce="$(date -u +%s)"
  local target="$target_dir/teamforge-feed-${ts_slug}-${nonce}.json"
  local tmp
  tmp="$(mktemp)"
  printf '%s\n' "$payload_json" > "$tmp"
  mv "$tmp" "$target"
  echo "$target"
}

prune_old_snapshots() {
  local snapshot_base="$REPO_ROOT/$TEAMFORGE_SNAPSHOTS_PATH"
  if [[ ! -d "$snapshot_base" ]]; then
    return 0
  fi
  if [[ "$TEAMFORGE_RETENTION_DAYS" =~ ^[0-9]+$ ]] && (( TEAMFORGE_RETENTION_DAYS > 0 )); then
    find "$snapshot_base" -type f -name 'teamforge-feed-*.json' -mtime +"$TEAMFORGE_RETENTION_DAYS" -print0 2>/dev/null | xargs -0 rm -f 2>/dev/null || true
  fi
}

build_role_slice() {
  local role="$1"
  local records_json="$2"
  local now_iso="$3"
  local snapshot_path="$4"
  local output_file="$SLICES_DIR/${role}.json"

  jq --arg role "$role" \
     --arg now "$now_iso" \
     --arg snapshot "$snapshot_path" \
     --arg expected "$EXPECTED_SCHEMA_VERSION" \
     --argjson limit "$TEAMFORGE_ROLE_SLICE_MAX_ITEMS" '
    def in_role($role):
      if $role == "jarvis" then
        (.routeOwner == "jarvis")
        or (.scoredSeverity == "critical")
        or (.eventType | test("quality|drift|routing"; "i"))
      elif $role == "clawd" then
        (.routeOwner == "clawd")
        or (.source == "clockify")
        or (.eventType | test("huly\\.issue|deploy|build|runtime|bug|error"; "i"))
      elif $role == "sentinel" then
        (.routeOwner == "sentinel")
        or (.scoredSeverity == "critical")
        or (.eventType | test("standup|heartbeat|sync.failed|incident|quality|drift"; "i"))
      elif $role == "sage" then
        (.routeOwner == "sage")
        or (.eventType | test("content|copy|client|marketing|research"; "i"))
      else
        false
      end;

    [ .[] | select(.suppressed != true) | select(in_role($role)) ]
    | sort_by((-(.score // 0)), (.detectedAt // ""), (.syncKey // ""))
    | .[0:$limit] as $items
    | {
        schemaVersion: "teamforge-slice/v1",
        feedSchemaVersion: $expected,
        role: $role,
        generatedAt: $now,
        overlapPolicy: "Signals may exist in multiple role slices; routeOwner remains canonical dispatch owner.",
        fallbackRole: "jarvis",
        sourceSnapshot: $snapshot,
        itemCount: ($items | length),
        items: $items
      }
  ' <<< "$records_json" > "$output_file"
}

build_role_slices() {
  local records_json="$1"
  local now_iso="$2"
  local snapshot_path="$3"
  build_role_slice "jarvis" "$records_json" "$now_iso" "$snapshot_path"
  build_role_slice "clawd" "$records_json" "$now_iso" "$snapshot_path"
  build_role_slice "sentinel" "$records_json" "$now_iso" "$snapshot_path"
  build_role_slice "sage" "$records_json" "$now_iso" "$snapshot_path"
}

build_quality_findings() {
  local records_json="$1"
  jq --argjson drift "$TEAMFORGE_DRIFT_THRESHOLD_SECONDS" '
    [
      .[] as $r
      | (
          if (($r.ownerHint // "") == "" and ($r.routeOwner // "") == "jarvis") then
            {
              type: "orphan_owner",
              severity: "warn",
              syncKey: $r.syncKey,
              message: "Owner hint missing and route fell back to jarvis.",
              guidance: "Review cross-platform identity map and owner routing overrides."
            }
          else empty end
        ),
        (
          if (((($r.actorClockifyUserId // "") != "") or (($r.actorHulyPersonId // "") != "") or (($r.actorSlackUserId // "") != ""))
              and (($r.ownerHint // "") == "")) then
            {
              type: "stale_mapping",
              severity: "warn",
              syncKey: $r.syncKey,
              message: "Actor identifiers are present but ownerHint is empty.",
              guidance: "Refresh identity mappings and run manual override review."
            }
          else empty end
        ),
        (
          (((($r.detectedAt // null) | fromdateiso8601?) // 0) - ((($r.occurredAt // null) | fromdateiso8601?) // 0)) as $delta
          | ($delta | if . < 0 then - . else . end) as $abs_delta
          | if $abs_delta > $drift then
              {
                type: "timestamp_drift",
                severity: "info",
                syncKey: $r.syncKey,
                message: ("Observed detectedAt/occurredAt drift of " + ($abs_delta | tostring) + "s."),
                guidance: "Check upstream source clocks and sync scheduling intervals."
              }
            else empty end
        )
    ]
  ' <<< "$records_json"
}

build_quality_summary() {
  local findings_json="$1"
  jq '
    (reduce .[] as $f (0;
      . + (
        if $f.type == "stale_mapping" then 14
        elif $f.type == "orphan_owner" then 10
        elif $f.type == "timestamp_drift" then 4
        else 5
        end
      )
    )) as $penalty
    | (100 - $penalty) as $raw
    | {
        score: (if $raw < 0 then 0 else $raw end),
        findingCount: length,
        findingsByType: (group_by(.type) | map({type: .[0].type, count: length}))
      }
  ' <<< "$findings_json"
}

attach_outcomes_to_state() {
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    return 0
  fi

  local outcomes_json
  outcomes_json="$(jq '
    [.tasks[]? | select((.source_sync_key // "") != "")]
    | group_by(.source_sync_key)
    | map({
        syncKey: .[0].source_sync_key,
        statuses: (map(.status) | unique),
        firstCreatedAt: ([.[].created_at] | min),
        firstCompletedAt: ([.[] | select(.status == "completed") | (.updated_at // .created_at)] | min // null)
      }
      | . + {
          outcome:
            (if (.statuses | index("completed")) and ((.statuses | length) == 1) then "resolved"
             elif (.statuses | index("completed")) then "partial"
             elif (.statuses | index("failed")) then "regressed"
             elif (.statuses | index("blocked")) then "no-change"
             else "no-change" end),
          timeToResolutionSeconds:
            (if .firstCompletedAt == null then null
             else (((.firstCompletedAt | fromdateiso8601?) // 0) - ((.firstCreatedAt | fromdateiso8601?) // 0))
             end)
        }
    )
  ' "$REGISTRY_FILE" 2>/dev/null || echo "[]")"

  local tmp
  tmp="$(mktemp)"
  jq --argjson outcomes "$outcomes_json" '
    .actions = (
      reduce $outcomes[] as $o (.actions // {};
        if has($o.syncKey) then
          .[$o.syncKey] = (
            .[$o.syncKey]
            + {
                outcome: $o.outcome,
                firstCreatedAt: $o.firstCreatedAt,
                firstCompletedAt: $o.firstCompletedAt,
                timeToResolutionSeconds: $o.timeToResolutionSeconds
              }
          )
        else . end
      )
    )
    | .outcomes = (
      ($outcomes | map(.outcome)) as $all
      | ($outcomes | map(select(.outcome == "resolved")) | length) as $resolved
      | ($outcomes | map(select(.outcome == "partial")) | length) as $partial
      | ($outcomes | map(select(.outcome == "no-change")) | length) as $no_change
      | ($outcomes | map(select(.outcome == "regressed")) | length) as $regressed
      | ($outcomes | map(select(.timeToResolutionSeconds != null) | .timeToResolutionSeconds) | if length == 0 then null else (add / length) end) as $avg_ttr
      | ($outcomes | map(select(.outcome == "resolved")) | map(.syncKey)) as $resolved_keys
      | {
          resolved: $resolved,
          partial: $partial,
          noChange: $no_change,
          regressed: $regressed,
          validatedSignals: ($resolved + $partial + $regressed + $no_change),
          avgTimeToResolutionSeconds: $avg_ttr,
          recurrenceSignals:
            (
              [ $resolved_keys[] as $k
                | select(((.seenSyncKeys[$k].timesSeen // 0) > 1))
              ] | length
            )
        }
    )
  ' "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

write_health_snapshot() {
  local records_json="$1"
  local lag_json="$2"
  local quality_summary_json="$3"
  local now_iso="$4"
  local run_errors="$5"
  local run_dispatched="$6"

  local source_coverage_json
  source_coverage_json="$(jq '
    {
      expectedSources: ["clockify", "huly", "slack"],
      seenSources: ([.[].source] | unique)
    }
    | .ratio = (
      if (.expectedSources | length) == 0 then 1
      else (
        ([.expectedSources[] as $e | select((.seenSources | index($e)) != null)] | length) / (.expectedSources | length)
      )
      end
    )
  ' <<< "$records_json")"

  local state_json
  state_json="$(cat "$STATE_FILE")"

  jq -n \
    --arg now "$now_iso" \
    --argjson records "$records_json" \
    --argjson lag "$lag_json" \
    --argjson quality "$quality_summary_json" \
    --argjson coverage "$source_coverage_json" \
    --argjson state "$state_json" \
    --argjson errors "$run_errors" \
    --argjson dispatched "$run_dispatched" \
    --argjson lag_warn "$TEAMFORGE_HEALTH_MAX_LAG_WARN_SECONDS" \
    --argjson failure_warn "$TEAMFORGE_HEALTH_FAILURE_RATE_WARN" \
    --argjson coverage_warn "$TEAMFORGE_HEALTH_MIN_COVERAGE_WARN" '
    ($records | map(select(.suppressed == true)) | length) as $suppressed
    | ($records | map(select(.isNew == true)) | length) as $new
    | ($records | map(select(.isNew != true)) | length) as $skipped
    | ($state.runs.total // 0) as $run_total
    | ($state.runs.failed // 0) as $run_failed
    | ($run_total | if . == 0 then 0 else ($run_failed / .) end) as $failure_rate
    | {
        schemaVersion: "teamforge-health/v1",
        generatedAt: $now,
        metrics: {
          newSignals: $new,
          skippedSignals: $skipped,
          suppressedSignals: $suppressed,
          dispatchedSignals: $dispatched,
          errors: $errors,
          lag: $lag,
          coverage: $coverage,
          quality: $quality,
          failureRate: $failure_rate,
          runs: $state.runs,
          outcomes: ($state.outcomes // {})
        },
        alerts: {
          maxLagWarning: (($lag.maxSourceLagSeconds // 0) > $lag_warn),
          failureRateWarning: ($failure_rate > $failure_warn),
          coverageWarning: (($coverage.ratio // 1) < $coverage_warn)
        }
      }
  ' > "$HEALTH_FILE"
}

dispatch_signal() {
  local record_json="$1"
  local snapshot_path="$2"
  local sync_key event_type route_owner scored_severity score source summary priority tag details

  sync_key="$(echo "$record_json" | jq -r '.syncKey')"
  event_type="$(echo "$record_json" | jq -r '.eventType')"
  route_owner="$(echo "$record_json" | jq -r '.routeOwner')"
  scored_severity="$(echo "$record_json" | jq -r '.scoredSeverity')"
  score="$(echo "$record_json" | jq -r '.score')"
  source="$(echo "$record_json" | jq -r '.source')"
  summary="$(echo "$record_json" | jq -r '.summary')"

  priority="$(priority_for_severity "$scored_severity")"
  tag="$(tag_for_owner "$route_owner")"
  details=$(cat <<EOF
TeamForge context
- Sync key: $sync_key
- Source: $source
- Event type: $event_type
- Severity: $scored_severity
- Score: $score
- Snapshot: $snapshot_path
- Summary: $summary
EOF
)
  details="$(trim_to_limit "$details" 1600)"

  local title="[TeamForge:${source}] ${event_type} :: ${summary}"
  title="$(trim_to_limit "$title" 140)"

  local dispatch_output
  dispatch_output="$("$DISPATCH_SCRIPT" "$title" \
    --agent "$route_owner" \
    --tag "$tag" \
    --priority "$priority" \
    --source "teamforge" \
    --sync-key "$sync_key" \
    --source-ref "${source}:${event_type}" \
    --signal-severity "$scored_severity" \
    --score-rationale "$(echo "$record_json" | jq -r '.scoreRationale')" \
    --details "$details" 2>/dev/null || true)"

  local task_id
  task_id="$(echo "$dispatch_output" | awk '/^Dispatched:/{print $2; exit}')"
  if [[ -z "$task_id" ]]; then
    log "warn" "Dispatch failed for sync_key=$sync_key (owner=$route_owner, event=$event_type)"
    echo ""
    return
  fi
  echo "$task_id"
}

perform_sync() {
  local local_input_file="$1"
  local now_iso
  now_iso="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local now_epoch
  now_epoch="$(date -u +%s)"

  local since_cursor
  since_cursor="$(jq -r '.cursor // empty' "$STATE_FILE")"

  local payload
  payload="$(resolve_feed_payload "$since_cursor" "$local_input_file" || true)"
  if [[ -z "$payload" ]]; then
    local msg="Unable to resolve TeamForge feed payload. Configure feed_url/export_file/export_cmd."
    log "warn" "$msg"
    mark_failed_run "$msg" "$now_iso"
    return 1
  fi

  local schema_version
  schema_version="$(echo "$payload" | jq -r '.schemaVersion // empty' 2>/dev/null || true)"
  if [[ "$schema_version" != "$EXPECTED_SCHEMA_VERSION" ]]; then
    local msg="Schema mismatch: expected=$EXPECTED_SCHEMA_VERSION got=${schema_version:-missing}"
    log "error" "$msg"
    mark_failed_run "$msg" "$now_iso"
    return 1
  fi

  local next_cursor has_more lag_json
  next_cursor="$(echo "$payload" | jq -r '.nextCursor // empty')"
  has_more="$(echo "$payload" | jq -r '.hasMore // false')"
  lag_json="$(echo "$payload" | jq '.lag // {}')"

  local items_count
  items_count="$(echo "$payload" | jq '.items | length')"
  log "info" "Fetched TeamForge feed: items=$items_count, hasMore=$has_more"

  local records_file
  records_file="$(mktemp)"

  local run_new=0
  local run_skipped=0
  local run_suppressed=0
  local run_errors=0
  local run_dispatched=0

  while IFS= read -r item_b64; do
    local item_json sync_key source event_type entity_id occurred_at detected_at feed_severity owner_hint
    local actor_clockify actor_huly actor_slack
    item_json="$(printf '%s' "$item_b64" | base64 --decode)"

    sync_key="$(echo "$item_json" | jq -r '.syncKey // empty')"
    source="$(echo "$item_json" | jq -r '.source // "unknown"')"
    event_type="$(echo "$item_json" | jq -r '.eventType // "unknown"')"
    entity_id="$(echo "$item_json" | jq -r '.entityId // "unknown"')"
    occurred_at="$(echo "$item_json" | jq -r '.occurredAt // .occurred_at // empty')"
    detected_at="$(echo "$item_json" | jq -r '.detectedAt // .detected_at // empty')"
    feed_severity="$(echo "$item_json" | jq -r '.severity // "info"')"
    owner_hint="$(echo "$item_json" | jq -r '.ownerHint // empty')"
    actor_clockify="$(echo "$item_json" | jq -r '.actorClockifyUserId // empty')"
    actor_huly="$(echo "$item_json" | jq -r '.actorHulyPersonId // empty')"
    actor_slack="$(echo "$item_json" | jq -r '.actorSlackUserId // empty')"

    if [[ -z "$sync_key" ]]; then
      run_errors=$((run_errors + 1))
      continue
    fi

    local seen_count
    seen_count="$(jq -r --arg key "$sync_key" '.seenSyncKeys[$key].timesSeen // 0' "$STATE_FILE")"
    local is_new=false
    if [[ "$seen_count" == "0" ]]; then
      is_new=true
      run_new=$((run_new + 1))
    else
      run_skipped=$((run_skipped + 1))
    fi

    local score_triplet scored_severity score score_rationale
    score_triplet="$(score_event "$feed_severity" "$event_type" "$source")"
    scored_severity="$(echo "$score_triplet" | cut -d'|' -f1)"
    score="$(echo "$score_triplet" | cut -d'|' -f2)"
    score_rationale="$(echo "$score_triplet" | cut -d'|' -f3-)"

    local route_pair route_owner route_reason
    route_pair="$(route_owner_agent "$event_type" "$scored_severity" "$owner_hint")"
    route_owner="$(echo "$route_pair" | cut -d'|' -f1)"
    route_reason="$(echo "$route_pair" | cut -d'|' -f2-)"

    local dedupe_key
    dedupe_key="${event_type}|${entity_id}|${route_owner}"
    local cooldown_secs
    cooldown_secs="$(cooldown_seconds_for "$scored_severity")"

    local suppressed=false
    local suppression_reason=""
    local last_dispatched_epoch
    last_dispatched_epoch="$(jq -r --arg key "$dedupe_key" '.cooldowns[$key].lastDispatchedAt // empty | fromdateiso8601? // 0' "$STATE_FILE")"

    if [[ "$is_new" != "true" ]]; then
      suppressed=true
      suppression_reason="duplicate_sync_key"
    elif [[ "$scored_severity" != "critical" ]] && (( cooldown_secs > 0 )) && (( last_dispatched_epoch > 0 )) && (( now_epoch - last_dispatched_epoch < cooldown_secs )); then
      suppressed=true
      suppression_reason="cooldown_window"
    fi

    if [[ "$suppressed" == "true" ]]; then
      run_suppressed=$((run_suppressed + 1))
    fi

    local summary
    summary="$(summarize_item "$item_json")"
    summary="$(trim_to_limit "$summary" 220)"

    local task_id=""
    if [[ "$suppressed" != "true" ]] && [[ "$NO_DISPATCH" != "true" ]] && [[ "$TEAMFORGE_DISPATCH_ENABLED" == "true" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        log "info" "DRY-RUN dispatch preview sync_key=$sync_key route=$route_owner severity=$scored_severity score=$score summary=\"$summary\""
      else
        task_id="$(dispatch_signal "$(jq -n \
          --arg syncKey "$sync_key" \
          --arg source "$source" \
          --arg eventType "$event_type" \
          --arg routeOwner "$route_owner" \
          --arg scoredSeverity "$scored_severity" \
          --arg score "$score" \
          --arg summary "$summary" \
          --arg scoreRationale "$score_rationale" \
          '{syncKey:$syncKey,source:$source,eventType:$eventType,routeOwner:$routeOwner,scoredSeverity:$scoredSeverity,score:($score|tonumber),summary:$summary,scoreRationale:$scoreRationale}')" "$LATEST_FEED_FILE")"
        if [[ -n "$task_id" ]]; then
          run_dispatched=$((run_dispatched + 1))
        else
          run_errors=$((run_errors + 1))
        fi
      fi
    fi

    jq -n \
      --arg syncKey "$sync_key" \
      --arg source "$source" \
      --arg eventType "$event_type" \
      --arg entityId "$entity_id" \
      --arg occurredAt "$occurred_at" \
      --arg detectedAt "$detected_at" \
      --arg feedSeverity "$feed_severity" \
      --arg scoredSeverity "$scored_severity" \
      --argjson score "$score" \
      --arg ownerHint "$owner_hint" \
      --arg routeOwner "$route_owner" \
      --arg routeReason "$route_reason" \
      --arg summary "$summary" \
      --arg scoreRationale "$score_rationale" \
      --arg dedupeKey "$dedupe_key" \
      --arg suppressionReason "$suppression_reason" \
      --arg actorClockifyUserId "$actor_clockify" \
      --arg actorHulyPersonId "$actor_huly" \
      --arg actorSlackUserId "$actor_slack" \
      --arg taskId "$task_id" \
      --argjson isNew "$is_new" \
      --argjson suppressed "$suppressed" \
      '
      {
        syncKey: $syncKey,
        source: $source,
        eventType: $eventType,
        entityId: $entityId,
        occurredAt: $occurredAt,
        detectedAt: $detectedAt,
        feedSeverity: $feedSeverity,
        scoredSeverity: $scoredSeverity,
        score: $score,
        ownerHint: (if $ownerHint == "" then null else $ownerHint end),
        routeOwner: $routeOwner,
        routeReason: $routeReason,
        summary: $summary,
        scoreRationale: $scoreRationale,
        dedupeKey: $dedupeKey,
        isNew: $isNew,
        suppressed: $suppressed,
        suppressionReason: (if $suppressionReason == "" then null else $suppressionReason end),
        actorClockifyUserId: (if $actorClockifyUserId == "" then null else $actorClockifyUserId end),
        actorHulyPersonId: (if $actorHulyPersonId == "" then null else $actorHulyPersonId end),
        actorSlackUserId: (if $actorSlackUserId == "" then null else $actorSlackUserId end),
        taskId: (if $taskId == "" then null else $taskId end)
      }
    ' >> "$records_file"
  done < <(echo "$payload" | jq -r '.items[]? | @base64')

  local records_json
  records_json="$(jq -s '.' "$records_file")"
  rm -f "$records_file"

  local quality_findings_json quality_summary_json
  quality_findings_json="$(build_quality_findings "$records_json")"
  quality_summary_json="$(build_quality_summary "$quality_findings_json")"
  printf '%s\n' "$quality_findings_json" > "$QUALITY_FILE"

  local latest_feed_json
  latest_feed_json="$(jq -n \
    --arg now "$now_iso" \
    --arg expected "$EXPECTED_SCHEMA_VERSION" \
    --arg sinceCursor "$since_cursor" \
    --arg nextCursor "$next_cursor" \
    --argjson hasMore "$has_more" \
    --argjson lag "$lag_json" \
    --argjson records "$records_json" \
    --argjson quality "$quality_summary_json" \
    '{
      schemaVersion: "teamforge-ingest/v1",
      feedSchemaVersion: $expected,
      generatedAt: $now,
      sourceWindow: {
        sinceCursor: (if $sinceCursor == "" then null else $sinceCursor end),
        nextCursor: (if $nextCursor == "" then null else $nextCursor end),
        hasMore: $hasMore
      },
      lag: $lag,
      quality: $quality,
      items: $records
    }'
  )"
  printf '%s\n' "$latest_feed_json" > "$LATEST_FEED_FILE"

  local snapshot_path
  snapshot_path="$(write_snapshot_file "$latest_feed_json" "$now_iso")"
  prune_old_snapshots

  build_role_slices "$records_json" "$now_iso" "$snapshot_path"

  if [[ "$DRY_RUN" != "true" ]]; then
    local state_tmp
    state_tmp="$(mktemp)"
    jq --arg now "$now_iso" \
       --arg expected "$EXPECTED_SCHEMA_VERSION" \
       --arg nextCursor "$next_cursor" \
       --arg snapshot "$snapshot_path" \
       --argjson records "$records_json" \
       --argjson quality "$quality_summary_json" '
      .schemaVersion = "teamforge-sync/v1"
      | .expectedFeedSchemaVersion = $expected
      | .lastRunAt = $now
      | .lastError = null
      | .latestSnapshotPath = $snapshot
      | .cursor = (if $nextCursor == "" then .cursor else $nextCursor end)
      | .runs.total = ((.runs.total // 0) + 1)
      | .runs.success = ((.runs.success // 0) + 1)
      | .suppression.total = ((.suppression.total // 0) + ($records | map(select(.suppressed == true)) | length))
      | .suppression.lastRun = ($records | map(select(.suppressed == true)) | length)
      | .quality = $quality
      | .seenSyncKeys = (
          reduce $records[] as $r (.seenSyncKeys // {};
            .[$r.syncKey] = (
              (.[ $r.syncKey ] // {
                firstSeenAt: $now,
                timesSeen: 0
              })
              | .lastSeenAt = $now
              | .timesSeen = ((.timesSeen // 0) + 1)
              | .lastSeverity = $r.scoredSeverity
              | .lastScore = $r.score
              | .lastEventType = $r.eventType
              | .lastOwner = $r.routeOwner
            )
          )
        )
      | .cooldowns = (
          reduce $records[] as $r (.cooldowns // {};
            if $r.suppressed == true then
              .[$r.dedupeKey] = (
                (.[ $r.dedupeKey ] // {})
                | .suppressedCount = ((.suppressedCount // 0) + 1)
                | .lastSuppressedAt = $now
              )
            else
              .[$r.dedupeKey] = (
                (.[ $r.dedupeKey ] // {})
                | .lastDispatchedAt = $now
              )
            end
          )
        )
      | .actions = (
          reduce $records[] as $r (.actions // {};
            if (($r.taskId // null) != null and ($r.taskId // "") != "") then
              .[$r.syncKey] = (
                (.[ $r.syncKey ] // { taskIds: [] })
                | .taskIds = ((.taskIds + [$r.taskId]) | unique)
                | .lastTaskId = $r.taskId
                | .lastTaskAt = $now
                | .routeOwner = $r.routeOwner
                | .severity = $r.scoredSeverity
                | .lastScore = $r.score
              )
            else . end
          )
        )
    ' "$STATE_FILE" > "$state_tmp"
    mv "$state_tmp" "$STATE_FILE"
    attach_outcomes_to_state
  fi

  write_health_snapshot "$records_json" "$lag_json" "$quality_summary_json" "$now_iso" "$run_errors" "$run_dispatched"

  echo "TeamForge sync: new=$run_new skipped=$run_skipped suppressed=$run_suppressed dispatched=$run_dispatched errors=$run_errors has_more=$has_more"
  return 0
}

print_status() {
  ensure_state_layout
  if [[ ! -f "$HEALTH_FILE" ]]; then
    echo "No TeamForge health snapshot found."
    return 0
  fi
  jq '{
    generatedAt,
    metrics: {
      newSignals: .metrics.newSignals,
      skippedSignals: .metrics.skippedSignals,
      suppressedSignals: .metrics.suppressedSignals,
      dispatchedSignals: .metrics.dispatchedSignals,
      errors: .metrics.errors,
      lag: .metrics.lag,
      coverage: .metrics.coverage,
      quality: .metrics.quality,
      failureRate: .metrics.failureRate,
      outcomes: .metrics.outcomes
    },
    alerts
  }' "$HEALTH_FILE"
}

run_quality_only() {
  local local_input_file="$1"
  local payload
  payload="$(resolve_feed_payload "" "$local_input_file" || true)"
  if [[ -z "$payload" ]]; then
    log "error" "Unable to load feed payload for quality command"
    return 1
  fi
  local schema_version
  schema_version="$(echo "$payload" | jq -r '.schemaVersion // empty')"
  if [[ "$schema_version" != "$EXPECTED_SCHEMA_VERSION" ]]; then
    log "error" "Schema mismatch for quality command: expected=$EXPECTED_SCHEMA_VERSION got=${schema_version:-missing}"
    return 1
  fi
  local records_json
  records_json="$(echo "$payload" | jq '
    [.items[]? | {
      syncKey: .syncKey,
      source: .source,
      eventType: .eventType,
      entityId: .entityId,
      occurredAt: .occurredAt,
      detectedAt: .detectedAt,
      ownerHint: .ownerHint,
      routeOwner: "jarvis",
      actorClockifyUserId: .actorClockifyUserId,
      actorHulyPersonId: .actorHulyPersonId,
      actorSlackUserId: .actorSlackUserId
    }]
  ')"
  local findings quality
  findings="$(build_quality_findings "$records_json")"
  quality="$(build_quality_summary "$findings")"
  jq -n --argjson findings "$findings" --argjson quality "$quality" '{quality: $quality, findings: $findings}'
}

parse_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --no-dispatch)
        NO_DISPATCH=true
        shift
        ;;
      --input-file)
        INPUT_FILE="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "ERROR: Unknown option '$1'" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

main() {
  require_dep jq
  require_dep curl
  load_manifest_overrides
  ensure_state_layout

  case "$CMD" in
    sync)
      parse_flags "$@"
      perform_sync "$INPUT_FILE"
      ;;
    replay)
      if [[ $# -lt 1 ]]; then
        echo "ERROR: replay requires a snapshot file path" >&2
        usage >&2
        exit 1
      fi
      INPUT_FILE="$1"
      shift
      parse_flags "$@"
      perform_sync "$INPUT_FILE"
      ;;
    status)
      print_status
      ;;
    quality)
      parse_flags "$@"
      run_quality_only "$INPUT_FILE"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "ERROR: Unknown command '$CMD'" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"

