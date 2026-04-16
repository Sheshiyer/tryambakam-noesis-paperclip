#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

AGENT="$1"
AGENT_DIR="$REPO_ROOT/agents/$AGENT"
TODAY=$(date -u +%Y-%m-%d)
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Validate
if [[ ! -d "$AGENT_DIR" ]]; then
  echo "Error: Agent '$AGENT' not found at $AGENT_DIR" >&2
  exit 1
fi

# Read agent state files
TASKS_FILE="$AGENT_DIR/TASKS.md"
HEARTBEAT_FILE="$AGENT_DIR/HEARTBEAT.md"
INBOX_FILE="$AGENT_DIR/INBOX.md"

# Extract agent display name from IDENTITY.md (first # heading)
DISPLAY_NAME=$(head -5 "$AGENT_DIR/IDENTITY.md" | grep '^# ' | sed 's/^# //' | head -1)
[[ -z "$DISPLAY_NAME" ]] && DISPLAY_NAME="$AGENT"

# Parse completed items from TASKS.md (status: done with today's date or recent)
COMPLETED=""
if [[ -f "$TASKS_FILE" ]]; then
  # Look for items marked done (various formats)
  COMPLETED=$(grep -i -E '(done|completed|✅)' "$TASKS_FILE" 2>/dev/null | head -10 || true)
fi

# Parse upcoming items from TASKS.md (status: open or in-progress)
UPCOMING=""
if [[ -f "$TASKS_FILE" ]]; then
  UPCOMING=$(grep -i -E '(open|in.progress|scheduled|📋)' "$TASKS_FILE" 2>/dev/null | head -10 || true)
fi

# Parse blocked items from TASKS.md
BLOCKED=""
if [[ -f "$TASKS_FILE" ]]; then
  BLOCKED=$(grep -i -E '(blocked|🚫)' "$TASKS_FILE" 2>/dev/null | head -5 || true)
fi

# Parse today's heartbeat cycles
CYCLES_TODAY=0
OUTCOMES=""
if [[ -f "$HEARTBEAT_FILE" ]]; then
  CYCLES_TODAY=$(grep -c "$TODAY" "$HEARTBEAT_FILE" 2>/dev/null || echo "0")
  OUTCOMES=$(grep "$TODAY" "$HEARTBEAT_FILE" 2>/dev/null | tail -5 || true)
fi

# Count pending inbox items
PENDING_INBOX=0
if [[ -f "$INBOX_FILE" ]]; then
  PENDING_INBOX=$(sed -n '/^## Pending/,/^## /p' "$INBOX_FILE" | grep -c '^### ' 2>/dev/null || echo "0")
fi

# Generate standup markdown
cat <<STANDUP
# Standup — $DISPLAY_NAME — $TODAY

Generated: $NOW

## ✅ Completed Today

$(if [[ -n "$COMPLETED" ]]; then
  echo "$COMPLETED" | while IFS= read -r line; do echo "- $line"; done
else
  echo "_No completed items today._"
fi)

## 📋 Tomorrow / Next

$(if [[ -n "$UPCOMING" ]]; then
  echo "$UPCOMING" | while IFS= read -r line; do echo "- $line"; done
else
  echo "_No upcoming items scheduled._"
fi)

## 🚫 Blockers

$(if [[ -n "$BLOCKED" ]]; then
  echo "$BLOCKED" | while IFS= read -r line; do echo "- $line"; done
else
  echo "- None"
fi)

## 📊 Cycle Metrics

- Heartbeat cycles today: $CYCLES_TODAY
- Pending inbox items: $PENDING_INBOX
$(if [[ -n "$OUTCOMES" ]]; then
  echo ""
  echo "Recent outcomes:"
  echo "$OUTCOMES" | while IFS= read -r line; do echo "  $line"; done
fi)
STANDUP
