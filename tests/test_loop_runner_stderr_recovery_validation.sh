#!/usr/bin/env bash
set -euo pipefail

SOURCE_REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$SOURCE_REPO/tests/lib/fixture-helpers.sh"

setup_fixture() {
  local root="$1"
  mkdir -p "$root/scripts" "$root/agents/clawd" "$root/.thoughtseed" "$root/logs"

  copy_scripts_from_repo "$SOURCE_REPO" "$root/scripts" \
    loop-runner.sh \
    yaml-helpers.sh \
    agent-output-parser.sh \
    write-back.sh \
    heartbeat-writer.sh
  write_runtime_root_guard_stub "$root/scripts/runtime-root-guard.sh"

  cat > "$root/scripts/agent-prompt-assembler.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Prompt stub"
EOF

  cat > "$root/scripts/codex-stub.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output_file=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  if [[ "${args[$i]}" == "--output-last-message" ]] && (( i + 1 < ${#args[@]} )); then
    output_file="${args[$((i + 1))]}"
    break
  fi
done

if [[ -n "$output_file" ]]; then
  : > "$output_file"
fi

case "${CODEX_STUB_MODE:-valid}" in
  template)
    cat >&2 <<'BLOCK'
===THOUGHTSEED_OUTPUT_START===
---FILE_UPDATE: TASKS.md---
[If TASKS.md changed this cycle, write the COMPLETE updated TASKS.md content.
If TASKS.md did not change, write exactly: NO_CHANGES]
---END_FILE_UPDATE---
---FILE_UPDATE: HEARTBEAT.md---
### 2026-04-22T12:00:00Z Cycle Result
- Step: [step_id or "idle"]
- Outcome: [completed|blocked|failed|idle]
- Duration: [estimated seconds]
- Summary: [1 sentence of what happened]
---END_FILE_UPDATE---
---FILE_UPDATE: INBOX.md---
[If INBOX.md changed this cycle, write the COMPLETE updated INBOX.md content.
If INBOX.md did not change, write exactly: NO_CHANGES]
---END_FILE_UPDATE---
---FILE_UPDATE: CONTEXT.md---
[ONLY if you have new pitfalls or learnings to add.
If nothing to add, write: NO_CHANGES]
---END_FILE_UPDATE---
===THOUGHTSEED_OUTPUT_END===
BLOCK
    ;;
  valid)
    cat >&2 <<'BLOCK'
===THOUGHTSEED_OUTPUT_START===
---FILE_UPDATE: TASKS.md---
# CLAWD — Tasks

## Active Tasks

_No active tasks._

## Task Format

format

## Completed Tasks
---END_FILE_UPDATE---
---FILE_UPDATE: HEARTBEAT.md---
### 2026-04-22T12:00:00Z Cycle Result
- Step: idle
- Outcome: idle
- Duration: 1s
- Summary: recovered from stderr
---END_FILE_UPDATE---
---FILE_UPDATE: INBOX.md---
NO_CHANGES
---END_FILE_UPDATE---
---FILE_UPDATE: CONTEXT.md---
NO_CHANGES
---END_FILE_UPDATE---
===THOUGHTSEED_OUTPUT_END===
BLOCK
    ;;
esac
EOF

  chmod +x "$root/scripts/"*.sh

  cat > "$root/manifest.yaml" <<'YAML'
org:
  paperclip:
    issues_to_inbox: false
YAML

  cat > "$root/agents/clawd/MANIFEST.yaml" <<'YAML'
role: development
tier: 2
loop:
  max_step_timeout: "5s"
YAML

  cat > "$root/agents/clawd/TASKS.md" <<'MD'
# CLAWD — Tasks

## Active Tasks

- ORIGINAL

## Task Format

format

## Completed Tasks
MD

  cat > "$root/agents/clawd/INBOX.md" <<'MD'
# CLAWD — Inbox

## Pending

## Processed
MD

  cat > "$root/agents/clawd/HEARTBEAT.md" <<'MD'
# CLAWD — Heartbeat
MD

  cat > "$root/agents/clawd/CONTEXT.md" <<'MD'
# CLAWD — Context

## Known Pitfalls
MD
}

run_once() {
  local root="$1"
  local mode="$2"
  REPO_ROOT="$root" \
  CODEX_BIN="$root/scripts/codex-stub.sh" \
  CODEX_STUB_MODE="$mode" \
  LOOP_PAPERCLIP_CYCLE_ENABLED=false \
  "$root/scripts/loop-runner.sh" run --once --agent clawd >/dev/null
}

tmp_template="$(mktemp -d)"
tmp_valid="$(mktemp -d)"
trap 'rm -rf "$tmp_template" "$tmp_valid"' EXIT

setup_fixture "$tmp_template"
setup_fixture "$tmp_valid"

run_once "$tmp_template" template
grep -q -- "- ORIGINAL" "$tmp_template/agents/clawd/TASKS.md"
grep -q "empty_output" "$tmp_template/agents/clawd/CONTEXT.md"

run_once "$tmp_valid" valid
grep -q "_No active tasks._" "$tmp_valid/agents/clawd/TASKS.md"
grep -q "recovered from stderr" "$tmp_valid/agents/clawd/HEARTBEAT.md"
