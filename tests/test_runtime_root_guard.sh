#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$("$REPO_ROOT/scripts/runtime-root-guard.sh" check 2>&1 || true)"

echo "$OUTPUT" | rg "canonical runtime root" >/dev/null
echo "$OUTPUT" | rg "mismatch|missing|ok" >/dev/null
