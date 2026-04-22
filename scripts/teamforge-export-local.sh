#!/usr/bin/env bash
# Thoughtseed Labs -- Local TeamForge agent_feed exporter
#
# Reads the TeamForge desktop SQLite projection and emits the `agent_feed/v1`
# payload that `scripts/teamforge-sync.sh` expects.
#
# Environment:
#   TEAMFORGE_DB_PATH   Optional path to the TeamForge SQLite db.
#                      Defaults to macOS desktop app storage.
#   SINCE_CURSOR       Optional cursor encoded as "<detected_at>|<sync_key>".
#   SINCE_TIMESTAMP    Optional RFC3339/ISO timestamp lower bound.
#   TEAMFORGE_LIMIT    Optional max rows to emit (default 500).

set -euo pipefail

TEAMFORGE_DB_PATH="${TEAMFORGE_DB_PATH:-$HOME/Library/Application Support/com.thoughtseed.teamforge/teamforge.db}"
SINCE_CURSOR="${SINCE_CURSOR:-}"
SINCE_TIMESTAMP="${SINCE_TIMESTAMP:-}"
TEAMFORGE_LIMIT="${TEAMFORGE_LIMIT:-500}"

if [[ ! -f "$TEAMFORGE_DB_PATH" ]]; then
  echo "teamforge-export-local: sqlite db not found at $TEAMFORGE_DB_PATH" >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "teamforge-export-local: sqlite3 is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "teamforge-export-local: jq is required" >&2
  exit 1
fi

if [[ ! "$TEAMFORGE_LIMIT" =~ ^[0-9]+$ ]]; then
  echo "teamforge-export-local: TEAMFORGE_LIMIT must be numeric" >&2
  exit 1
fi

limit="$TEAMFORGE_LIMIT"
if (( limit < 1 )); then
  limit=1
fi
fetch_limit=$((limit + 1))

query_filter=""
if [[ -n "$SINCE_CURSOR" ]]; then
  cursor_detected_at="${SINCE_CURSOR%%|*}"
  cursor_sync_key="${SINCE_CURSOR#*|}"
  if [[ -z "$cursor_detected_at" || -z "$cursor_sync_key" || "$cursor_detected_at" == "$cursor_sync_key" ]]; then
    echo "teamforge-export-local: invalid SINCE_CURSOR format" >&2
    exit 1
  fi
  safe_detected_at="${cursor_detected_at//\'/''}"
  safe_sync_key="${cursor_sync_key//\'/''}"
  query_filter="WHERE (detected_at > '$safe_detected_at') OR (detected_at = '$safe_detected_at' AND sync_key > '$safe_sync_key')"
elif [[ -n "$SINCE_TIMESTAMP" ]]; then
  safe_since_timestamp="${SINCE_TIMESTAMP//\'/''}"
  query_filter="WHERE detected_at >= '$safe_since_timestamp'"
fi

items_json="$(sqlite3 -json "$TEAMFORGE_DB_PATH" "
  SELECT
    sync_key AS syncKey,
    source,
    event_type AS eventType,
    entity_type AS entityType,
    entity_id AS entityId,
    occurred_at AS occurredAt,
    detected_at AS detectedAt,
    severity,
    owner_hint AS ownerHint,
    actor_clockify_user_id AS actorClockifyUserId,
    actor_huly_person_id AS actorHulyPersonId,
    actor_slack_user_id AS actorSlackUserId,
    payload_json AS payloadJson,
    metadata_json AS metadataJson
  FROM agent_feed
  $query_filter
  ORDER BY detected_at ASC, sync_key ASC
  LIMIT $fetch_limit;
")"
if [[ -z "$items_json" ]]; then
  items_json='[]'
fi

sync_state_json="$(sqlite3 -json "$TEAMFORGE_DB_PATH" "
  SELECT
    source,
    entity,
    last_sync_at AS lastSyncAt
  FROM sync_state
  WHERE (source = 'agent_feed' AND entity = 'projection')
     OR (source = 'clockify' AND entity = 'time_entries')
     OR (source = 'huly' AND entity = 'issues')
     OR (source = 'slack' AND entity = 'messages_delta')
  ORDER BY source ASC, entity ASC;
")"
if [[ -z "$sync_state_json" ]]; then
  sync_state_json='[]'
fi

generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

jq -n \
  --arg generatedAt "$generated_at" \
  --arg sinceCursor "$SINCE_CURSOR" \
  --arg sinceTimestamp "$SINCE_TIMESTAMP" \
  --argjson limit "$limit" \
  --argjson items "$items_json" \
  --argjson sources "$sync_state_json" '
  ($items[:$limit] | map(
    .payloadJson = ((.payloadJson // "{}") | fromjson? // {})
    | .metadataJson = (
        if (.metadataJson // null) == null or .metadataJson == "" then null
        else ((.metadataJson | fromjson?) // null)
        end
      )
  )) as $page
  | {
      schemaVersion: "agent_feed/v1",
      generatedAt: $generatedAt,
      sinceCursor: (if $sinceCursor == "" then null else $sinceCursor end),
      sinceTimestamp: (if $sinceTimestamp == "" then null else $sinceTimestamp end),
      nextCursor: (
        if ($page | length) == 0 then null
        else ($page[-1].detectedAt + "|" + $page[-1].syncKey)
        end
      ),
      hasMore: (($items | length) > $limit),
      lag: {
        projectionLagSeconds: null,
        maxSourceLagSeconds: null,
        sources: ($sources | map({
          source,
          entity,
          lastSyncAt,
          lagSeconds: null
        }))
      },
      items: $page
    }
  '
