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
original tasks
MD

cat > "$TMP_ROOT/agents/clawd/INBOX.md" <<'MD'
original inbox
MD

cat > "$TMP_ROOT/agents/clawd/HEARTBEAT.md" <<'MD'
original heartbeat
MD

cat > "$TMP_ROOT/agents/clawd/CONTEXT.md" <<'MD'
original context
MD

cat > "$TMP_ROOT/parsed-output.json" <<'JSON'
{
  "updates": [
    {
      "file": "TASKS.md",
      "content": "# CLAWD — Tasks\n\n## Active Tasks\n\n- line before marker\n- ===END_UPDATE_ENTRY===\n- line after marker\n- FILE:INBOX.md\n\n## Completed Tasks"
    },
    {
      "file": "INBOX.md",
      "content": "NO_CHANGES"
    }
  ]
}
JSON

REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/write-back.sh" clawd "$TMP_ROOT/parsed-output.json" >/dev/null

cat > "$TMP_ROOT/expected-tasks.md" <<'MD'
# CLAWD — Tasks

## Active Tasks

- line before marker
- ===END_UPDATE_ENTRY===
- line after marker
- FILE:INBOX.md

## Completed Tasks
MD

cmp -s "$TMP_ROOT/expected-tasks.md" "$TMP_ROOT/agents/clawd/TASKS.md"
grep -q '^original inbox$' "$TMP_ROOT/agents/clawd/INBOX.md"
