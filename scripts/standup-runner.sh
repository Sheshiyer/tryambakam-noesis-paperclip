#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Parse args
AGENT=""
SUMMARY_ONLY=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --agent) AGENT="$2"; shift 2;;
    --summary) SUMMARY_ONLY=true; shift;;
    *) shift;;
  esac
done

TODAY=$(date -u +%Y-%m-%d)
STANDUP_DIR="$REPO_ROOT/vault/standups/$TODAY"
mkdir -p "$STANDUP_DIR"

# Discover agents from manifest (or list dirs)
if [[ -n "$AGENT" ]]; then
  AGENTS=("$AGENT")
elif [[ "$SUMMARY_ONLY" == "false" ]]; then
  AGENTS=($(ls "$REPO_ROOT/agents/"))
fi

# Generate individual standups
if [[ "$SUMMARY_ONLY" == "false" ]]; then
  for agent in "${AGENTS[@]}"; do
    echo "📋 Generating standup for $agent..."
    "$REPO_ROOT/scripts/standup-template.sh" "$agent" > "$STANDUP_DIR/$agent.md"
    echo "✅ $agent standup saved to vault/standups/$TODAY/$agent.md"
  done
fi

# Generate org summary (only if all standups exist or --summary flag)
echo ""
echo "📊 Generating org summary..."
# Count standups vs expected
EXPECTED=$(ls "$REPO_ROOT/agents/" | wc -l | tr -d ' ')
ACTUAL=$(ls "$STANDUP_DIR"/*.md 2>/dev/null | grep -v org-summary | wc -l | tr -d ' ')

# Build summary
{
  echo "# Org Standup Summary — $TODAY"
  echo ""
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Coverage: $ACTUAL / $EXPECTED agents reported"
  echo ""

  # Completed work across org
  echo "## ✅ Completed Today"
  echo ""
  for f in "$STANDUP_DIR"/*.md; do
    [[ "$(basename "$f")" == "org-summary.md" ]] && continue
    agent=$(basename "$f" .md)
    # Extract completed items
    completed=$(sed -n '/^## ✅ Completed/,/^## /p' "$f" | grep '^- ' || true)
    if [[ -n "$completed" ]]; then
      echo "### $agent"
      echo "$completed"
      echo ""
    fi
  done

  # Blockers across org
  echo "## 🚫 Active Blockers"
  echo ""
  BLOCKERS_FOUND=false
  for f in "$STANDUP_DIR"/*.md; do
    [[ "$(basename "$f")" == "org-summary.md" ]] && continue
    agent=$(basename "$f" .md)
    blockers=$(sed -n '/^## 🚫 Blockers/,/^## /p' "$f" | grep '^- ' | grep -v 'None' || true)
    if [[ -n "$blockers" ]]; then
      BLOCKERS_FOUND=true
      echo "### $agent"
      echo "$blockers"
      echo ""
    fi
  done
  if [[ "$BLOCKERS_FOUND" == "false" ]]; then
    echo "_No blockers reported._"
    echo ""
  fi

  # Missing standups
  echo "## ⚠️ Missing Standups"
  echo ""
  for agent_dir in "$REPO_ROOT/agents"/*/; do
    agent=$(basename "$agent_dir")
    if [[ ! -f "$STANDUP_DIR/$agent.md" ]]; then
      echo "- **$agent** — no standup submitted"
    fi
  done
  echo ""

  # Metrics
  echo "## 📊 Metrics"
  echo ""
  total_completed=0
  total_blocked=0
  for f in "$STANDUP_DIR"/*.md; do
    [[ "$(basename "$f")" == "org-summary.md" ]] && continue
    c=$(sed -n '/^## ✅ Completed/,/^## /p' "$f" | grep -c '^- ' || true)
    b=$(sed -n '/^## 🚫 Blockers/,/^## /p' "$f" | grep '^- ' | grep -vc 'None' || true)
    total_completed=$((total_completed + c))
    total_blocked=$((total_blocked + b))
  done
  echo "- Total completed items: $total_completed"
  echo "- Total active blockers: $total_blocked"
  echo "- Standup coverage: ${ACTUAL}/${EXPECTED} ($(( ACTUAL * 100 / EXPECTED ))%)"

} > "$STANDUP_DIR/org-summary.md"

echo "✅ Org summary saved to vault/standups/$TODAY/org-summary.md"
echo ""
echo "📊 Coverage: $ACTUAL/$EXPECTED agents | Blockers: review org-summary.md"
