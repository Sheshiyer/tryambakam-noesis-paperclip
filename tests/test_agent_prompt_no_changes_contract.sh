#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/scripts" "$TMP_ROOT/agents/clawd" "$TMP_ROOT/.thoughtseed/teamforge/slices"
copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" agent-prompt-assembler.sh yaml-helpers.sh
chmod +x "$TMP_ROOT/scripts/agent-prompt-assembler.sh"

cat > "$TMP_ROOT/agents/clawd/MANIFEST.yaml" <<'YAML'
role: development
reports_to: jarvis
tier: 2
loop:
  max_step_timeout: "4m"
  on_blocked: log_and_skip
  on_failure: log_skip_continue
  retry_blocked_after: 3
YAML

cat > "$TMP_ROOT/agents/clawd/IDENTITY.md" <<'MD'
# CLAWD — Identity
MD

cat > "$TMP_ROOT/agents/clawd/AGENTS.md" <<'MD'
# CLAWD — Agent Instructions
MD

cat > "$TMP_ROOT/agents/clawd/SOUL.md" <<'MD'
# CLAWD — Soul
MD

cat > "$TMP_ROOT/agents/clawd/TASKS.md" <<'MD'
# CLAWD — Task Board

## Active Tasks

## Task Format

## Completed Tasks
MD

cat > "$TMP_ROOT/agents/clawd/INBOX.md" <<'MD'
# CLAWD — Inbox

## Pending

## Processed
MD

cat > "$TMP_ROOT/agents/clawd/CONTEXT.md" <<'MD'
# CLAWD — Context

## Known Pitfalls
MD

cat > "$TMP_ROOT/agents/clawd/HEARTBEAT.md" <<'MD'
# CLAWD — Heartbeat
MD

cat > "$TMP_ROOT/.thoughtseed/teamforge/slices/development.json" <<'JSON'
{
  "generatedAt": "2026-04-22T11:26:12Z",
  "overlapPolicy": "none",
  "items": []
}
JSON

cat > "$TMP_ROOT/.thoughtseed/teamforge/slices/clawd.json" <<'JSON'
{
  "generatedAt": "2026-04-22T11:26:12Z",
  "overlapPolicy": "none",
  "items": []
}
JSON

cat > "$TMP_ROOT/.thoughtseed/teamforge/slices/jarvis.json" <<'JSON'
{
  "generatedAt": "2026-04-22T11:26:12Z",
  "overlapPolicy": "none",
  "items": []
}
JSON

TEAMFORGE_SLICES_DIR="$TMP_ROOT/.thoughtseed/teamforge/slices" \
REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/agent-prompt-assembler.sh" clawd > "$TMP_ROOT/prompt.txt"

grep -q 'For any unchanged state file, emit "NO_CHANGES" in that file' "$TMP_ROOT/prompt.txt"
grep -q 'If TASKS.md did not change, write exactly: NO_CHANGES' "$TMP_ROOT/prompt.txt"
grep -q 'If INBOX.md did not change, write exactly: NO_CHANGES' "$TMP_ROOT/prompt.txt"
grep -q 'If nothing to add, write: NO_CHANGES' "$TMP_ROOT/prompt.txt"
grep -q 'TASKS.md update must contain the FULL file content when changed, or "NO_CHANGES" when unchanged.' "$TMP_ROOT/prompt.txt"
grep -q 'INBOX.md update must contain the FULL file content when changed, or "NO_CHANGES" when unchanged.' "$TMP_ROOT/prompt.txt"
