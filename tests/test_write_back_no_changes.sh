#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

mkdir -p "$TMP_ROOT/scripts" "$TMP_ROOT/agents/clawd"
copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" write-back.sh
chmod +x "$TMP_ROOT/scripts/write-back.sh"

cat > "$TMP_ROOT/agents/clawd/TASKS.md" <<'MD'
# CLAWD — Task Board

## Active Tasks

1. [high][open] test task

## Task Format

Status values: open, in-progress, blocked, done, failed.

## Completed Tasks
MD

cat > "$TMP_ROOT/agents/clawd/INBOX.md" <<'MD'
# CLAWD — Inbox

## Pending

- 2026-04-22T11:00:00Z [high] test pending item

## Processed
MD

cat > "$TMP_ROOT/agents/clawd/HEARTBEAT.md" <<'MD'
# CLAWD — Heartbeat
MD

cat > "$TMP_ROOT/agents/clawd/CONTEXT.md" <<'MD'
# CLAWD — Context

## Known Pitfalls
MD

cat > "$TMP_ROOT/parsed-output.json" <<'JSON'
{
  "updates": [
    {
      "file": "TASKS.md",
      "content": "NO_CHANGES"
    },
    {
      "file": "HEARTBEAT.md",
      "content": "### 2026-04-22T11:23:53Z Cycle Result\n- Step: idle\n- Outcome: idle\n- Duration: 14s\n- Summary: No actionable tasks."
    },
    {
      "file": "INBOX.md",
      "content": "NO_CHANGES"
    },
    {
      "file": "CONTEXT.md",
      "content": "NO_CHANGES"
    }
  ]
}
JSON

tasks_sha_before="$(shasum -a 256 "$TMP_ROOT/agents/clawd/TASKS.md" | awk '{print $1}')"
inbox_sha_before="$(shasum -a 256 "$TMP_ROOT/agents/clawd/INBOX.md" | awk '{print $1}')"
context_sha_before="$(shasum -a 256 "$TMP_ROOT/agents/clawd/CONTEXT.md" | awk '{print $1}')"

REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/write-back.sh" clawd "$TMP_ROOT/parsed-output.json" \
  >/dev/null 2>"$TMP_ROOT/write-back.stderr"

tasks_sha_after="$(shasum -a 256 "$TMP_ROOT/agents/clawd/TASKS.md" | awk '{print $1}')"
inbox_sha_after="$(shasum -a 256 "$TMP_ROOT/agents/clawd/INBOX.md" | awk '{print $1}')"
context_sha_after="$(shasum -a 256 "$TMP_ROOT/agents/clawd/CONTEXT.md" | awk '{print $1}')"

[[ "$tasks_sha_before" == "$tasks_sha_after" ]]
[[ "$inbox_sha_before" == "$inbox_sha_after" ]]
[[ "$context_sha_before" == "$context_sha_after" ]]

grep -q "TASKS.md -- no changes" "$TMP_ROOT/write-back.stderr"
grep -q "INBOX.md -- no changes" "$TMP_ROOT/write-back.stderr"
grep -q "CONTEXT.md -- no changes" "$TMP_ROOT/write-back.stderr"

grep -q "### 2026-04-22T11:23:53Z Cycle Result" "$TMP_ROOT/agents/clawd/HEARTBEAT.md"
grep -q -- "- Outcome: idle" "$TMP_ROOT/agents/clawd/HEARTBEAT.md"
