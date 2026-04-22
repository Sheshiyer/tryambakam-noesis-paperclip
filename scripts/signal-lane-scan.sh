#!/usr/bin/env bash
# Thoughtseed Labs -- Reflective signal lane scanner
#
# Usage:
#   ./scripts/signal-lane-scan.sh init
#   ./scripts/signal-lane-scan.sh scan [--fixture-dir DIR]

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
VAULT_ROOT="${VAULT_ROOT:-$(cd "$REPO_ROOT/../../.." && pwd)}"
RUNTIME_ROOT_GUARD="$REPO_ROOT/scripts/runtime-root-guard.sh"
STATE_DIR="$REPO_ROOT/.thoughtseed/signal-lane"
STATE_FILE="$STATE_DIR/state.json"
EVENTS_FILE="$STATE_DIR/events.jsonl"
BOARD_DIR="$REPO_ROOT/vault/leadership/signal-lane"
BOARD_FILE="$BOARD_DIR/signal-board.md"
TEMPLATE_FILE="$REPO_ROOT/templates/signal-board.md"
FIXTURE_STATE="$REPO_ROOT/tests/fixtures/signal-lane/minimal-state.json"
TASK_REGISTRY="$REPO_ROOT/scripts/task-registry.sh"
DISPATCH_TASK="$REPO_ROOT/scripts/dispatch-task.sh"
FIXTURE_DIR=""
SIGNAL_LANE_COOLDOWN_MINUTES="${SIGNAL_LANE_COOLDOWN_MINUTES:-180}"

assert_runtime_root() {
  if [[ ! -x "$RUNTIME_ROOT_GUARD" ]]; then
    echo "Runtime root guard missing or not executable: $RUNTIME_ROOT_GUARD" >&2
    exit 1
  fi
  "$RUNTIME_ROOT_GUARD" assert >/dev/null
}

ensure_layout() {
  mkdir -p "$STATE_DIR" "$BOARD_DIR"
  if [[ ! -f "$EVENTS_FILE" ]]; then
    : > "$EVENTS_FILE"
  fi
}

require_exec() {
  local path="$1"
  if [[ ! -x "$path" ]]; then
    echo "Required executable missing: $path" >&2
    exit 1
  fi
}

string_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]]
}

file_line_count_contains() {
  local file="$1"
  local needle="$2"

  if [[ ! -f "$file" ]]; then
    printf '0\n'
    return
  fi

  awk -v needle="$needle" 'index($0, needle) { count++ } END { print count + 0 }' "$file" 2>/dev/null || printf '0\n'
}

write_state() {
  if [[ -f "$FIXTURE_STATE" ]]; then
    cp "$FIXTURE_STATE" "$STATE_FILE"
    return
  fi

  cat > "$STATE_FILE" <<'JSON'
{
  "schemaVersion": "signal-lane/v1",
  "metadata": {
    "generatedAt": null,
    "repoRoot": null,
    "vaultRoot": null
  },
  "signals": [],
  "cooldowns": {},
  "outcomes": {
    "watching": 0,
    "candidate": 0,
    "experiment": 0,
    "ready": 0,
    "blocked": 0,
    "ghost": 0,
    "stale": 0,
    "resolved": 0
  }
}
JSON
}

write_board() {
  if [[ -f "$TEMPLATE_FILE" ]]; then
    cp "$TEMPLATE_FILE" "$BOARD_FILE"
    return
  fi

  cat > "$BOARD_FILE" <<'MD'
# Signal Board

## Runtime Health

- Pending initialization.

## Ready Intents

- None yet.

## Candidate Intents

- None yet.

## Ghosts / Stale / Blocked

- None yet.
MD
}

iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

iso_to_epoch() {
  local ts="$1"
  python3 -c '
import datetime
import sys

raw = sys.argv[1].strip()
if not raw:
    print(0)
    raise SystemExit(0)

try:
    dt = datetime.datetime.fromisoformat(raw.replace("Z", "+00:00"))
    print(int(dt.timestamp()))
except Exception:
    print(0)
' "$ts"
}

resolve_input_file() {
  local fixture_name="$1"
  local live_path="$2"

  if [[ -n "$FIXTURE_DIR" && -f "$FIXTURE_DIR/$fixture_name" ]]; then
    printf '%s\n' "$FIXTURE_DIR/$fixture_name"
    return
  fi

  printf '%s\n' "$live_path"
}

append_signal() {
  local signals_file="$1"
  local signal_type="$2"
  local state="$3"
  local score="$4"
  local owner="$5"
  local recommended_action="$6"
  local summary="$7"
  local source_ref="$8"
  local now="$9"
  local sync_key="signal:${signal_type}"

  jq -cn \
    --arg sync_key "$sync_key" \
    --arg signal_type "$signal_type" \
    --arg state "$state" \
    --argjson score "$score" \
    --arg owner "$owner" \
    --arg recommended_action "$recommended_action" \
    --arg summary "$summary" \
    --arg source_ref "$source_ref" \
    --arg now "$now" \
    '{
      sync_key: $sync_key,
      signal_type: $signal_type,
      state: $state,
      score: $score,
      signal_count: 1,
      signal_types: [$signal_type],
      first_seen_at: $now,
      last_seen_at: $now,
      cooldown_until: null,
      owner: $owner,
      source_refs: [$source_ref],
      recommended_action: $recommended_action,
      summary: $summary
    }' >> "$signals_file"
}

signal_title() {
  local signal_type="$1"
  case "$signal_type" in
    runtime_root_drift)
      printf '%s\n' "Build intent: normalize Paperclip runtime root"
      ;;
    teamforge_feed_down)
      printf '%s\n' "Build intent: restore TeamForge feed ingestion"
      ;;
    meru_stale_run)
      printf '%s\n' "Review intent: evaluate stale Meru handoff"
      ;;
    skill_mirror_drift)
      printf '%s\n' "Review intent: reconcile skill mirror drift"
      ;;
    task_registry_drift)
      printf '%s\n' "Review intent: reconcile task registry drift"
      ;;
    loop_runner_idle_storm)
      printf '%s\n' "Review intent: inspect loop-runner idle storm"
      ;;
    *)
      printf '%s\n' "Review intent: ${signal_type}"
      ;;
  esac
}

signal_tag() {
  local signal_type="$1"
  case "$signal_type" in
    runtime_root_drift|teamforge_feed_down)
      printf '%s\n' "ops"
      ;;
    skill_mirror_drift)
      printf '%s\n' "research"
      ;;
    task_registry_drift)
      printf '%s\n' "qa"
      ;;
    meru_stale_run|loop_runner_idle_storm)
      printf '%s\n' "content"
      ;;
    *)
      printf '%s\n' "ops"
      ;;
  esac
}

signal_priority() {
  local signal_type="$1"
  case "$signal_type" in
    runtime_root_drift|teamforge_feed_down)
      printf '%s\n' "high"
      ;;
    *)
      printf '%s\n' "medium"
      ;;
  esac
}

signal_route_owner() {
  local signal_type="$1"
  case "$signal_type" in
    runtime_root_drift|teamforge_feed_down)
      printf '%s\n' "clawd"
      ;;
    skill_mirror_drift)
      printf '%s\n' "atlas"
      ;;
    task_registry_drift)
      printf '%s\n' "sentinel"
      ;;
    meru_stale_run|loop_runner_idle_storm)
      printf '%s\n' "sage"
      ;;
    *)
      printf '%s\n' "jarvis"
      ;;
  esac
}

signal_source() {
  local signal_state="$1"
  if [[ "$signal_state" == "ready" ]]; then
    printf '%s\n' "build-intent"
    return
  fi
  printf '%s\n' "review-intent"
}

is_cooldown_active() {
  local sync_key="$1"
  local now_epoch="$2"
  local cooldown_value cooldown_epoch

  cooldown_value="$(jq -r --arg sync_key "$sync_key" '.cooldowns[$sync_key] // ""' "$STATE_FILE")"
  if [[ -z "$cooldown_value" ]]; then
    return 1
  fi

  cooldown_epoch="$(iso_to_epoch "$cooldown_value")"
  if [[ "$cooldown_epoch" -gt "$now_epoch" ]]; then
    return 0
  fi

  return 1
}

set_cooldown() {
  local sync_key="$1"
  local now_epoch="$2"
  local cooldown_epoch cooldown_at tmp_file

  cooldown_epoch=$(( now_epoch + (SIGNAL_LANE_COOLDOWN_MINUTES * 60) ))
  cooldown_at="$(python3 - <<'PY' "$cooldown_epoch"
import datetime
import sys

epoch = int(sys.argv[1])
print(datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"

  tmp_file="${STATE_FILE}.tmp"
  jq --arg sync_key "$sync_key" --arg cooldown_at "$cooldown_at" '
    .cooldowns[$sync_key] = $cooldown_at
    | .signals |= map(if .sync_key == $sync_key then .cooldown_until = $cooldown_at else . end)
  ' "$STATE_FILE" > "$tmp_file"
  mv "$tmp_file" "$STATE_FILE"
}

render_board() {
  local now="$1"
  local runtime_items ready_items candidate_items stale_items

  runtime_items="$(jq -r '
    [.signals[]? | select(.signal_type == "runtime_root_drift" or .signal_type == "teamforge_feed_down" or .signal_type == "loop_runner_idle_storm")
     | "- [" + .state + "|" + (.score|tostring) + "] " + .signal_type + " -> " + .owner + " :: " + .summary]
    | if length == 0 then "- None." else .[] end
  ' "$STATE_FILE")"

  ready_items="$(jq -r '
    [.signals[]? | select(.state == "ready")
     | "- [" + (.score|tostring) + "] " + .signal_type + " -> " + .owner + " :: " + .recommended_action]
    | if length == 0 then "- None yet." else .[] end
  ' "$STATE_FILE")"

  candidate_items="$(jq -r '
    [.signals[]? | select(.state == "candidate" or .state == "watching" or .state == "experiment")
     | "- [" + .state + "|" + (.score|tostring) + "] " + .signal_type + " -> " + .owner + " :: " + .recommended_action]
    | if length == 0 then "- None yet." else .[] end
  ' "$STATE_FILE")"

  stale_items="$(jq -r '
    [.signals[]? | select(.state == "stale" or .state == "ghost" or .state == "blocked")
     | "- [" + .state + "|" + (.score|tostring) + "] " + .signal_type + " -> " + .owner + " :: " + .summary]
    | if length == 0 then "- None yet." else .[] end
  ' "$STATE_FILE")"

  cat > "$BOARD_FILE" <<EOF
# Signal Board

Generated: $now

## Runtime Health

$runtime_items

## Ready Intents

$ready_items

## Candidate Intents

$candidate_items

## Ghosts / Stale / Blocked

$stale_items
EOF
}

scan_signal_lane() {
  assert_runtime_root
  ensure_layout

  local now current_epoch
  now="$(iso_now)"
  current_epoch="$(iso_to_epoch "$now")"

  local signals_file
  signals_file="$(mktemp)"

  local runtime_status_file runtime_output
  runtime_status_file="$(resolve_input_file "runtime-root-status.txt" "$RUNTIME_ROOT_GUARD")"
  if [[ -n "$FIXTURE_DIR" && -f "$runtime_status_file" ]]; then
    runtime_output="$(cat "$runtime_status_file")"
  else
    runtime_output="$("$RUNTIME_ROOT_GUARD" check 2>&1 || true)"
  fi
  if string_contains "$runtime_output" "status: mismatch"; then
    append_signal "$signals_file" "runtime_root_drift" "ready" 95 "clawd" \
      "Normalize the Paperclip runtime root and reinstall host supervision from the canonical repo." \
      "Runtime root check reported a canonical-root mismatch." \
      "$runtime_status_file" \
      "$now"
  fi

  local teamforge_file teamforge_failures teamforge_success teamforge_error
  teamforge_file="$(resolve_input_file "teamforge-sync-state.json" "$REPO_ROOT/.thoughtseed/teamforge/sync-state.json")"
  if [[ -f "$teamforge_file" ]]; then
    teamforge_failures="$(jq -r '.runs.failed // 0' "$teamforge_file")"
    teamforge_success="$(jq -r '.runs.success // 0' "$teamforge_file")"
    teamforge_error="$(jq -r '.lastError // ""' "$teamforge_file")"
    if [[ "$teamforge_failures" -gt 0 && "$teamforge_success" -eq 0 ]] || [[ -n "$teamforge_error" ]]; then
      append_signal "$signals_file" "teamforge_feed_down" "ready" 88 "clawd" \
        "Restore TeamForge export resolution so slices materialize again before the next Paperclip cycle." \
        "TeamForge sync has recorded failures without successful feed ingestion." \
        "$teamforge_file" \
        "$now"
    fi
  fi

  local meru_file meru_generated_at meru_generated_epoch meru_openclaw meru_paperclip meru_candidates
  meru_file="$(resolve_input_file "meru-latest-run.json" "$VAULT_ROOT/_System/memory/archetypal-candidates/latest-run.json")"
  if [[ -f "$meru_file" ]]; then
    meru_generated_at="$(jq -r '.generated_at // .generatedAt // ""' "$meru_file")"
    meru_generated_epoch="$(iso_to_epoch "$meru_generated_at")"
    meru_openclaw="$(jq -r '.openclaw_task_count // 0' "$meru_file")"
    meru_paperclip="$(jq -r '.paperclip_task_count // 0' "$meru_file")"
    meru_candidates="$(jq -r '[.seeds[]? | .candidate_count // 0] | add // 0' "$meru_file")"
    if [[ "$meru_generated_epoch" -gt 0 ]]; then
      local meru_age=$(( current_epoch - meru_generated_epoch ))
      if (( meru_age > 86400 )) && [[ "$meru_candidates" -eq 0 ]] && [[ "$meru_openclaw" -eq 0 ]] && [[ "$meru_paperclip" -eq 0 ]]; then
        append_signal "$signals_file" "meru_stale_run" "candidate" 71 "sage" \
          "Review stale Meru handoff surfaces after runtime-root and TeamForge repair, then decide whether to restage candidates." \
          "Latest Meru candidate run is stale and produced no downstream tasks." \
          "$meru_file" \
          "$now"
      fi
    fi
  fi

  local skill_diff_file skill_diff_count
  skill_diff_file="$(resolve_input_file "skill-diff.json" "$VAULT_ROOT/.claude/skills")"
  if [[ -n "$FIXTURE_DIR" && -f "$skill_diff_file" ]]; then
    skill_diff_count="$(jq -r '.differing_skill_count // 0' "$skill_diff_file")"
  else
    local diff_count=0
    if [[ -d "$VAULT_ROOT/.claude/skills" && -d "$VAULT_ROOT/.agents/skills" ]]; then
      diff_count="$( (diff -rq "$VAULT_ROOT/.claude/skills" "$VAULT_ROOT/.agents/skills" 2>/dev/null || true) | wc -l | tr -d ' ' )"
    fi
    skill_diff_count="${diff_count:-0}"
  fi
  if [[ "${skill_diff_count:-0}" -gt 0 ]]; then
    append_signal "$signals_file" "skill_mirror_drift" "candidate" 68 "atlas" \
      "Review .claude/skills versus .agents/skills and define a generated mirror or single canonical surface." \
      "Skill mirror drift is present between the canonical and mirrored skill surfaces." \
      "$skill_diff_file" \
      "$now"
  fi

  local registry_file registry_pending registry_updated_at registry_updated_epoch
  registry_file="$(resolve_input_file "task-registry.json" "$REPO_ROOT/.thoughtseed/task-registry.json")"
  if [[ -f "$registry_file" ]]; then
    registry_pending="$(jq -r '.metadata.pending // 0' "$registry_file")"
    registry_updated_at="$(jq -r '.metadata.last_updated // ""' "$registry_file")"
    registry_updated_epoch="$(iso_to_epoch "$registry_updated_at")"
    if [[ "$registry_updated_epoch" -gt 0 ]]; then
      local registry_age=$(( current_epoch - registry_updated_epoch ))
      if (( registry_age > 86400 )) && [[ "$registry_pending" -gt 0 ]]; then
        append_signal "$signals_file" "task_registry_drift" "candidate" 64 "sentinel" \
          "Reconcile task-registry state against current agent task files after root normalization." \
          "Pending tasks are stale relative to the registry's last update timestamp." \
          "$registry_file" \
          "$now"
      fi
    fi
  fi

  local loop_log idle_count teamforge_warning_count
  loop_log="$(resolve_input_file "loop-runner.log" "$REPO_ROOT/logs/loop-runner.log")"
  if [[ -f "$loop_log" ]]; then
    idle_count="$(file_line_count_contains "$loop_log" "Step: idle")"
    teamforge_warning_count="$(file_line_count_contains "$loop_log" "No TeamForge feed slices found")"
    if [[ "$idle_count" -ge 3 ]] || [[ "$teamforge_warning_count" -gt 0 ]]; then
      append_signal "$signals_file" "loop_runner_idle_storm" "watching" 52 "sage" \
        "Keep watching loop-runner idle storms until the TeamForge and runtime-root repairs land." \
        "Loop runner is spending cycles idling instead of advancing work." \
        "$loop_log" \
        "$now"
    fi
  fi

  jq -n \
    --arg now "$now" \
    --arg repo_root "$REPO_ROOT" \
    --arg vault_root "$VAULT_ROOT" \
    --slurpfile signals "$signals_file" \
    '{
      schemaVersion: "signal-lane/v1",
      metadata: {
        generatedAt: $now,
        repoRoot: $repo_root,
        vaultRoot: $vault_root
      },
      signals: ($signals // []),
      cooldowns: {},
      outcomes: {
        watching: ([($signals // [])[] | select(.state == "watching")] | length),
        candidate: ([($signals // [])[] | select(.state == "candidate")] | length),
        experiment: ([($signals // [])[] | select(.state == "experiment")] | length),
        ready: ([($signals // [])[] | select(.state == "ready")] | length),
        blocked: ([($signals // [])[] | select(.state == "blocked")] | length),
        ghost: ([($signals // [])[] | select(.state == "ghost")] | length),
        stale: ([($signals // [])[] | select(.state == "stale")] | length),
        resolved: ([($signals // [])[] | select(.state == "resolved")] | length)
      }
    }' > "$STATE_FILE"

  render_board "$now"
  rm -f "$signals_file"
}

dispatch_signal_lane() {
  assert_runtime_root
  ensure_layout
  require_exec "$TASK_REGISTRY"
  require_exec "$DISPATCH_TASK"

  if [[ ! -f "$STATE_FILE" ]]; then
    echo "Signal lane state not initialized: $STATE_FILE" >&2
    exit 1
  fi

  local now now_epoch
  now="$(iso_now)"
  now_epoch="$(iso_to_epoch "$now")"

  local signals_payload
  signals_payload="$(jq -c '.signals[] | select(.state == "ready" or .state == "candidate")' "$STATE_FILE")"
  if [[ -z "$signals_payload" ]]; then
    return 0
  fi

  while IFS= read -r signal; do
    [[ -n "$signal" ]] || continue

    local sync_key signal_type signal_state owner source_ref summary recommended_action active_count
    sync_key="$(echo "$signal" | jq -r '.sync_key')"
    signal_type="$(echo "$signal" | jq -r '.signal_type')"
    signal_state="$(echo "$signal" | jq -r '.state')"
    owner="$(echo "$signal" | jq -r '.owner // empty')"
    source_ref="$(echo "$signal" | jq -r '.source_refs[0] // empty')"
    summary="$(echo "$signal" | jq -r '.summary // empty')"
    recommended_action="$(echo "$signal" | jq -r '.recommended_action // empty')"

    if [[ -z "$owner" ]]; then
      owner="$(signal_route_owner "$signal_type")"
    fi

    if is_cooldown_active "$sync_key" "$now_epoch"; then
      continue
    fi

    active_count="$("$TASK_REGISTRY" find-active-by-sync-key "$sync_key" | jq 'length')"
    if [[ "$active_count" -gt 0 ]]; then
      continue
    fi

    "$DISPATCH_TASK" \
      "$(signal_title "$signal_type")" \
      --tag "$(signal_tag "$signal_type")" \
      --priority "$(signal_priority "$signal_type")" \
      --source "$(signal_source "$signal_state")" \
      --agent "$owner" \
      --sync-key "$sync_key" \
      --source-ref "$source_ref" \
      --details "$summary"$'\n'"$recommended_action" \
      --score-rationale "$signal_type" >/dev/null

    set_cooldown "$sync_key" "$now_epoch"
  done <<< "$signals_payload"

  render_board "$(iso_now)"
}

init_signal_lane() {
  assert_runtime_root
  ensure_layout
  write_state
  write_board
}

case "${1:-help}" in
  init)
    init_signal_lane
    ;;
  scan)
    shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --fixture-dir)
          FIXTURE_DIR="$2"
          shift 2
          ;;
        *)
          echo "Unknown argument: $1" >&2
          exit 1
          ;;
      esac
    done
    scan_signal_lane
    ;;
  dispatch)
    shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --fixture-dir)
          FIXTURE_DIR="$2"
          shift 2
          ;;
        *)
          echo "Unknown argument: $1" >&2
          exit 1
          ;;
      esac
    done
    dispatch_signal_lane
    ;;
  help|*)
    cat <<'EOF'
Thoughtseed Labs signal lane scanner

Usage: signal-lane-scan.sh {init|scan [--fixture-dir DIR]|dispatch}
EOF
    ;;
esac
