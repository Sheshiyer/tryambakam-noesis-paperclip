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
tier: "2"
reports_to: "jarvis"
role: "development"
loop:
  on_failure: "escalate_immediately"
  retry_blocked_after: "11"
  max_step_timeout: "9m"
  on_blocked: "retry_later"
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

cat > "$TMP_ROOT/.thoughtseed/teamforge/slices/clawd.json" <<'JSON'
{
  "generatedAt": "2026-04-22T12:21:54Z",
  "overlapPolicy": "none",
  "items": []
}
JSON

TEAMFORGE_SLICES_DIR="$TMP_ROOT/.thoughtseed/teamforge/slices" \
REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/agent-prompt-assembler.sh" clawd > "$TMP_ROOT/prompt.txt"

grep -q -- '- Tier: 2' "$TMP_ROOT/prompt.txt"
grep -q -- '- Reports to: jarvis' "$TMP_ROOT/prompt.txt"
grep -q -- '- Max step timeout: 9m' "$TMP_ROOT/prompt.txt"
grep -q -- '- On blocked: retry_later' "$TMP_ROOT/prompt.txt"
grep -q -- '- On failure: escalate_immediately' "$TMP_ROOT/prompt.txt"
grep -q -- '- Retry blocked after: 11 cycles' "$TMP_ROOT/prompt.txt"
