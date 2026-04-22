#!/usr/bin/env bash
# Thoughtseed Labs Write-Back
# Takes parser JSON output and applies file updates to the agent's directory.
#
# Usage:
#   ./scripts/write-back.sh <agent_id> /path/to/parsed-output.json
#   cat parsed-output.json | ./scripts/write-back.sh <agent_id>
#
# Behavior:
#   - TASKS.md:    Full overwrite (parser provides complete file)
#   - HEARTBEAT.md: APPEND only (new entry appended to existing file)
#   - INBOX.md:    Full overwrite (parser provides complete file)
#   - CONTEXT.md:  APPEND new pitfalls (unless content is "NO_CHANGES")

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# ---- Logging (to stderr) ----

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [write-back] [$level] $*" >&2
}

# ---- Validate args ----

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <agent_id> [parsed-output.json]" >&2
  exit 1
fi

AGENT_ID="$1"
AGENT_DIR="$REPO_ROOT/agents/$AGENT_ID"

if [[ ! -d "$AGENT_DIR" ]]; then
  log "error" "Agent directory not found: $AGENT_DIR"
  exit 1
fi

# ---- Read JSON input ----

JSON_INPUT=""

if [[ $# -ge 2 ]] && [[ -f "$2" ]]; then
  JSON_INPUT=$(cat "$2")
  log "info" "Reading parsed output from file: $2"
elif [[ ! -t 0 ]]; then
  JSON_INPUT=$(cat)
  log "info" "Reading parsed output from stdin"
else
  log "error" "No input provided. Pass a file path or pipe stdin."
  exit 1
fi

# ---- Check for error in parser output ----

HAS_ERROR=$(echo "$JSON_INPUT" | python3 -c '
import sys, json
data = json.load(sys.stdin)
print("yes" if "error" in data else "no")
' 2>/dev/null || echo "parse_fail")

if [[ "$HAS_ERROR" == "parse_fail" ]]; then
  ERROR_MSG="invalid_json"
  log "warn" "Parser output was malformed JSON -- writing error context"

  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  if [[ -f "$AGENT_DIR/CONTEXT.md" ]]; then
    echo "" >> "$AGENT_DIR/CONTEXT.md"
    echo "- [$NOW] Loop cycle error: $ERROR_MSG -- write-back input was malformed JSON. Check logs for raw output." >> "$AGENT_DIR/CONTEXT.md"
    log "info" "Appended invalid-json error to CONTEXT.md"
  fi

  if [[ -f "$AGENT_DIR/HEARTBEAT.md" ]]; then
    {
      echo ""
      echo "### $NOW Cycle Result"
      echo "- Step: parse-error"
      echo "- Outcome: failed"
      echo "- Duration: 0s"
      echo "- Summary: Agent output could not be parsed ($ERROR_MSG)"
    } >> "$AGENT_DIR/HEARTBEAT.md"
    log "info" "Appended invalid-json failure entry to HEARTBEAT.md"
  fi

  exit 0
fi

if [[ "$HAS_ERROR" == "yes" ]]; then
  ERROR_MSG=$(echo "$JSON_INPUT" | python3 -c '
import sys, json
data = json.load(sys.stdin)
print(data.get("error", "unknown"))
')
  log "warn" "Parser returned error: $ERROR_MSG -- writing error context"

  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Write error to CONTEXT.md
  if [[ -f "$AGENT_DIR/CONTEXT.md" ]]; then
    echo "" >> "$AGENT_DIR/CONTEXT.md"
    echo "- [$NOW] Loop cycle error: $ERROR_MSG -- agent output was not parseable. Check logs for raw output." >> "$AGENT_DIR/CONTEXT.md"
    log "info" "Appended error to CONTEXT.md"
  fi

  # Write failure entry to HEARTBEAT.md
  if [[ -f "$AGENT_DIR/HEARTBEAT.md" ]]; then
    {
      echo ""
      echo "### $NOW Cycle Result"
      echo "- Step: parse-error"
      echo "- Outcome: failed"
      echo "- Duration: 0s"
      echo "- Summary: Agent output could not be parsed ($ERROR_MSG)"
    } >> "$AGENT_DIR/HEARTBEAT.md"
    log "info" "Appended failure entry to HEARTBEAT.md"
  fi

  exit 0
fi

# ---- Process each file update ----

UPDATE_COUNT=$(echo "$JSON_INPUT" | python3 -c '
import sys, json
data = json.load(sys.stdin)
print(len(data.get("updates", [])))
' 2>/dev/null || echo "parse_fail")

if [[ "$UPDATE_COUNT" == "parse_fail" ]]; then
  log "warn" "Could not parse updates array from JSON input -- skipping write-back"
  exit 0
fi

log "info" "Processing $UPDATE_COUNT file updates for agent $AGENT_ID"

export AGENT_DIR

echo "$JSON_INPUT" | python3 -c '
import sys, json, base64

data = json.load(sys.stdin)

for update in data.get("updates", []):
    filename = str(update.get("file", ""))
    content = update.get("content", "")
    if not isinstance(content, str):
        content = str(content)
    encoded = base64.b64encode(content.encode("utf-8")).decode("ascii")
    print(f"{filename}\t{encoded}")
' | {
  while IFS=$'\t' read -r current_file current_content_b64; do
    if [[ -z "$current_file" ]]; then
      log "warn" "Skipping update with empty filename"
      continue
    fi

    current_content="$(python3 - "$current_content_b64" <<'PY'
import sys, base64
raw = sys.argv[1]
print(base64.b64decode(raw.encode("ascii")).decode("utf-8"), end="")
PY
)"

    TARGET_FILE="$AGENT_DIR/$current_file"

    case "$current_file" in
      TASKS.md)
        if [[ "$current_content" == "NO_CHANGES" ]]; then
          log "info" "TASKS.md -- no changes"
        else
          echo "$current_content" > "$TARGET_FILE"
          log "info" "Wrote TASKS.md (overwrite) -- $(echo "$current_content" | wc -l | xargs) lines"
        fi
        ;;

      HEARTBEAT.md)
        if [[ -f "$TARGET_FILE" ]]; then
          {
            echo ""
            echo "$current_content"
          } >> "$TARGET_FILE"
        else
          echo "$current_content" > "$TARGET_FILE"
        fi
        log "info" "Appended to HEARTBEAT.md -- $(echo "$current_content" | wc -l | xargs) lines"
        ;;

      INBOX.md)
        if [[ "$current_content" == "NO_CHANGES" ]]; then
          log "info" "INBOX.md -- no changes"
        else
          echo "$current_content" > "$TARGET_FILE"
          log "info" "Wrote INBOX.md (overwrite) -- $(echo "$current_content" | wc -l | xargs) lines"
        fi
        ;;

      CONTEXT.md)
        if [[ "$current_content" == "NO_CHANGES" ]]; then
          log "info" "CONTEXT.md -- no changes"
        else
          if [[ -f "$TARGET_FILE" ]]; then
            {
              echo ""
              echo "$current_content"
            } >> "$TARGET_FILE"
          else
            echo "$current_content" > "$TARGET_FILE"
          fi
          log "info" "Appended to CONTEXT.md -- $(echo "$current_content" | wc -l | xargs) lines"
        fi
        ;;

      *)
        log "warn" "Unknown file update target: $current_file -- skipping"
        ;;
    esac
  done
}

log "info" "Write-back complete for agent $AGENT_ID"
