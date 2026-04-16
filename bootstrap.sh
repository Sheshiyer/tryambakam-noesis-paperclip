#!/usr/bin/env bash
set -euo pipefail

# Thoughtseed Labs — Bootstrap Script
# Idempotent setup: validates manifest, seeds missing state files, creates dirs, verifies Paperclip connection

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
PAPERCLIP_API="${PAPERCLIP_API:-http://127.0.0.1:3100/api}"
PAPERCLIP_COMPANY_ID="${PAPERCLIP_COMPANY_ID:-d89420ba-ce5a-45f6-bd0a-e735d2e02740}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { printf "${GREEN}✓${NC} %s\n" "$1"; }
fail() { printf "${RED}✗${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}!${NC} %s\n" "$1"; }
info() { printf "  %s\n" "$1"; }

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║  Thoughtseed Labs — Bootstrap                 ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

ERRORS=0

# ── Step 1: Validate manifest ──
echo "── Step 1: Validate manifest.yaml ──"
if [[ -f "$REPO_ROOT/manifest.yaml" ]]; then
  pass "manifest.yaml exists"
  # Basic structure check
  if grep -q "org:" "$REPO_ROOT/manifest.yaml" && grep -q "hierarchy:" "$REPO_ROOT/manifest.yaml"; then
    pass "manifest.yaml has org + hierarchy sections"
  else
    fail "manifest.yaml missing required sections (org, hierarchy)"
    ERRORS=$((ERRORS + 1))
  fi
else
  fail "manifest.yaml not found at $REPO_ROOT/manifest.yaml"
  ERRORS=$((ERRORS + 1))
fi

# ── Step 2: Validate agent directories ──
echo ""
echo "── Step 2: Validate agent state files ──"
AGENTS=(jarvis atlas trendy scribe clawd sentinel pixel nova vibe sage clip)
REQUIRED_FILES=(MANIFEST.yaml IDENTITY.md SOUL.md CONTEXT.md TASKS.md INBOX.md TOOLS.md HEARTBEAT.md USER.md MEMORY.md AGENTS.md EVOLVE.md SELF.md)

for agent in "${AGENTS[@]}"; do
  agent_dir="$REPO_ROOT/agents/$agent"
  if [[ ! -d "$agent_dir" ]]; then
    fail "Agent directory missing: agents/$agent"
    ERRORS=$((ERRORS + 1))
    continue
  fi
  missing=()
  for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$agent_dir/$f" ]]; then
      missing+=("$f")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    pass "agents/$agent — all 13 state files present"
  else
    warn "agents/$agent — missing: ${missing[*]}"
  fi
done

# ── Step 3: Validate directories ──
echo ""
echo "── Step 3: Validate directory structure ──"
REQUIRED_DIRS=(scripts workflows departments memory vault vault/research vault/content vault/design vault/engineering vault/handoffs .thoughtseed logs templates skills-source)

for d in "${REQUIRED_DIRS[@]}"; do
  if [[ -d "$REPO_ROOT/$d" ]]; then
    pass "$d/"
  else
    mkdir -p "$REPO_ROOT/$d"
    warn "$d/ created (was missing)"
  fi
done

# ── Step 4: Validate scripts ──
echo ""
echo "── Step 4: Validate orchestration scripts ──"
REQUIRED_SCRIPTS=(loop-runner.sh agent-prompt-assembler.sh agent-output-parser.sh write-back.sh dispatch-task.sh heartbeat-writer.sh task-registry.sh paperclip-sync.sh teamforge-sync.sh paperclip-reconcile-local.sh paperclip-cycle.sh paperclip-cron.sh)

for s in "${REQUIRED_SCRIPTS[@]}"; do
  if [[ -f "$REPO_ROOT/scripts/$s" ]]; then
    if [[ -x "$REPO_ROOT/scripts/$s" ]]; then
      pass "scripts/$s (executable)"
    else
      chmod +x "$REPO_ROOT/scripts/$s"
      warn "scripts/$s (made executable)"
    fi
  else
    fail "scripts/$s not found"
    ERRORS=$((ERRORS + 1))
  fi
done

# ── Step 5: Validate workflows ──
echo ""
echo "── Step 5: Validate workflows ──"
REQUIRED_WORKFLOWS=(agent-loop.yaml)

for w in "${REQUIRED_WORKFLOWS[@]}"; do
  if [[ -f "$REPO_ROOT/workflows/$w" ]]; then
    pass "workflows/$w"
  else
    fail "workflows/$w not found"
    ERRORS=$((ERRORS + 1))
  fi
done

# ── Step 6: Validate task registry ──
echo ""
echo "── Step 6: Validate runtime state ──"
REGISTRY="$REPO_ROOT/.thoughtseed/task-registry.json"
if [[ -f "$REGISTRY" ]]; then
  if jq empty "$REGISTRY" 2>/dev/null; then
    pass ".thoughtseed/task-registry.json (valid JSON)"
  else
    fail ".thoughtseed/task-registry.json (invalid JSON)"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo '{"tasks":[],"metadata":{"total":0,"pending":0,"in_progress":0,"completed":0,"blocked":0,"failed":0,"last_updated":null}}' > "$REGISTRY"
  warn ".thoughtseed/task-registry.json created"
fi

# ── Step 7: Verify Paperclip connection ──
echo ""
echo "── Step 7: Verify Paperclip connection ──"
if command -v curl &>/dev/null; then
  HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "$PAPERCLIP_API/companies/$PAPERCLIP_COMPANY_ID" 2>/dev/null || echo "000")
  if [[ "$HTTP_CODE" == "200" ]]; then
    COMPANY_NAME=$(curl -s "$PAPERCLIP_API/companies/$PAPERCLIP_COMPANY_ID" 2>/dev/null | jq -r '.name // "unknown"')
    pass "Paperclip API reachable — org: $COMPANY_NAME"
    AGENT_COUNT=$(curl -s "$PAPERCLIP_API/companies/$PAPERCLIP_COMPANY_ID/agents" 2>/dev/null | jq 'length')
    info "$AGENT_COUNT agents registered in Paperclip"
  elif [[ "$HTTP_CODE" == "000" ]]; then
    warn "Paperclip API unreachable at $PAPERCLIP_API (server may not be running)"
  else
    warn "Paperclip API returned HTTP $HTTP_CODE"
  fi
else
  warn "curl not found — skipping Paperclip connection check"
fi

# ── Step 8: Verify tools ──
echo ""
echo "── Step 8: Verify required tools ──"
for tool in jq node codex; do
  if command -v "$tool" &>/dev/null; then
    ver=$($tool --version 2>/dev/null | head -1 || echo "installed")
    pass "$tool ($ver)"
  else
    case "$tool" in
      codex) warn "$tool not found — agents won't be able to execute cycles" ;;
      jq)    fail "$tool not found — required for JSON parsing"; ERRORS=$((ERRORS + 1)) ;;
      *)     warn "$tool not found" ;;
    esac
  fi
done

# ── Summary ──
echo ""
echo "════════════════════════════════════════════════"
if [[ $ERRORS -eq 0 ]]; then
  printf "${GREEN}Bootstrap complete — no critical errors${NC}\n"
  echo ""
  echo "Next steps:"
  echo "  1. Dispatch a task:  ./scripts/dispatch-task.sh \"Test task\" --tag research --priority medium"
  echo "  2. Run one cycle:    ./scripts/loop-runner.sh run --once --agent jarvis"
  echo "  3. Run Paperclip:    ./scripts/paperclip-cycle.sh"
  echo "  4. Install cron:     ./scripts/paperclip-cron.sh install"
  echo "  5. Start the swarm:  ./scripts/babysitter.sh start"
  echo "  6. Check status:     ./scripts/health-check.sh"
else
  printf "${RED}Bootstrap found $ERRORS critical error(s)${NC}\n"
  echo "Fix the errors above and re-run: ./bootstrap.sh"
fi
echo ""
