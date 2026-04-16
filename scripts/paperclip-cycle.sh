#!/usr/bin/env bash
# Thoughtseed Labs -- Paperclip Cycle Runner
# Runs one maintenance cycle in a deterministic order:
# 1) sync TeamForge operational feed into local projections/slices
# 2) sync unresolved issues from Paperclip (with TeamForge enrichment)
# 3) reconcile local registry + inbox state
# 4) optionally report heartbeats back to Paperclip
#
# Usage:
#   ./scripts/paperclip-cycle.sh
#   ./scripts/paperclip-cycle.sh --reconcile-dry-run
#   ./scripts/paperclip-cycle.sh --with-heartbeats

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SYNC_SCRIPT="$REPO_ROOT/scripts/paperclip-sync.sh"
RECON_SCRIPT="$REPO_ROOT/scripts/paperclip-reconcile-local.sh"
TEAMFORGE_SYNC_SCRIPT="$REPO_ROOT/scripts/teamforge-sync.sh"
LOCK_DIR="${PAPERCLIP_CYCLE_LOCK_DIR:-/tmp/thoughtseed-paperclip-cycle.lock}"
LOCK_PID_FILE="$LOCK_DIR/pid"

WITH_HEARTBEATS=false
RECON_DRY_RUN=false
WITH_TEAMFORGE=true
TEAMFORGE_DRY_RUN=false

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [paperclip-cycle] [$level] $*" >&2
}

usage() {
  cat <<'USAGE'
Thoughtseed Labs Paperclip Cycle Runner

Usage:
  paperclip-cycle.sh [--with-heartbeats] [--reconcile-dry-run] [--without-teamforge] [--teamforge-dry-run]

Options:
  --with-heartbeats    Also run `paperclip-sync.sh sync-heartbeats`
  --reconcile-dry-run  Run reconciliation in dry-run mode
  --without-teamforge  Skip TeamForge feed sync for this cycle
  --teamforge-dry-run  Run TeamForge feed sync in dry-run mode (no cursor mutation, no dispatch)
  -h, --help           Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-heartbeats)
      WITH_HEARTBEATS=true
      shift
      ;;
    --reconcile-dry-run)
      RECON_DRY_RUN=true
      shift
      ;;
    --without-teamforge)
      WITH_TEAMFORGE=false
      shift
      ;;
    --teamforge-dry-run)
      TEAMFORGE_DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -x "$SYNC_SCRIPT" ]]; then
  echo "ERROR: Missing executable sync script at $SYNC_SCRIPT" >&2
  exit 1
fi

if [[ ! -x "$RECON_SCRIPT" ]]; then
  echo "ERROR: Missing executable reconcile script at $RECON_SCRIPT" >&2
  exit 1
fi

if [[ "$WITH_TEAMFORGE" == "true" ]] && [[ ! -x "$TEAMFORGE_SYNC_SCRIPT" ]]; then
  echo "ERROR: Missing executable TeamForge sync script at $TEAMFORGE_SYNC_SCRIPT" >&2
  exit 1
fi

acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$$" > "$LOCK_PID_FILE"
    return 0
  fi

  # Attempt stale lock recovery.
  if [[ -f "$LOCK_PID_FILE" ]]; then
    local owner_pid
    owner_pid="$(cat "$LOCK_PID_FILE" 2>/dev/null || true)"
    if [[ -n "$owner_pid" ]] && kill -0 "$owner_pid" 2>/dev/null; then
      log "warn" "Another cycle appears to be running (pid=$owner_pid, lock=$LOCK_DIR); skipping this run"
      return 1
    fi
  fi

  rm -f "$LOCK_PID_FILE" 2>/dev/null || true
  rmdir "$LOCK_DIR" 2>/dev/null || true

  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$$" > "$LOCK_PID_FILE"
    log "warn" "Recovered stale cycle lock: $LOCK_DIR"
    return 0
  fi

  log "warn" "Unable to acquire cycle lock after recovery attempt: $LOCK_DIR"
  return 1
}

release_lock() {
  rm -f "$LOCK_PID_FILE" 2>/dev/null || true
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

if ! acquire_lock; then
  exit 0
fi
trap 'release_lock' EXIT

failures=0

run_step() {
  local name="$1"
  shift
  log "info" "Starting step: $name"
  if "$@"; then
    log "info" "Step completed: $name"
  else
    log "error" "Step failed: $name"
    failures=$((failures + 1))
  fi
}

if [[ "$WITH_TEAMFORGE" == "true" ]]; then
  if [[ "$TEAMFORGE_DRY_RUN" == "true" ]]; then
    run_step "teamforge-sync(dry-run)" "$TEAMFORGE_SYNC_SCRIPT" sync --dry-run --no-dispatch
  else
    run_step "teamforge-sync" "$TEAMFORGE_SYNC_SCRIPT" sync
  fi
fi

run_step "sync-issues" "$SYNC_SCRIPT" sync-issues

if [[ "$RECON_DRY_RUN" == "true" ]]; then
  run_step "reconcile-local(dry-run)" "$RECON_SCRIPT" --dry-run
else
  run_step "reconcile-local" "$RECON_SCRIPT"
fi

if [[ "$WITH_HEARTBEATS" == "true" ]]; then
  run_step "sync-heartbeats" "$SYNC_SCRIPT" sync-heartbeats
fi

if [[ "$failures" -gt 0 ]]; then
  log "error" "Cycle finished with $failures failed step(s)"
  exit 1
fi

log "info" "Cycle finished successfully"
