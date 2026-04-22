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

cat > "$TMP_ROOT/agents/clawd/CONTEXT.md" <<'MD'
# CLAWD — Context
MD

cat > "$TMP_ROOT/agents/clawd/HEARTBEAT.md" <<'MD'
# CLAWD — Heartbeat
MD

cat > "$TMP_ROOT/bad.json" <<'JSON'
{"updates":[
JSON

set +e
REPO_ROOT="$TMP_ROOT" "$TMP_ROOT/scripts/write-back.sh" clawd "$TMP_ROOT/bad.json" >/dev/null 2>"$TMP_ROOT/write-back.stderr"
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  echo "Expected malformed JSON input to be handled gracefully" >&2
  exit 1
fi

grep -q "invalid_json" "$TMP_ROOT/agents/clawd/CONTEXT.md"
grep -q "parse-error" "$TMP_ROOT/agents/clawd/HEARTBEAT.md"
grep -q "could not be parsed (invalid_json)" "$TMP_ROOT/agents/clawd/HEARTBEAT.md"
