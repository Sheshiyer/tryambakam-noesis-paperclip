#!/usr/bin/env bash
# Thoughtseed Labs Agent Prompt Assembler
# Builds the structured prompt that gets piped to codex for a given agent.
#
# Reads the agent's identity, state files, manifest, and shared memory
# to construct a prompt that makes the agent follow its loop cycle.
#
# Usage:
#   ./scripts/agent-prompt-assembler.sh <agent_id>
#
# Output: prompt text on stdout

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SCRIPT_DIR="$REPO_ROOT/scripts"

# ---- Logging (to stderr so stdout stays clean for the prompt) ----

log() {
  local level="$1"
  shift
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [prompt-assembler] [$level] $*" >&2
}

# ---- Validate args ----

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <agent_id>" >&2
  exit 1
fi

AGENT_ID="$1"
AGENT_DIR="$REPO_ROOT/agents/$AGENT_ID"

if [[ ! -d "$AGENT_DIR" ]]; then
  log "error" "Agent directory not found: $AGENT_DIR"
  exit 1
fi

# ---- Read file safely (returns empty string if missing) ----

read_file() {
  local filepath="$1"
  if [[ -f "$filepath" ]]; then
    cat "$filepath"
  else
    log "warn" "File not found: $filepath"
    echo "(file not found)"
  fi
}

read_file_head_tail() {
  local filepath="$1"
  local head_lines="$2"
  local tail_lines="$3"
  local label="$4"

  if [[ ! -f "$filepath" ]]; then
    log "warn" "File not found: $filepath"
    echo "(file not found)"
    return
  fi

  if (( head_lines <= 0 || tail_lines <= 0 )); then
    cat "$filepath"
    return
  fi

  local total_lines
  total_lines=$(wc -l < "$filepath" | tr -d ' ')
  local passthrough_limit=$(( head_lines + tail_lines + 20 ))

  if (( total_lines <= passthrough_limit )); then
    cat "$filepath"
    return
  fi

  {
    head -n "$head_lines" "$filepath"
    echo ""
    echo "[... ${label} middle omitted for prompt-size control: showing first ${head_lines} and last ${tail_lines} lines out of ${total_lines} total ...]"
    echo ""
    tail -n "$tail_lines" "$filepath"
  }
}

trim_to_limit() {
  local text="$1"
  local limit="$2"
  if (( ${#text} <= limit )); then
    printf '%s' "$text"
    return
  fi
  printf '%s [truncated to %s chars]' "${text:0:limit}" "$limit"
}

TEAMFORGE_SLICES_DIR="${TEAMFORGE_SLICES_DIR:-$REPO_ROOT/.thoughtseed/teamforge/slices}"
TEAMFORGE_PROMPT_MAX_CHARS="${TEAMFORGE_PROMPT_MAX_CHARS:-6000}"
TEAMFORGE_PROMPT_MAX_ITEMS="${TEAMFORGE_PROMPT_MAX_ITEMS:-8}"
CONTEXT_PROMPT_HEAD_LINES="${CONTEXT_PROMPT_HEAD_LINES:-180}"
CONTEXT_PROMPT_TAIL_LINES="${CONTEXT_PROMPT_TAIL_LINES:-220}"
HEARTBEAT_PROMPT_HEAD_LINES="${HEARTBEAT_PROMPT_HEAD_LINES:-40}"
HEARTBEAT_PROMPT_TAIL_LINES="${HEARTBEAT_PROMPT_TAIL_LINES:-180}"

build_teamforge_feed_context() {
  local role="$1"
  local slice_file="$TEAMFORGE_SLICES_DIR/${role}.json"
  local fallback_file="$TEAMFORGE_SLICES_DIR/jarvis.json"
  local selected_file=""

  if [[ -f "$slice_file" ]]; then
    selected_file="$slice_file"
  elif [[ -f "$fallback_file" ]]; then
    selected_file="$fallback_file"
    log "warn" "No TeamForge slice for role '$role'; falling back to jarvis slice"
  fi

  if [[ -z "$selected_file" ]]; then
    log "warn" "No TeamForge feed slices found at $TEAMFORGE_SLICES_DIR"
    echo "No TeamForge feed slice available for this cycle."
    return
  fi

  if ! jq empty "$selected_file" >/dev/null 2>&1; then
    log "warn" "Invalid TeamForge slice JSON: $selected_file"
    echo "TeamForge feed slice is unreadable; continuing without feed context."
    return
  fi

  local context
  context="$(jq -r --arg role "$role" --argjson max_items "$TEAMFORGE_PROMPT_MAX_ITEMS" '
    (
      "Feed role: " + $role,
      "Slice generated at: " + (.generatedAt // "unknown"),
      "Overlap policy: " + (.overlapPolicy // "n/a"),
      "Signals:"
    ),
    (
      .items
      | sort_by((-(.score // 0)), (.detectedAt // ""), (.syncKey // ""))
      | .[0:$max_items]
      | if length == 0 then
          "- (no matching signals)"
        else
          .[]
          | "- [" + ((.scoredSeverity // "info") | ascii_upcase) + "|" + ((.score // 0) | tostring) + "] "
            + (.eventType // "unknown-event")
            + " :: " + (.summary // .entityId // "n/a")
            + " | source=" + (.source // "unknown")
            + " | owner=" + (.routeOwner // "jarvis")
            + " | sync_key=" + (.syncKey // "n/a")
        end
    )
  ' "$selected_file")"

  trim_to_limit "$context" "$TEAMFORGE_PROMPT_MAX_CHARS"
}

# ---- YAML Helper ----

YAML_HELPERS_SCRIPT="$SCRIPT_DIR/yaml-helpers.sh"
if [[ ! -f "$YAML_HELPERS_SCRIPT" ]]; then
  log "error" "YAML helpers script missing: $YAML_HELPERS_SCRIPT"
  exit 1
fi
# shellcheck disable=SC1090
source "$YAML_HELPERS_SCRIPT"

# ---- Read agent manifest values ----

AGENT_MANIFEST="$AGENT_DIR/MANIFEST.yaml"

agent_role=""
agent_reports_to=""
agent_tier=""
agent_max_timeout="4m"
agent_on_blocked="log_and_skip"
agent_on_failure="log_skip_continue"
agent_retry_blocked_after="3"

if [[ -f "$AGENT_MANIFEST" ]]; then
  agent_role=$(yaml_path_get "$AGENT_MANIFEST" "role")
  agent_reports_to=$(yaml_path_get "$AGENT_MANIFEST" "reports_to")
  agent_tier=$(yaml_path_get "$AGENT_MANIFEST" "tier")

  local_timeout=$(yaml_path_get "$AGENT_MANIFEST" "loop.max_step_timeout")
  if [[ -n "$local_timeout" ]]; then
    agent_max_timeout="$local_timeout"
  fi

  local_on_blocked=$(yaml_path_get "$AGENT_MANIFEST" "loop.on_blocked")
  if [[ -n "$local_on_blocked" ]]; then
    agent_on_blocked="$local_on_blocked"
  fi

  local_on_failure=$(yaml_path_get "$AGENT_MANIFEST" "loop.on_failure")
  if [[ -n "$local_on_failure" ]]; then
    agent_on_failure="$local_on_failure"
  fi

  local_retry=$(yaml_path_get "$AGENT_MANIFEST" "loop.retry_blocked_after")
  if [[ -n "$local_retry" ]]; then
    agent_retry_blocked_after="$local_retry"
  fi
fi

# ---- Read all agent state files ----

IDENTITY=$(read_file "$AGENT_DIR/IDENTITY.md")
SOUL=$(read_file "$AGENT_DIR/SOUL.md")
TASKS=$(read_file "$AGENT_DIR/TASKS.md")
INBOX=$(read_file "$AGENT_DIR/INBOX.md")
CONTEXT=$(read_file_head_tail "$AGENT_DIR/CONTEXT.md" "$CONTEXT_PROMPT_HEAD_LINES" "$CONTEXT_PROMPT_TAIL_LINES" "CONTEXT.md")
HEARTBEAT=$(read_file_head_tail "$AGENT_DIR/HEARTBEAT.md" "$HEARTBEAT_PROMPT_HEAD_LINES" "$HEARTBEAT_PROMPT_TAIL_LINES" "HEARTBEAT.md")
AGENTS=$(read_file "$AGENT_DIR/AGENTS.md")

# ---- Read shared memory files (core + Huly operational context) ----

SHARED_MEMORY=""

# Core memory (always loaded)
for mem_file in brand-voice.md tech-stack.md processes.md huly-system-overview.md; do
  local_path="$REPO_ROOT/memory/$mem_file"
  if [[ -f "$local_path" ]]; then
    SHARED_MEMORY+="
--- memory/$mem_file ---
$(cat "$local_path")
"
  fi
done

# Conditional Huly context (loaded based on agent role)
# JARVIS, SENTINEL get standup + team planner context
if [[ "$AGENT_ID" == "jarvis" || "$AGENT_ID" == "sentinel" ]]; then
  for mem_file in standup-process.md team-planner.md; do
    local_path="$REPO_ROOT/memory/$mem_file"
    if [[ -f "$local_path" ]]; then
      SHARED_MEMORY+="
--- memory/$mem_file ---
$(cat "$local_path")
"
    fi
  done
fi

# Department leads get sprint workflow
if [[ "$AGENT_ID" == "jarvis" || "$AGENT_ID" == "clawd" || "$AGENT_ID" == "atlas" || "$AGENT_ID" == "sage" || "$AGENT_ID" == "pixel" ]]; then
  local_path="$REPO_ROOT/memory/sprint-workflow.md"
  if [[ -f "$local_path" ]]; then
    SHARED_MEMORY+="
--- memory/sprint-workflow.md ---
$(cat "$local_path")
"
  fi
fi

# Client-facing agents get client management context
if [[ "$AGENT_ID" == "jarvis" || "$AGENT_ID" == "atlas" || "$AGENT_ID" == "sage" || "$AGENT_ID" == "clawd" ]]; then
  local_path="$REPO_ROOT/memory/client-management.md"
  if [[ -f "$local_path" ]]; then
    SHARED_MEMORY+="
--- memory/client-management.md ---
$(cat "$local_path")
"
  fi
fi

# ---- Load TeamForge feed context slice (role-specific with fallback) ----

TEAMFORGE_FEED_ROLE="jarvis"
case "$AGENT_ID" in
  jarvis|clawd|sentinel|sage)
    TEAMFORGE_FEED_ROLE="$AGENT_ID"
    ;;
  *)
    TEAMFORGE_FEED_ROLE="jarvis"
    ;;
esac

TEAMFORGE_FEED_CONTEXT="$(build_teamforge_feed_context "$TEAMFORGE_FEED_ROLE")"

# ---- Current timestamp ----

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ---- Assemble the prompt ----

log "info" "Assembling prompt for agent: $AGENT_ID (role: $agent_role, tier: $agent_tier)"

cat <<PROMPT_EOF
You are ${AGENT_ID}, a Thoughtseed Labs autonomous agent running a scheduled loop cycle.

Current time: ${NOW}

=============================================
IDENTITY
=============================================
${IDENTITY}

=============================================
CORE DIRECTIVES (SOUL)
=============================================
${SOUL}

=============================================
AGENT HIERARCHY & AWARENESS
=============================================
${AGENTS}

=============================================
SHARED MEMORY
=============================================
${SHARED_MEMORY}

=============================================
TEAMFORGE FEED CONTEXT
=============================================
${TEAMFORGE_FEED_CONTEXT}

=============================================
LOOP CYCLE CONFIGURATION
=============================================
- Agent ID: ${AGENT_ID}
- Role: ${agent_role}
- Tier: ${agent_tier}
- Reports to: ${agent_reports_to}
- Max step timeout: ${agent_max_timeout}
- On blocked: ${agent_on_blocked}
- On failure: ${agent_on_failure}
- Retry blocked after: ${agent_retry_blocked_after} cycles

=============================================
CURRENT STATE FILES
=============================================

--- INBOX.md (check FIRST) ---
${INBOX}

--- TASKS.md (work queue) ---
${TASKS}

--- CONTEXT.md (rules, constraints, pitfalls) ---
${CONTEXT}

--- HEARTBEAT.md (cycle history) ---
${HEARTBEAT}

=============================================
YOUR INSTRUCTIONS FOR THIS CYCLE
=============================================

You are running ONE autonomous loop cycle. Follow these steps EXACTLY:

PHASE 1 -- INBOX PROCESSING
1. Read the INBOX.md content above.
2. Look under "## Pending" for any new items.
3. For each pending item:
   a. Create a new step in TASKS.md with the item's priority and tags.
   b. Mark the inbox item as processed (move to "## Processed" with timestamp ${NOW}).
4. If there are 10+ pending items, add a note to escalate to ${agent_reports_to} for triage.
5. Critical inbox items override current step selection.

PHASE 2 -- STEP SELECTION
1. Look at TASKS.md under "## Active Tasks".
2. Find the first step with status "open" or "in-progress", ordered by priority: critical > high > medium > low.
3. Skip any step with status "blocked" whose retry_count < ${agent_retry_blocked_after}.
4. Retry any "blocked" step whose retry_count >= ${agent_retry_blocked_after}.
5. Respect depends_on: skip steps whose dependencies have not completed.
6. If no actionable steps exist, report idle.

PHASE 3 -- EXECUTE ONE STEP
1. Work on ONLY the selected step. Do NOT attempt multiple steps.
2. Read CONTEXT.md constraints before acting -- honor all rules and past pitfalls.
3. If the step requires delegating to a subordinate, create a task in their INBOX.md instead.
4. If the step is not your responsibility per the hierarchy, escalate upward.
5. Apply your identity and soul directives to HOW you approach the work.

PHASE 4 -- WRITE RESULTS
Based on the outcome of your step execution:

ON SUCCESS:
- Update the step status in TASKS.md to "done" with a Result description.
- Record the cycle in HEARTBEAT.md.
- If the step produced deliverables, note the vault path.

ON BLOCKED:
- Update the step status to "blocked" with a specific blocked reason.
- Increment the step's retry_count.
- Log the blocker in CONTEXT.md under "## Known Pitfalls".

ON FAILURE:
- Update the step status to "failed" with error details.
- The error becomes context -- add it to CONTEXT.md under "## Known Pitfalls".
- If the same step has failed 3+ times, add an escalation note for ${agent_reports_to}.

ON IDLE (no steps to work):
- Report idle status. Do not invent work.
- For any unchanged state file, emit "NO_CHANGES" in that file's update block.

=============================================
OUTPUT FORMAT -- MANDATORY
=============================================

You MUST output your results in this EXACT structured format.
Everything between the START and END markers will be parsed programmatically.
Do NOT include any text outside these markers except a brief summary before them.

Brief cycle summary: [1-2 sentences about what you did this cycle]

===THOUGHTSEED_OUTPUT_START===
---FILE_UPDATE: TASKS.md---
[If TASKS.md changed this cycle, write the COMPLETE updated TASKS.md content.
Include ALL sections: Active Tasks, Task Format, Completed Tasks.
Update the step you worked on and keep all other steps as-is.
If TASKS.md did not change, write exactly: NO_CHANGES]
---END_FILE_UPDATE---
---FILE_UPDATE: HEARTBEAT.md---
### ${NOW} Cycle Result
- Step: [step_id or "idle"]
- Outcome: [completed|blocked|failed|idle]
- Duration: [estimated seconds]
- Summary: [1 sentence of what happened]
---END_FILE_UPDATE---
---FILE_UPDATE: INBOX.md---
[If INBOX.md changed this cycle, write the COMPLETE updated INBOX.md content.
Move any processed items from Pending to Processed with timestamps.
If INBOX.md did not change, write exactly: NO_CHANGES]
---END_FILE_UPDATE---
---FILE_UPDATE: CONTEXT.md---
[ONLY if you have new pitfalls or learnings to add.
Write ONLY the new entries to append, prefixed with "- [${NOW}]".
If nothing to add, write: NO_CHANGES]
---END_FILE_UPDATE---
===THOUGHTSEED_OUTPUT_END===

CRITICAL RULES:
- Output MUST contain the ===THOUGHTSEED_OUTPUT_START=== and ===THOUGHTSEED_OUTPUT_END=== markers.
- Each file update MUST be between ---FILE_UPDATE: {filename}--- and ---END_FILE_UPDATE--- markers.
- TASKS.md update must contain the FULL file content when changed, or "NO_CHANGES" when unchanged.
- HEARTBEAT.md update should contain ONLY the new entry to append.
- INBOX.md update must contain the FULL file content when changed, or "NO_CHANGES" when unchanged.
- CONTEXT.md update contains ONLY new lines to append, or "NO_CHANGES".
- Do NOT wrap the output in markdown code fences.
- Do NOT add commentary inside the structured output section.
PROMPT_EOF

log "info" "Prompt assembled for $AGENT_ID"
