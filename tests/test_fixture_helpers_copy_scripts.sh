#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

set +e
usage_output="$(
  copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" 2>&1
)"
usage_status=$?
set -e

if [[ "$usage_status" -eq 0 ]]; then
  echo "Expected usage failure when no script names are provided" >&2
  exit 1
fi

grep -q "Usage: copy_scripts_from_repo" <<<"$usage_output"

set +e
missing_dir_output="$(
  copy_scripts_from_repo "$TMP_ROOT/missing-repo" "$TMP_ROOT/scripts" write-back.sh 2>&1
)"
missing_dir_status=$?
set -e

if [[ "$missing_dir_status" -eq 0 ]]; then
  echo "Expected source directory validation failure for missing repo scripts dir" >&2
  exit 1
fi

grep -q "Missing source scripts directory:" <<<"$missing_dir_output"

copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" write-back.sh loop-runner.sh

test -f "$TMP_ROOT/scripts/write-back.sh"
test -f "$TMP_ROOT/scripts/loop-runner.sh"

set +e
missing_output="$(
  copy_scripts_from_repo "$SOURCE_REPO" "$TMP_ROOT/scripts" missing-script.sh 2>&1
)"
missing_status=$?
set -e

if [[ "$missing_status" -eq 0 ]]; then
  echo "Expected copy_scripts_from_repo to fail for missing scripts" >&2
  exit 1
fi

grep -q "Missing source script:" <<<"$missing_output"

stub_path="$TMP_ROOT/runtime-root-guard.sh"
write_runtime_root_guard_stub "$stub_path"
test -x "$stub_path"

"$stub_path" assert
"$stub_path" check
"$stub_path" anything_else

set +e
chmod_usage_output="$(
  make_scripts_executable "$TMP_ROOT/scripts" 2>&1
)"
chmod_usage_status=$?
set -e

if [[ "$chmod_usage_status" -eq 0 ]]; then
  echo "Expected make_scripts_executable usage failure when no script names are provided" >&2
  exit 1
fi

grep -q "Usage: make_scripts_executable" <<<"$chmod_usage_output"

make_scripts_executable "$TMP_ROOT/scripts" write-back.sh loop-runner.sh

set +e
chmod_missing_output="$(
  make_scripts_executable "$TMP_ROOT/scripts" missing-target.sh 2>&1
)"
chmod_missing_status=$?
set -e

if [[ "$chmod_missing_status" -eq 0 ]]; then
  echo "Expected make_scripts_executable to fail for missing target script" >&2
  exit 1
fi

grep -q "Missing target script:" <<<"$chmod_missing_output"
