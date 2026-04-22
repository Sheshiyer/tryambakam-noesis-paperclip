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
TASK_REGISTRY_SCRIPT="$REPO_ROOT/scripts/task-registry.sh"
# shellcheck disable=SC1091
[[ -f "$REPO_ROOT/.env" ]] && set -a && . "$REPO_ROOT/.env" && set +a || true

EXPECTED_SCHEMA_VERSION="${TEAMFORGE_EXPECTED_SCHEMA_VERSION:-agent_feed/v1}"
TEAMFORGE_FEED_URL="${TEAMFORGE_FEED_URL:-${TEAMFORGE_AGENT_FEED_URL:-}}"
TEAMFORGE_EXPORT_FILE="${TEAMFORGE_EXPORT_FILE:-}"
TEAMFORGE_EXPORT_CMD="${TEAMFORGE_EXPORT_CMD:-}"
TEAMFORGE_FEED_BEARER_TOKEN="${TEAMFORGE_FEED_BEARER_TOKEN:-${TF_WEBHOOK_HMAC_SECRET:-}}"
TEAMFORGE_FEED_LIMIT="${TEAMFORGE_FEED_LIMIT:-500}"
TEAMFORGE_SNAPSHOTS_PATH="${TEAMFORGE_SNAPSHOTS_PATH:-vault/leadership/teamforge-feed}"
TEAMFORGE_RETENTION_DAYS="${TEAMFORGE_RETENTION_DAYS:-30}"
TEAMFORGE_ROLE_SLICE_MAX_ITEMS="${TEAMFORGE_ROLE_SLICE_MAX_ITEMS:-25}"
TEAMFORGE_DISPATCH_ENABLED="${TEAMFORGE_DISPATCH_ENABLED:-true}"
TEAMFORGE_DRIFT_THRESHOLD_SECONDS="${TEAMFORGE_DRIFT_THRESHOLD_SECONDS:-21600}"
TEAMFORGE_COOLDOWN_INFO_MINUTES="${TEAMFORGE_COOLDOWN_INFO_MINUTES:-120}"
TEAMFORGE_COOLDOWN_WARN_MINUTES="${TEAMFORGE_COOLDOWN_WARN_MINUTES:-60}"
TEAMFORGE_COOLDOWN_CRITICAL_MINUTES="${TEAMFORGE_COOLDOWN_CRITICAL_MINUTES:-0}"
TEAMFORGE_CLOCKIFY_INFO_ACTIVE_DAYS="${TEAMFORGE_CLOCKIFY_INFO_ACTIVE_DAYS:-14}"
TEAMFORGE_HEALTH_MAX_LAG_WARN_SECONDS="${TEAMFORGE_HEALTH_MAX_LAG_WARN_SECONDS:-3600}"
TEAMFORGE_HEALTH_FAILURE_RATE_WARN="${TEAMFORGE_HEALTH_FAILURE_RATE_WARN:-0.20}"
TEAMFORGE_HEALTH_MIN_COVERAGE_WARN="${TEAMFORGE_HEALTH_MIN_COVERAGE_WARN:-0.66}"
TEAMFORGE_RESOLVE_ERROR=""
TEAMFORGE_RESOLVE_PAYLOAD=""

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

iso_day_minus_days() {
  local days="${1:-0}"
  python3 - "$days" <<'PY'
import datetime
import sys

days = int(sys.argv[1]) if len(sys.argv) > 1 else 0
target_day = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)).date()
print(target_day.isoformat())
PY
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

  v="$(read_manifest_scalar "export_cmd")"
  if [[ -n "$v" ]]; then TEAMFORGE_EXPORT_CMD="$v"; fi

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

  v="$(read_manifest_scalar "clockify_info_active_days")"
  if [[ -n "$v" ]]; then TEAMFORGE_CLOCKIFY_INFO_ACTIVE_DAYS="$v"; fi

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
  },
  "clockifyPolicy": {
    "version": "clockify-info-policy/v1",
    "activeWindowDays": 14,
    "cutoffDay": null,
    "lastAppliedAt": null,
    "dailySeen": {},
    "lastRun": {
      "archivedCount": 0,
      "archivedRetention": 0,
      "archivedNonActionable": 0,
      "suppressedDuplicates": 0,
      "suppressedRetention": 0,
      "aggregatesVisible": 0,
      "rawClockifyLowSeverity": 0
    },
    "totals": {
      "archived": 0,
      "archivedRetention": 0,
      "archivedNonActionable": 0,
      "suppressedDuplicates": 0,
      "suppressedRetention": 0,
      "aggregatesVisible": 0
    }
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
  TEAMFORGE_RESOLVE_ERROR="Unable to resolve TeamForge feed payload. Configure feed_url/export_file/export_cmd."
  TEAMFORGE_RESOLVE_PAYLOAD=""

  if [[ -n "$local_input_file" ]]; then
    if [[ ! -f "$local_input_file" ]]; then
      TEAMFORGE_RESOLVE_ERROR="Input file not found: $local_input_file"
      log "error" "$TEAMFORGE_RESOLVE_ERROR"
      return 1
    fi
    TEAMFORGE_RESOLVE_PAYLOAD="$(cat "$local_input_file")"
    return 0
  fi

  if [[ -n "$TEAMFORGE_EXPORT_FILE" ]]; then
    if [[ -f "$TEAMFORGE_EXPORT_FILE" ]]; then
      TEAMFORGE_RESOLVE_PAYLOAD="$(cat "$TEAMFORGE_EXPORT_FILE")"
      return 0
    fi
    TEAMFORGE_RESOLVE_ERROR="Configured TeamForge export_file not found: $TEAMFORGE_EXPORT_FILE"
  fi

  if [[ -n "$TEAMFORGE_EXPORT_CMD" ]]; then
    local export_cmd_status=0
    payload="$(
      cd "$REPO_ROOT" && \
      SINCE_CURSOR="$since_cursor" TEAMFORGE_LIMIT="$TEAMFORGE_FEED_LIMIT" bash -lc "$TEAMFORGE_EXPORT_CMD" 2>/dev/null
    )" || export_cmd_status=$?
    if [[ -n "$payload" ]]; then
      TEAMFORGE_RESOLVE_PAYLOAD="$payload"
      return 0
    fi
    if (( export_cmd_status != 0 )); then
      TEAMFORGE_RESOLVE_ERROR="Configured TeamForge export_cmd failed with exit status $export_cmd_status"
    else
      TEAMFORGE_RESOLVE_ERROR="Configured TeamForge export_cmd returned an empty payload"
    fi
  fi

  if [[ -n "$TEAMFORGE_FEED_URL" ]]; then
    local url="$TEAMFORGE_FEED_URL"
    local sep="?"
    local -a curl_cmd=(curl -sS --fail -H "Accept: application/json")
    if [[ "$url" == *"?"* ]]; then
      sep="&"
    fi
    url="${url}${sep}limit=$(url_encode "$TEAMFORGE_FEED_LIMIT")"
    if [[ -n "$since_cursor" ]]; then
      url="${url}&sinceCursor=$(url_encode "$since_cursor")"
    fi
    if [[ -n "$TEAMFORGE_FEED_BEARER_TOKEN" ]]; then
      curl_cmd+=(-H "Authorization: Bearer $TEAMFORGE_FEED_BEARER_TOKEN")
    fi

    local curl_status=0
    local curl_output=""
    curl_output="$("${curl_cmd[@]}" "$url" 2>&1)" || curl_status=$?
    payload="$curl_output"
    if [[ -n "$payload" ]]; then
      if (( curl_status == 0 )); then
        TEAMFORGE_RESOLVE_PAYLOAD="$payload"
        return 0
      fi
      local compact_error
      compact_error="$(printf '%s' "$curl_output" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | sed -E 's/^ //; s/ $//')"
      TEAMFORGE_RESOLVE_ERROR="TeamForge feed_url fetch failed for $url (curl exit $curl_status): $compact_error"
    elif (( curl_status != 0 )); then
      TEAMFORGE_RESOLVE_ERROR="TeamForge feed_url fetch failed for $url (curl exit $curl_status)"
    else
      TEAMFORGE_RESOLVE_ERROR="TeamForge feed_url returned an empty payload: $url"
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

materialize_active_records() {
  local records_json="$1"
  local cutoff_day="$2"

  jq --arg cutoff "$cutoff_day" \
     --argjson activeDays "$TEAMFORGE_CLOCKIFY_INFO_ACTIVE_DAYS" '
    def clockify_recent:
      (.isClockifyLow == true)
      and ((.clockifyDay // "") >= $cutoff);

    def passthrough_records:
      [
        .[]
        | select(.isClockifyLow != true)
        | select(.suppressed != true)
      ];

    def clockify_aggregates:
      [
        .[]
        | select(clockify_recent)
      ]
      | sort_by(.clockifyBucket // "", .detectedAt // "", .syncKey // "")
      | group_by(.clockifyBucket)
      | map(
          . as $group
          | .[0] as $first
          | {
              syncKey: ("aggregate:v1:" + ($first.clockifyBucket // $first.syncKey)),
              source: $first.source,
              eventType: $first.eventType,
              entityId: ("aggregate:" + ($first.clockifyDay // "unknown")),
              occurredAt: ($group | map(.occurredAt // "") | min),
              detectedAt: ($group | map(.detectedAt // "") | max),
              feedSeverity: $first.feedSeverity,
              scoredSeverity: $first.scoredSeverity,
              score: ($group | map(.score // 0) | max),
              ownerHint: $first.ownerHint,
              routeOwner: $first.routeOwner,
              routeReason: "policy:clockify_daily_aggregate",
              summary:
                (if ($group | length) == 1 then
                   $first.summary
                 else
                   (($group | length | tostring) + " Clockify " + $first.eventType + " events on " + ($first.clockifyDay // "unknown"))
                 end),
              scoreRationale: $first.scoreRationale,
              dedupeKey: ($first.clockifyBucket // $first.dedupeKey),
              isNew: ($group | any(.isNew == true)),
              suppressed: false,
              dispatchEligible: false,
              isClockifyLow: true,
              clockifyDay: $first.clockifyDay,
              clockifyBucket: $first.clockifyBucket,
              suppressionReason: null,
              actorClockifyUserId: null,
              actorHulyPersonId: null,
              actorSlackUserId: null,
              taskId: null,
              policy: {
                name: "clockify_info_daily_aggregate",
                aggregated: true,
                rawCount: ($group | length),
                day: $first.clockifyDay,
                activeWindowDays: $activeDays,
                rawSyncKeys: ($group | map(.syncKey))
              }
            }
        );

    (passthrough_records + clockify_aggregates)
    | sort_by((-(.score // 0)), (.detectedAt // ""), (.syncKey // ""))
  ' <<< "$records_json"
}

build_quality_findings() {
  local records_json="$1"
  jq --argjson drift "$TEAMFORGE_DRIFT_THRESHOLD_SECONDS" '
    [
      .[] as $r
      | select((($r.isNew // true) == true))
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

reconcile_registry_from_inbox() {
  if [[ "$DRY_RUN" == "true" ]]; then
    return 0
  fi

  if [[ ! -x "$TASK_REGISTRY_SCRIPT" ]]; then
    return 0
  fi

  "$TASK_REGISTRY_SCRIPT" reconcile-inbox >/dev/null 2>&1 || log "warn" "task-registry reconcile-inbox failed; continuing without registry reconciliation"
}

apply_clockify_policy_archive_registry() {
  local now_iso="$1"
  local cutoff_day="$2"

  if [[ ! -f "$REGISTRY_FILE" ]]; then
    echo '{"archivedCount":0,"archivedRetention":0,"archivedNonActionable":0,"archivedItems":[]}'
    return 0
  fi

  local policy_blob
  policy_blob="$(jq --arg now "$now_iso" --arg cutoff "$cutoff_day" '
    def task_day:
      ((try (.source_sync_key // "" | capture("(?<day>[0-9]{4}-[0-9]{2}-[0-9]{2})[tT]") | .day) catch null)
       // ((.created_at // "")[0:10]));
    def is_active:
      (.status == "pending" or .status == "in_progress" or .status == "blocked");
    def is_clockify_low:
      (.source == "teamforge")
      and ((.source_ref // "") | tostring | startswith("clockify:"))
      and ((.signal_severity // "info") != "critical");
    def archive_reason($day):
      if ($day != "" and $day < $cutoff) then
        "clockify_info_retention_window"
      else
        "clockify_info_non_actionable"
      end;

    [ .tasks[]
      | select(is_clockify_low and is_active)
      | (task_day) as $day
      | {
          taskId: .id,
          syncKey: (.source_sync_key // ""),
          day: $day,
          eventType: ((.source_ref // "" | sub("^clockify:"; ""))),
          reason: archive_reason($day)
        }
    ] as $targets
    | {
        registry: (
          .tasks |= map(
            if (is_clockify_low and is_active) then
              (task_day) as $day
              | .status = "archived"
              | .updated_at = $now
              | .archived_at = $now
              | .archived_by = "teamforge-sync:clockify-policy"
              | .archive_reason = archive_reason($day)
            else .
            end
          )
          | .metadata = (.metadata // {})
          | .metadata.total = (.tasks | length)
          | .metadata.pending = ([.tasks[] | select(.status == "pending")] | length)
          | .metadata.in_progress = ([.tasks[] | select(.status == "in_progress")] | length)
          | .metadata.completed = ([.tasks[] | select(.status == "completed")] | length)
          | .metadata.blocked = ([.tasks[] | select(.status == "blocked")] | length)
          | .metadata.failed = ([.tasks[] | select(.status == "failed")] | length)
          | .metadata.archived = ([.tasks[] | select(.status == "archived")] | length)
          | .metadata.last_updated = $now
        ),
        summary: {
          archivedCount: ($targets | length),
          archivedRetention: ($targets | map(select(.reason == "clockify_info_retention_window")) | length),
          archivedNonActionable: ($targets | map(select(.reason == "clockify_info_non_actionable")) | length),
          archivedItems: $targets
        }
      }
  ' "$REGISTRY_FILE")"

  if [[ -z "$policy_blob" ]] || ! jq empty <<< "$policy_blob" >/dev/null 2>&1; then
    log "warn" "Clockify archive policy skipped: unable to materialize policy blob from task registry."
    echo '{"archivedCount":0,"archivedRetention":0,"archivedNonActionable":0,"archivedItems":[]}'
    return 0
  fi

  local tmp_registry
  tmp_registry="$(mktemp)"
  jq '.registry' <<< "$policy_blob" > "$tmp_registry"
  mv "$tmp_registry" "$REGISTRY_FILE"
  jq -c '.summary' <<< "$policy_blob"
}

update_clockify_policy_audit() {
  local now_iso="$1"
  local cutoff_day="$2"
  local archive_summary_json="$3"
  local run_summary_json="$4"

  local tmp
  tmp="$(mktemp)"
  jq --arg now "$now_iso" \
     --arg cutoff "$cutoff_day" \
     --argjson activeDays "$TEAMFORGE_CLOCKIFY_INFO_ACTIVE_DAYS" \
     --argjson archive "$archive_summary_json" \
     --argjson run "$run_summary_json" '
    .clockifyPolicy = (
      (.clockifyPolicy // {
        version: "clockify-info-policy/v1",
        activeWindowDays: $activeDays,
        cutoffDay: null,
        lastAppliedAt: null,
        dailySeen: {},
        lastRun: {},
        totals: {}
      })
      | .version = "clockify-info-policy/v1"
      | .activeWindowDays = $activeDays
      | .cutoffDay = $cutoff
      | .lastAppliedAt = $now
      | .lastRun = {
          archivedCount: ($archive.archivedCount // 0),
          archivedRetention: ($archive.archivedRetention // 0),
          archivedNonActionable: ($archive.archivedNonActionable // 0),
          suppressedDuplicates: ($run.suppressedDuplicates // 0),
          suppressedRetention: ($run.suppressedRetention // 0),
          aggregatesVisible: ($run.aggregatesVisible // 0),
          rawClockifyLowSeverity: ($run.rawClockifyLowSeverity // 0)
        }
      | .totals.archived = ((.totals.archived // 0) + ($archive.archivedCount // 0))
      | .totals.archivedRetention = ((.totals.archivedRetention // 0) + ($archive.archivedRetention // 0))
      | .totals.archivedNonActionable = ((.totals.archivedNonActionable // 0) + ($archive.archivedNonActionable // 0))
      | .totals.suppressedDuplicates = ((.totals.suppressedDuplicates // 0) + ($run.suppressedDuplicates // 0))
      | .totals.suppressedRetention = ((.totals.suppressedRetention // 0) + ($run.suppressedRetention // 0))
      | .totals.aggregatesVisible = ((.totals.aggregatesVisible // 0) + ($run.aggregatesVisible // 0))
    )
    | .actions = (
      reduce ($archive.archivedItems // [])[] as $item (.actions // {};
        if (($item.syncKey // "") == "") then
          .
        else
          .[$item.syncKey] = (
            (.[ $item.syncKey ] // {})
            | .archiveStatus = "archived"
            | .archiveReason = $item.reason
            | .archiveLastAt = $now
            | .archiveTaskIds = (
              ((.archiveTaskIds // []) + [($item.taskId // "")])
              | map(select(length > 0))
              | unique
            )
          )
        end
      )
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
      seenSources: ([.[] | select(.isNew == true) | .source] | unique)
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
          coverage: (
            $coverage
            | .evaluated = ($new > 0)
            | if ($new > 0) then . else (.ratio = null) end
          ),
          quality: $quality,
          failureRate: $failure_rate,
          failureRateCurrent: (if $errors > 0 then 1 else 0 end),
          failureRateScope: "historical_lifetime_runs",
          runs: $state.runs,
          outcomes: ($state.outcomes // {})
        },
        alerts: {
          maxLagWarning: (($lag.maxSourceLagSeconds // 0) > $lag_warn),
          failureRateWarning: ($errors > 0),
          coverageWarning: (($new > 0) and (($coverage.ratio // 1) < $coverage_warn))
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

  resolve_feed_payload "$since_cursor" "$local_input_file" || true
  local payload="$TEAMFORGE_RESOLVE_PAYLOAD"
  if [[ -z "$payload" ]]; then
    local msg="${TEAMFORGE_RESOLVE_ERROR:-Unable to resolve TeamForge feed payload. Configure feed_url/export_file/export_cmd.}"
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
  local clockify_cutoff_day
  clockify_cutoff_day="$(iso_day_minus_days "$TEAMFORGE_CLOCKIFY_INFO_ACTIVE_DAYS")"

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
    local is_clockify_low=false
    local dispatch_eligible=true
    local clockify_day=""
    local clockify_bucket=""

    local suppressed=false
    local suppression_reason=""
    local last_dispatched_epoch=0

    if [[ "$source" == "clockify" ]] && [[ "$scored_severity" != "critical" ]]; then
      is_clockify_low=true
      dispatch_eligible=false
      if [[ "$occurred_at" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        clockify_day="${BASH_REMATCH[1]}"
      elif [[ "$detected_at" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        clockify_day="${BASH_REMATCH[1]}"
      else
        clockify_day="${now_iso:0:10}"
      fi
      clockify_bucket="${event_type}|${clockify_day}|${route_owner}"
      dedupe_key="$clockify_bucket"
    fi

    last_dispatched_epoch="$(jq -r --arg key "$dedupe_key" '.cooldowns[$key].lastDispatchedAt // empty | fromdateiso8601? // 0' "$STATE_FILE")"

    if [[ "$is_new" != "true" ]]; then
      suppressed=true
      suppression_reason="duplicate_sync_key"
    elif [[ "$is_clockify_low" == "true" ]] && [[ "$clockify_day" < "$clockify_cutoff_day" ]]; then
      suppressed=true
      suppression_reason="clockify_info_retention_window"
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
    if [[ "$suppressed" != "true" ]] && [[ "$dispatch_eligible" == "true" ]] && [[ "$NO_DISPATCH" != "true" ]] && [[ "$TEAMFORGE_DISPATCH_ENABLED" == "true" ]]; then
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
      --arg clockifyDay "$clockify_day" \
      --arg clockifyBucket "$clockify_bucket" \
      --argjson isNew "$is_new" \
      --argjson suppressed "$suppressed" \
      --argjson isClockifyLow "$is_clockify_low" \
      --argjson dispatchEligible "$dispatch_eligible" \
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
        dispatchEligible: $dispatchEligible,
        isClockifyLow: $isClockifyLow,
        clockifyDay: (if $clockifyDay == "" then null else $clockifyDay end),
        clockifyBucket: (if $clockifyBucket == "" then null else $clockifyBucket end),
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

  local clockify_run_summary_json
  clockify_run_summary_json="$(jq --arg cutoff "$clockify_cutoff_day" '
    {
      rawClockifyLowSeverity: ([.[] | select(.isClockifyLow == true)] | length),
      aggregatesVisible: (
        [.[] | select(.isClockifyLow == true and (.clockifyDay // "") >= $cutoff and (.clockifyBucket // "") != "")]
        | group_by(.clockifyBucket)
        | length
      ),
      suppressedDuplicates: (
        [.[] | select(.isClockifyLow == true and (.clockifyDay // "") >= $cutoff and (.clockifyBucket // "") != "")]
        | group_by(.clockifyBucket)
        | map(if length > 1 then length - 1 else 0 end)
        | add // 0
      ),
      suppressedRetention: ([.[] | select(.isClockifyLow == true and (.clockifyDay // "") < $cutoff)] | length)
    }
  ' <<< "$records_json")"
  local clockify_archive_summary_json='{"archivedCount":0,"archivedRetention":0,"archivedNonActionable":0,"archivedItems":[]}'
  local clockify_archived_count=0
  local active_records_json
  active_records_json="$(materialize_active_records "$records_json" "$clockify_cutoff_day")"

  local quality_findings_json quality_summary_json
  if (( run_new == 0 )); then
    quality_findings_json='[]'
    quality_summary_json='{"score":100,"findingCount":0,"findingsByType":[]}'
  else
    quality_findings_json="$(build_quality_findings "$records_json")"
    quality_summary_json="$(build_quality_summary "$quality_findings_json")"
  fi
  printf '%s\n' "$quality_findings_json" > "$QUALITY_FILE"

  local latest_feed_json
  latest_feed_json="$(jq -n \
    --arg now "$now_iso" \
    --arg expected "$EXPECTED_SCHEMA_VERSION" \
    --arg sinceCursor "$since_cursor" \
    --arg nextCursor "$next_cursor" \
    --argjson hasMore "$has_more" \
    --argjson lag "$lag_json" \
    --argjson records "$active_records_json" \
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

  build_role_slices "$active_records_json" "$now_iso" "$snapshot_path"

  if [[ "$DRY_RUN" != "true" ]]; then
    local state_tmp
    state_tmp="$(mktemp)"
    jq --arg now "$now_iso" \
       --arg expected "$EXPECTED_SCHEMA_VERSION" \
       --arg nextCursor "$next_cursor" \
       --arg snapshot "$snapshot_path" \
       --arg cutoffDay "$clockify_cutoff_day" \
       --argjson clockifyActiveDays "$TEAMFORGE_CLOCKIFY_INFO_ACTIVE_DAYS" \
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
      | .clockifyPolicy = (
          (.clockifyPolicy // {})
          | .version = "clockify-info-policy/v1"
          | .activeWindowDays = $clockifyActiveDays
          | .cutoffDay = $cutoffDay
          | .dailySeen = (
              ((.dailySeen // {}) | with_entries(select((.value.day // "") >= $cutoffDay))) as $base
              | reduce ($records[] | select(.isClockifyLow == true and (.clockifyDay // "") >= $cutoffDay and (.clockifyBucket // "") != "")) as $r ($base;
                  .[$r.clockifyBucket] = (
                    (.[ $r.clockifyBucket ] // { count: 0 })
                    | .day = $r.clockifyDay
                    | .eventType = $r.eventType
                    | .routeOwner = $r.routeOwner
                    | .syncKey = $r.syncKey
                    | .summary = $r.summary
                    | .lastSeenAt = $now
                    | .count = ((.count // 0) + 1)
                  )
                )
            )
        )
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

    clockify_archive_summary_json="$(apply_clockify_policy_archive_registry "$now_iso" "$clockify_cutoff_day")"
    clockify_archived_count="$(jq -r '.archivedCount // 0' <<< "$clockify_archive_summary_json")"
    update_clockify_policy_audit "$now_iso" "$clockify_cutoff_day" "$clockify_archive_summary_json" "$clockify_run_summary_json"
    reconcile_registry_from_inbox
    attach_outcomes_to_state
  fi

  write_health_snapshot "$records_json" "$lag_json" "$quality_summary_json" "$now_iso" "$run_errors" "$run_dispatched"

  echo "TeamForge sync: new=$run_new skipped=$run_skipped suppressed=$run_suppressed dispatched=$run_dispatched errors=$run_errors clockify_archived=$clockify_archived_count has_more=$has_more"
  return 0
}

default_status_payload() {
  jq -n '
    {
      generatedAt: null,
      metrics: {
        newSignals: 0,
        skippedSignals: 0,
        suppressedSignals: 0,
        dispatchedSignals: 0,
        errors: 0,
        lag: {
          projectionLagSeconds: null,
          maxSourceLagSeconds: null,
          sources: []
        },
        coverage: {
          expectedSources: ["clockify", "huly", "slack"],
          seenSources: [],
          ratio: null,
          evaluated: false
        },
        quality: {
          score: 100,
          findingCount: 0,
          findingsByType: []
        },
        failureRate: 0,
        failureRateCurrent: 0,
        failureRateScope: "historical_lifetime_runs",
        outcomes: {
          resolved: 0,
          partial: 0,
          noChange: 0,
          regressed: 0,
          validatedSignals: 0,
          avgTimeToResolutionSeconds: null,
          recurrenceSignals: 0
        }
      },
      alerts: {
        maxLagWarning: false,
        failureRateWarning: false,
        coverageWarning: false
      }
    }
  '
}

print_status() {
  ensure_state_layout
  if [[ ! -f "$HEALTH_FILE" ]]; then
    log "warn" "No TeamForge health snapshot found at $HEALTH_FILE; emitting default status payload"
    default_status_payload
    return 0
  fi
  local status_json
  if ! status_json="$(
    jq --argjson lag_warn "$TEAMFORGE_HEALTH_MAX_LAG_WARN_SECONDS" --argjson coverage_warn "$TEAMFORGE_HEALTH_MIN_COVERAGE_WARN" '
    def to_bool($value; $fallback):
      if $value == null then
        $fallback
      elif (($value | type) == "boolean") then
        $value
      elif (($value | type) == "number") then
        ($value != 0)
      elif (($value | type) == "string") then
        (
          ($value | gsub("^\\s+|\\s+$"; "") | ascii_downcase) as $bool_str
          | (($bool_str | tonumber?) // null) as $bool_num
          | if $bool_num != null then
              ($bool_num != 0)
            elif ($bool_str == "true" or $bool_str == "1" or $bool_str == "yes") then
              true
            elif ($bool_str == "false" or $bool_str == "0" or $bool_str == "no") then
              false
            else
              $fallback
            end
        )
      else
        $fallback
      end;
    def to_trimmed_string_or_null($value):
      if $value == null then
        null
      else
        (($value | tostring | gsub("^\\s+|\\s+$"; "")) as $text
         | if ($text | length) == 0 then null else $text end)
      end;
    def to_source_token($value):
      (to_trimmed_string_or_null($value) as $source
       | if $source == null then null else ($source | ascii_downcase) end);
    def source_field_to_list($value):
      if (($value | type) == "string" or ($value | type) == "number") then
        [$value]
      else
        []
      end;
    def source_keys_from_object($obj):
      [
        ($obj | to_entries)[]
        | . as $entry
        | ($entry.value | type) as $value_type
        | if ($value_type == "null") then
            empty
          elif ($value_type == "string") then
            (to_trimmed_string_or_null($entry.value)) as $string_value
            | if ($string_value == null) then
                empty
              else
                (to_bool($string_value; null)) as $bool_value
                | if ($bool_value == false) then empty else $entry.key end
              end
          elif ($value_type == "boolean" or $value_type == "number") then
            (to_bool($entry.value; null)) as $bool_value
            | if ($bool_value == false) then empty else $entry.key end
          else
            $entry.key
          end
      ];
    def normalize_coverage_sources_value($value):
      if (($value | type) == "array") then
        [
          $value[]
          | if (type == "string" or type == "number") then
              .
            elif (type == "object") then
              if has("sources") then
                (normalize_coverage_sources_value(.sources)) as $nested_sources
                | if (($nested_sources | length) > 0) then
                    $nested_sources[]
                  else
                    (source_field_to_list(.source)[])
                  end
              elif has("source") then
                (source_field_to_list(.source)[])
              else
                empty
              end
            else
              empty
            end
        ]
      elif (($value | type) == "string" or ($value | type) == "number") then
        [$value]
      elif (($value | type) == "boolean") then
        []
      elif (($value | type) == "object") then
        (source_keys_from_object($value))
      else
        []
      end;
    def first_non_null($primary; $secondary):
      if $primary != null then
        $primary
      elif $secondary != null then
        $secondary
      else
        null
      end;
    def first_object($primary; $secondary):
      if ($primary != null and (($primary | type) == "object")) then
        $primary
      elif ($secondary != null and (($secondary | type) == "object")) then
        $secondary
      else
        {}
      end;
    (. as $root_raw | if (($root_raw | type) == "object") then $root_raw else {} end) as $root
    | (to_trimmed_string_or_null(first_non_null($root.generatedAt; $root.generated_at))) as $generated_at
    | (
        ($root.metrics // null) as $metrics_raw
        | if (($metrics_raw | type) == "object") then $metrics_raw else {} end
      ) as $metrics
    | (((first_non_null(
        first_non_null($metrics.newSignals; $metrics.new_signals);
        first_non_null($root.newSignals; $root.new_signals)
      ) | tonumber?) // 0) | if . < 0 then 0 else . end) as $new_signals
    | (((first_non_null(
        first_non_null($metrics.skippedSignals; $metrics.skipped_signals);
        first_non_null($root.skippedSignals; $root.skipped_signals)
      ) | tonumber?) // 0) | if . < 0 then 0 else . end) as $skipped_signals
    | (((first_non_null(
        first_non_null($metrics.suppressedSignals; $metrics.suppressed_signals);
        first_non_null($root.suppressedSignals; $root.suppressed_signals)
      ) | tonumber?) // 0) | if . < 0 then 0 else . end) as $suppressed_signals
    | (((first_non_null(
        first_non_null($metrics.dispatchedSignals; $metrics.dispatched_signals);
        first_non_null($root.dispatchedSignals; $root.dispatched_signals)
      ) | tonumber?) // 0) | if . < 0 then 0 else . end) as $dispatched_signals
    | (((first_non_null(
        first_non_null($metrics.errors; first_non_null($metrics.error_count; first_non_null($metrics.errors_count; first_non_null($metrics.errorCount; $metrics.errorsCount))));
        first_non_null($root.errors; first_non_null($root.error_count; first_non_null($root.errors_count; first_non_null($root.errorCount; $root.errorsCount))))
      ) | tonumber?) // 0) | if . < 0 then 0 else . end) as $errors_count
    | (first_object($metrics.lag; $root.lag)) as $lag
    | (
        (first_non_null($lag.sources; first_non_null($lag.lag_sources; $lag.lagSources))) as $lag_sources_raw
        | (if (($lag_sources_raw | type) == "array") then
             $lag_sources_raw
           elif (($lag_sources_raw | type) == "object") then
             (
               if (
                 ($lag_sources_raw | has("source"))
                 or ($lag_sources_raw | has("entity"))
                 or ($lag_sources_raw | has("lastSyncAt"))
                 or ($lag_sources_raw | has("last_sync_at"))
                 or ($lag_sources_raw | has("lagSeconds"))
                 or ($lag_sources_raw | has("lag_seconds"))
               ) then
                 [$lag_sources_raw]
               elif ($lag_sources_raw | has("sources")) then
                 (
                   ($lag_sources_raw.sources) as $lag_sources_nested
                   | if (($lag_sources_nested | type) == "array") then
                       $lag_sources_nested
                     elif (($lag_sources_nested | type) == "string" or ($lag_sources_nested | type) == "number" or ($lag_sources_nested | type) == "boolean") then
                       [$lag_sources_nested]
                     elif (($lag_sources_nested | type) == "object") then
                       (
                         if (
                           ($lag_sources_nested | has("source"))
                           or ($lag_sources_nested | has("entity"))
                           or ($lag_sources_nested | has("lastSyncAt"))
                           or ($lag_sources_nested | has("last_sync_at"))
                           or ($lag_sources_nested | has("lagSeconds"))
                           or ($lag_sources_nested | has("lag_seconds"))
                         ) then
                           [$lag_sources_nested]
                         else
                           (
                             $lag_sources_nested
                             | to_entries
                             | map(
                                 if ((.value | type) == "object") then
                                   (.value + { source: (first_non_null(.value.source; .key)) })
                                 elif ((.value | type) == "boolean") then
                                   empty
                                 elif ((.value | type) == "string" or (.value | type) == "number") then
                                   { source: .key, lagSeconds: .value }
                                 else
                                   { source: .key }
                                 end
                               )
                           )
                         end
                       )
                     else
                       []
                     end
                 )
               else
                 (
                   $lag_sources_raw
                   | to_entries
                   | map(
                       if ((.value | type) == "object") then
                         (.value + { source: (first_non_null(.value.source; .key)) })
                       elif ((.value | type) == "boolean") then
                         empty
                       elif ((.value | type) == "string" or (.value | type) == "number") then
                         { source: .key, lagSeconds: .value }
                       else
                         { source: .key }
                       end
                     )
                 )
               end
             )
           elif (($lag_sources_raw | type) == "string" or ($lag_sources_raw | type) == "number" or ($lag_sources_raw | type) == "boolean") then
             [$lag_sources_raw]
           else
             []
           end)
        | map(
	            if (type == "object") then
	              {
	                source: (to_source_token(.source)),
	                entity: (to_trimmed_string_or_null(.entity)),
	                lastSyncAt: (to_trimmed_string_or_null(first_non_null(.lastSyncAt; .last_sync_at))),
	                lagSeconds: (
	                  ((first_non_null(.lagSeconds; .lag_seconds) | tonumber?) // null) as $lag_seconds_raw
	                  | if $lag_seconds_raw == null then
	                      null
	                    elif $lag_seconds_raw < 0 then
	                      0
                    else
                      $lag_seconds_raw
                    end
                )
              }
            elif (type == "boolean") then
              empty
            elif (type == "string" or type == "number") then
              {
                source: (to_source_token(.)),
                entity: null,
                lastSyncAt: null,
                lagSeconds: null
              }
            else
              {
                source: null,
                entity: null,
                lastSyncAt: null,
                lagSeconds: null
              }
            end
          )
      ) as $lag_sources
    | (
	        (((first_non_null($lag.maxSourceLagSeconds; $lag.max_source_lag_seconds) | tonumber?) // null)) as $lag_max_raw
        | if $lag_max_raw == null then
            null
          elif $lag_max_raw < 0 then
            0
          else
            $lag_max_raw
          end
      ) as $lag_max_raw
    | (
        if ($lag_max_raw != null) then
          $lag_max_raw
        else
          ([ $lag_sources[] | select(.source != null) | .lagSeconds | select(type == "number") ] | max // null)
        end
      ) as $lag_max
    | {
        projectionLagSeconds: (
	          (((first_non_null($lag.projectionLagSeconds; $lag.projection_lag_seconds) | tonumber?) // null)) as $projection_lag_raw
          | if $projection_lag_raw == null then
              null
            elif $projection_lag_raw < 0 then
              0
            else
              $projection_lag_raw
            end
        ),
        maxSourceLagSeconds: $lag_max,
        sources: $lag_sources
      } as $lag_norm
    | (first_object($metrics.coverage; $root.coverage)) as $coverage
    | (to_bool((first_non_null($coverage.evaluated; first_non_null($coverage.is_evaluated; first_non_null($coverage.coverage_evaluated; first_non_null($coverage.isEvaluated; $coverage.coverageEvaluated))))); ($new_signals > 0))) as $evaluated
    | (
        (
          (first_non_null($coverage.expectedSources; $coverage.expected_sources)) as $expected_raw
          | if (($expected_raw | type) == "array") then
              (normalize_coverage_sources_value($expected_raw))
            elif (($expected_raw | type) == "string" or ($expected_raw | type) == "number") then
              [$expected_raw]
            elif (($expected_raw | type) == "boolean") then
              []
            elif (($expected_raw | type) == "object") then
              (
                (source_field_to_list($expected_raw.source)) as $expected_source_field
                | if ($expected_raw | has("sources")) then
                    (normalize_coverage_sources_value($expected_raw.sources)) as $expected_sources_field
                    | if (($expected_sources_field | length) > 0) then
                        $expected_sources_field
                      elif (($expected_source_field | length) > 0) then
                        $expected_source_field
                      else
                        []
                      end
                  elif ($expected_raw | has("source")) then
                    if (($expected_source_field | length) > 0) then
                      $expected_source_field
                    else
                      []
                    end
                  else
                    (source_keys_from_object($expected_raw))
                  end
              )
            else
              ["clockify", "huly", "slack"]
            end
        )
        | map(select(. != null) | tostring | gsub("^\\s+|\\s+$"; "") | ascii_downcase)
        | map(select(length > 0))
        | unique
      ) as $expected
    | (
        (
          (first_non_null($coverage.seenSources; $coverage.seen_sources)) as $seen_raw
          | if (($seen_raw | type) == "array") then
              (normalize_coverage_sources_value($seen_raw))
            elif (($seen_raw | type) == "string" or ($seen_raw | type) == "number") then
              [$seen_raw]
            elif (($seen_raw | type) == "boolean") then
              []
            elif (($seen_raw | type) == "object") then
              (
                (source_field_to_list($seen_raw.source)) as $seen_source_field
                | if ($seen_raw | has("sources")) then
                    (normalize_coverage_sources_value($seen_raw.sources)) as $seen_sources_field
                    | if (($seen_sources_field | length) > 0) then
                        $seen_sources_field
                      elif (($seen_source_field | length) > 0) then
                        $seen_source_field
                      else
                        []
                      end
                  elif ($seen_raw | has("source")) then
                    if (($seen_source_field | length) > 0) then
                      $seen_source_field
                    else
                      []
                    end
                  else
                    (source_keys_from_object($seen_raw))
                  end
              )
            else
              []
            end
        )
        | map(select(. != null) | tostring | gsub("^\\s+|\\s+$"; "") | ascii_downcase)
        | map(select(length > 0))
        | unique
      ) as $seen
    | (((first_non_null($coverage.ratio; first_non_null($coverage.coverage_ratio; $coverage.coverageRatio)) | tonumber?) // null)) as $coverage_ratio_raw
    | {
        expectedSources: $expected,
        seenSources: $seen,
        ratio: (
          if ($evaluated == false) then null
          elif ($coverage_ratio_raw != null) then
            (if $coverage_ratio_raw < 0 then 0 elif $coverage_ratio_raw > 1 then 1 else $coverage_ratio_raw end)
          elif (($expected | length) == 0) then 1
          else (
            ([ $expected[] as $e | select(($seen | index($e)) != null) ] | length)
            / ($expected | length)
          )
          end
        ),
        evaluated: $evaluated
      } as $coverage_norm
    | (first_object($metrics.quality; $root.quality)) as $quality_raw
    | (
        (
          (first_non_null($quality_raw.findingsByType; $quality_raw.findings_by_type) // []) as $quality_findings_raw
          | if (($quality_findings_raw | type) == "array") then
              $quality_findings_raw
            elif (($quality_findings_raw | type) == "object") then
              (
                $quality_findings_raw
                | to_entries
                | map({
                    type: .key,
                    count: (
                      if ((.value | type) == "object") then
                        (.value.count // 1)
                      else
                        .value
                      end
                    )
                  })
              )
            else
              []
            end
        )
        | map(
            if type == "string" then
              (
                (. | gsub("^\\s+|\\s+$"; "") | ascii_downcase) as $quality_type_norm
                | {
                    type: (if ($quality_type_norm | length) == 0 then "unknown" else $quality_type_norm end),
                    count: 1
                  }
              )
            elif type == "object" then
              (
                ((.type // "unknown") | tostring | gsub("^\\s+|\\s+$"; "") | ascii_downcase) as $quality_type_norm
                | {
                    type: (if ($quality_type_norm | length) == 0 then "unknown" else $quality_type_norm end),
                    count: (
                      ((.count // 1) | tonumber? // 1)
                      | if . < 0 then 0 else . end
                    )
                  }
              )
            else
              empty
            end
          )
        | sort_by(.type)
        | group_by(.type)
        | map({
            type: .[0].type,
            count: ([ .[] | (.count // 0) ] | add // 0)
          })
      ) as $quality_types
    | (
        ((first_non_null($quality_raw.findingCount; $quality_raw.finding_count) | tonumber?) // null) as $count_raw
        | if ($count_raw != null and $count_raw >= 0) then
            $count_raw
          else
            ([ $quality_types[] | (.count // 0) ] | add // 0)
          end
      ) as $quality_count
    | (
        ((first_non_null($quality_raw.score; first_non_null($quality_raw.quality_score; $quality_raw.qualityScore)) | tonumber?) // null) as $score_raw
        | if $score_raw != null then
            (if $score_raw < 0 then 0 elif $score_raw > 100 then 100 else $score_raw end)
          else
            (
              100 - (
                if (($quality_types | length) == 0) then
                  (5 * ($quality_count // 0))
                else
                  reduce $quality_types[] as $f (0;
                    . + (
                      if $f.type == "stale_mapping" then
                        (14 * ($f.count // 0))
                      elif $f.type == "orphan_owner" then
                        (10 * ($f.count // 0))
                      elif $f.type == "timestamp_drift" then
                        (4 * ($f.count // 0))
                      else
                        (5 * ($f.count // 0))
                      end
                    )
                  )
                end
              )
            ) as $raw
            | if $raw < 0 then 0 else $raw end
          end
      ) as $quality_score
    | {
        score: $quality_score,
        findingCount: $quality_count,
        findingsByType: $quality_types
      } as $quality_norm
    | (first_object($metrics.outcomes; $root.outcomes)) as $outcomes
    | (((($outcomes.resolved | tonumber?) // 0)) | if . < 0 then 0 else . end) as $outcomes_resolved
    | (((($outcomes.partial | tonumber?) // 0)) | if . < 0 then 0 else . end) as $outcomes_partial
    | (((($outcomes.noChange | tonumber?) // ($outcomes["no-change"] | tonumber?) // ($outcomes.no_change | tonumber?) // 0)) | if . < 0 then 0 else . end) as $outcomes_no_change
    | (((($outcomes.regressed | tonumber?) // 0)) | if . < 0 then 0 else . end) as $outcomes_regressed
    | (((($outcomes.recurrenceSignals | tonumber?) // ($outcomes.recurrence_signals | tonumber?) // 0)) | if . < 0 then 0 else . end) as $outcomes_recurrence
    | ((($outcomes.avgTimeToResolutionSeconds | tonumber?) // ($outcomes.avg_time_to_resolution_seconds | tonumber?) // null)) as $outcomes_avg_ttr
    | (first_object($metrics.runs; $root.runs)) as $runs_raw
    | (((first_non_null($runs_raw.total; first_non_null($runs_raw.total_runs; $runs_raw.totalRuns)) | tonumber?) // 0) | if . < 0 then 0 else . end) as $runs_total
    | (((first_non_null($runs_raw.failed; first_non_null($runs_raw.failed_runs; $runs_raw.failedRuns)) | tonumber?) // 0) | if . < 0 then 0 else . end) as $runs_failed
    | (
        ((first_non_null(
            first_non_null($metrics.failureRate; $metrics.failure_rate);
            first_non_null($root.failureRate; $root.failure_rate)
          ) | tonumber?) // null) as $failure_rate_raw
        | if $failure_rate_raw != null then
            (if $failure_rate_raw < 0 then 0 elif $failure_rate_raw > 1 then 1 else $failure_rate_raw end)
          elif ($runs_total == 0) then
            0
          else
            ((($runs_failed / $runs_total) | if . < 0 then 0 elif . > 1 then 1 else . end))
          end
      ) as $failure_rate_norm
    | (
        to_bool(
          (first_non_null(
            first_non_null($metrics.failureRateCurrent; $metrics.failure_rate_current);
            first_non_null($root.failureRateCurrent; $root.failure_rate_current)
          ));
          ($errors_count > 0)
        )
      ) as $failure_rate_current_bool
    | (if $failure_rate_current_bool then 1 else 0 end) as $failure_rate_current_norm
    | {
        resolved: $outcomes_resolved,
        partial: $outcomes_partial,
        noChange: $outcomes_no_change,
        regressed: $outcomes_regressed,
        validatedSignals: (
          ((($outcomes.validatedSignals | tonumber?) // ($outcomes.validated_signals | tonumber?) // null))
          // ($outcomes_resolved + $outcomes_partial + $outcomes_no_change + $outcomes_regressed)
          | if . < 0 then 0 else . end
        ),
        avgTimeToResolutionSeconds: (
          if $outcomes_avg_ttr == null then
            null
          elif $outcomes_avg_ttr < 0 then
            null
          else
            $outcomes_avg_ttr
          end
        ),
        recurrenceSignals: $outcomes_recurrence
      } as $outcomes_norm
    | (
        ($root.alerts // null) as $alerts_raw_maybe
        | if (($alerts_raw_maybe | type) == "object") then $alerts_raw_maybe else {} end
      ) as $alerts_raw
    | ((($lag_norm.maxSourceLagSeconds // 0) > $lag_warn)) as $max_lag_alert_fallback
    | (($errors_count > 0)) as $failure_rate_alert_fallback
    | ((($coverage_norm.evaluated == true) and (($coverage_norm.ratio // 1) < $coverage_warn))) as $coverage_alert_fallback
    | (
        to_bool(
          (first_non_null(
            first_non_null($alerts_raw.maxLagWarning; $alerts_raw.max_lag_warning);
            first_non_null($root.maxLagWarning; $root.max_lag_warning)
          ));
          $max_lag_alert_fallback
        )
      ) as $max_lag_alert
    | (
        to_bool(
          (first_non_null(
            first_non_null($alerts_raw.failureRateWarning; $alerts_raw.failure_rate_warning);
            first_non_null($root.failureRateWarning; $root.failure_rate_warning)
          ));
          $failure_rate_alert_fallback
        )
      ) as $failure_rate_alert
    | (
        to_bool(
          (first_non_null(
            first_non_null($alerts_raw.coverageWarning; $alerts_raw.coverage_warning);
            first_non_null($root.coverageWarning; $root.coverage_warning)
          ));
          $coverage_alert_fallback
        )
      ) as $coverage_alert
    | (
        (first_non_null(
          first_non_null($metrics.failureRateScope; $metrics.failure_rate_scope);
          first_non_null($root.failureRateScope; $root.failure_rate_scope)
        )) as $scope_raw
        | if (($scope_raw | type) == "string") then
            (($scope_raw | gsub("^\\s+|\\s+$"; "") | ascii_downcase) as $scope_trim
             | if ($scope_trim | length) > 0 then $scope_trim else "historical_lifetime_runs" end)
          else
            "historical_lifetime_runs"
          end
      ) as $failure_rate_scope_norm
    | {
        generatedAt: $generated_at,
        metrics: {
          newSignals: $new_signals,
          skippedSignals: $skipped_signals,
          suppressedSignals: $suppressed_signals,
          dispatchedSignals: $dispatched_signals,
          errors: $errors_count,
          lag: $lag_norm,
          coverage: $coverage_norm,
          quality: $quality_norm,
          failureRate: $failure_rate_norm,
          failureRateCurrent: $failure_rate_current_norm,
          failureRateScope: $failure_rate_scope_norm,
          outcomes: $outcomes_norm
        },
        alerts: {
          maxLagWarning: $max_lag_alert,
          failureRateWarning: $failure_rate_alert,
          coverageWarning: $coverage_alert
        }
      }
  ' "$HEALTH_FILE" 2>/dev/null
  )"; then
    log "warn" "Health snapshot at $HEALTH_FILE is invalid JSON; emitting default status payload"
    status_json="$(default_status_payload)"
  fi
  echo "$status_json"
}

run_quality_only() {
  local local_input_file="$1"
  resolve_feed_payload "" "$local_input_file" || true
  local payload="$TEAMFORGE_RESOLVE_PAYLOAD"
  if [[ -z "$payload" ]]; then
    log "error" "${TEAMFORGE_RESOLVE_ERROR:-Unable to load feed payload for quality command}"
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
