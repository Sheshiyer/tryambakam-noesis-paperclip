#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/scripts/yaml-helpers.sh"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

cat > "$TMP_ROOT/sample.yaml" <<'YAML'
org:
  paperclip:
    sync:
      issues_to_inbox: "false"
      heartbeat_reporting: true # inline comment should be removed
      keep_hash: "value # should be preserved"
  signal_lane:
    cooldown_minutes: "42"
plain_value: unquoted
quoted_single: 'single-quoted'
with_comment: bare-value # trailing comment should be removed
nested:
  child:
    key: "  spaced value  "
YAML

[[ "$(yaml_path_get "$TMP_ROOT/sample.yaml" "org.paperclip.sync.issues_to_inbox")" == "false" ]]
[[ "$(yaml_path_get "$TMP_ROOT/sample.yaml" "org.paperclip.sync.heartbeat_reporting")" == "true" ]]
[[ "$(yaml_path_get "$TMP_ROOT/sample.yaml" "org.paperclip.sync.keep_hash")" == "value # should be preserved" ]]
[[ "$(yaml_path_get "$TMP_ROOT/sample.yaml" "org.signal_lane.cooldown_minutes")" == "42" ]]
[[ "$(yaml_path_get "$TMP_ROOT/sample.yaml" "plain_value")" == "unquoted" ]]
[[ "$(yaml_path_get "$TMP_ROOT/sample.yaml" "quoted_single")" == "single-quoted" ]]
[[ "$(yaml_path_get "$TMP_ROOT/sample.yaml" "with_comment")" == "bare-value" ]]
[[ "$(yaml_path_get "$TMP_ROOT/sample.yaml" "nested.child.key")" == "  spaced value  " ]]
[[ "$(yaml_path_get "$TMP_ROOT/sample.yaml" "missing.path")" == "" ]]

yaml_is_false "false"
yaml_is_false "NO"
yaml_is_false "0"
yaml_is_false "  false  "
yaml_is_false "  nO  "
yaml_is_false " 0 "

yaml_is_true "true"
yaml_is_true "YES"
yaml_is_true "1"
yaml_is_true "  true  "
yaml_is_true "  yEs "
yaml_is_true " 1 "
