#!/usr/bin/env bash
# Thoughtseed Labs -- Canonical runtime root guard
#
# Usage:
#   ./scripts/runtime-root-guard.sh print
#   ./scripts/runtime-root-guard.sh check
#   ./scripts/runtime-root-guard.sh assert

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MARKER_FILE_DEFAULT="$REPO_ROOT/.thoughtseed/canonical-runtime-root.txt"
RUNTIME_ROOT_MARKER_FILE="${RUNTIME_ROOT_MARKER_FILE:-$MARKER_FILE_DEFAULT}"

normalize_path() {
  local path="$1"
  if [[ -d "$path" ]]; then
    (cd "$path" && pwd -P)
    return
  fi
  printf '%s\n' "$path"
}

current_root() {
  normalize_path "$REPO_ROOT"
}

canonical_runtime_root() {
  if [[ -n "${CANONICAL_RUNTIME_ROOT:-}" ]]; then
    normalize_path "$CANONICAL_RUNTIME_ROOT"
    return 0
  fi

  if [[ ! -f "$RUNTIME_ROOT_MARKER_FILE" ]]; then
    return 1
  fi

  local marker_value
  marker_value="$(head -n 1 "$RUNTIME_ROOT_MARKER_FILE" | tr -d '\r')"
  if [[ -z "$marker_value" ]]; then
    return 1
  fi

  normalize_path "$marker_value"
}

print_status() {
  local current
  current="$(current_root)"

  echo "current repo root: $current"
  echo "marker file: $RUNTIME_ROOT_MARKER_FILE"

  local canonical=""
  if ! canonical="$(canonical_runtime_root)"; then
    echo "canonical runtime root: missing"
    echo "status: missing"
    return 1
  fi

  echo "canonical runtime root: $canonical"
  if [[ "$current" == "$canonical" ]]; then
    echo "status: ok"
    return 0
  fi

  echo "status: mismatch"
  return 1
}

assert_status() {
  if ! print_status; then
    echo "runtime-root-guard: refusing to run outside canonical runtime root" >&2
    exit 1
  fi
}

case "${1:-check}" in
  print)
    print_status
    ;;
  check)
    print_status
    ;;
  assert)
    assert_status
    ;;
  help|*)
    cat <<'EOF'
Thoughtseed Labs runtime root guard

Usage: runtime-root-guard.sh {print|check|assert}

  print   Print current root, canonical runtime root, and status
  check   Print status and exit non-zero on missing/mismatch
  assert  Same as check, with refusal message for callers
EOF
    ;;
esac
