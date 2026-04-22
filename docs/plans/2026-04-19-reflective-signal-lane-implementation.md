# Reflective Signal Lane Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a constrained reflective signal lane to Paperclip that notices recurring operational drift, writes durable board state, and raises reviewable intents without directly shipping code or becoming a second control plane.

**Architecture:** Reuse the existing `paperclip-cycle.sh` and local vault bridge instead of creating a new "subconscious" profile. The signal lane runs after TeamForge sync and local reconciliation, reads current operational surfaces from `.thoughtseed/`, `logs/`, and the vault bridge, scores recurring issues into explicit middle states, and dispatches only `review-intent` / `build-intent` tasks to current leads (`jarvis`, `clawd`, `atlas`, `sage`, `sentinel`, `scribe`) with stable sync keys and cooldowns.

**Tech Stack:** Bash, `jq`, markdown/JSON artifacts, existing `dispatch-task.sh`, existing `task-registry.sh`, existing Paperclip cycle scripts, vault bridge files under `/Volumes/madara/2026/twc-vault`

---

## Recommendation

### Chosen Approach: Reflective Signal Lane inside the existing control plane

This is the right fit for the current repo because the main failure is not "lack of ideation." It is runtime drift:

- stale Paperclip roots
- dead launchd supervision
- empty TeamForge slices
- stale Meru candidate surfaces
- task-registry drift
- `.claude` / `.agents` skill drift

The new lane should therefore be a **read-mostly noticing layer** that:

- reads current state
- scores recurrence
- writes a board
- opens narrow intents
- never writes product code itself
- never mutates scoring rules from inside the loop

### Rejected Approach 1: New autonomous `subc` profile

Do not create a separate "subconscious" agent workspace yet. That would add one more source of truth while the repo still has multiple Paperclip roots in circulation.

### Rejected Approach 2: Dashboard-only observability

Pure dashboards would improve visibility, but they would not create durable operator-ready tasks with gating, cooldowns, and explicit intermediate states. The value of the pattern is not a prettier board; it is disciplined noticing before execution.

## Current Repo Mapping

Use the current Paperclip roster. Do not add a new named agent.

- `jarvis`: final gate for `ready`, `blocked`, `priority-arbitration`, and cross-lane conflicts
- `clawd`: runtime-root drift, launchd drift, script path drift, execution-surface repairs
- `atlas`: skill drift, mapping ambiguity, taxonomy inconsistencies, research-backed remediation notes
- `sage`: triage of noisy or borderline signals into `watching`, `candidate`, or `ghost`
- `sentinel`: regression review, board quality review, false-positive control
- `scribe`: human-readable operator brief, daily/weekly signal digest

Use these current folders and files as the signal lane's operating surfaces:

- `.thoughtseed/task-registry.json`
- `.thoughtseed/teamforge/sync-state.json`
- `.thoughtseed/teamforge/slices/*.json`
- `logs/loop-runner.log`
- `logs/babysitter.log`
- `scripts/paperclip-cycle.sh`
- `scripts/loop-runner.sh`
- `scripts/dispatch-task.sh`
- `scripts/task-registry.sh`
- `memory/twc-vault-integration.md`
- `/Volumes/madara/2026/twc-vault/_System/memory/archetypal-candidates/latest-run.json`
- `/Volumes/madara/2026/twc-vault/.claude/skills/`
- `/Volumes/madara/2026/twc-vault/.agents/skills/`

## State Model

The signal lane should use explicit middle states:

- `watching`
- `candidate`
- `experiment`
- `ready`
- `blocked`
- `ghost`
- `stale`
- `resolved`

The lane should emit two task types only:

- `review-intent`: "something recurrent needs a human or lead decision"
- `build-intent`: "a bounded repair is now justified and assigned"

It should not emit direct code execution or self-approved changes.

## Output Contract

Create one durable state surface and two operator views:

- machine state:
  - `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/.thoughtseed/signal-lane/state.json`
  - `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/.thoughtseed/signal-lane/events.jsonl`
- human-readable board:
  - `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/vault/leadership/signal-lane/signal-board.md`
- operator digest:
  - `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/vault/leadership/signal-lane/daily-brief.md`

Each signal record should carry:

- `sync_key`
- `signal_type`
- `state`
- `score`
- `signal_count`
- `signal_types`
- `first_seen_at`
- `last_seen_at`
- `cooldown_until`
- `owner`
- `source_refs`
- `recommended_action`

### Task 1: Add a canonical runtime-root guard before any signal work

**Files:**
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/runtime-root-guard.sh`
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/host-supervisor.sh`
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/babysitter.sh`
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/loop-runner.sh`
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/health-check.sh`
- Test: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_runtime_root_guard.sh`

**Step 1: Write the failing test**

Create `tests/test_runtime_root_guard.sh` to assert:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$("$REPO_ROOT/scripts/runtime-root-guard.sh" check 2>&1 || true)"

echo "$OUTPUT" | rg "canonical runtime root" >/dev/null
echo "$OUTPUT" | rg "mismatch|missing|ok" >/dev/null
```

**Step 2: Run test to verify it fails**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_runtime_root_guard.sh
```

Expected: FAIL because `runtime-root-guard.sh` does not exist yet.

**Step 3: Write minimal implementation**

Create `scripts/runtime-root-guard.sh` with three commands:

- `check`: compare `REPO_ROOT` against one canonical path source
- `print`: emit resolved repo root and configured canonical root
- `assert`: exit non-zero if the current runtime root is stale

Use one config source only. Recommended first version:

```bash
CANONICAL_RUNTIME_ROOT="${CANONICAL_RUNTIME_ROOT:-$REPO_ROOT}"
```

Then wire `assert` into `host-supervisor.sh`, `babysitter.sh`, `loop-runner.sh`, and `health-check.sh` before they claim PID files or report healthy status.

**Step 4: Run test to verify it passes**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_runtime_root_guard.sh
bash -n 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/runtime-root-guard.sh
bash -n 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/loop-runner.sh
```

Expected: PASS, no syntax errors.

**Step 5: Commit**

```bash
git add 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/runtime-root-guard.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/host-supervisor.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/babysitter.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/loop-runner.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/health-check.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_runtime_root_guard.sh
git commit -m "fix: assert canonical paperclip runtime root"
```

### Task 2: Add the signal-lane state contract and board outputs

**Files:**
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/signal-lane-scan.sh`
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/templates/signal-board.md`
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/.thoughtseed/signal-lane/.gitkeep`
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_contract.sh`
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/fixtures/signal-lane/minimal-state.json`

**Step 1: Write the failing test**

Create `tests/test_signal_lane_contract.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$REPO_ROOT/.thoughtseed/signal-lane/state.json"
BOARD_FILE="$REPO_ROOT/vault/leadership/signal-lane/signal-board.md"

"$REPO_ROOT/scripts/signal-lane-scan.sh" init >/dev/null

jq -e '.signals and .metadata and .cooldowns' "$STATE_FILE" >/dev/null
test -f "$BOARD_FILE"
```

**Step 2: Run test to verify it fails**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_contract.sh
```

Expected: FAIL because `signal-lane-scan.sh` and board outputs do not exist.

**Step 3: Write minimal implementation**

Create `scripts/signal-lane-scan.sh init` that bootstraps:

```json
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
```

Also create a simple `templates/signal-board.md` scaffold with sections:

- room health / runtime health
- top recurring signals
- ready intents
- blocked intents
- ghosts / stale items

**Step 4: Run test to verify it passes**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_contract.sh
bash -n 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/signal-lane-scan.sh
```

Expected: PASS, state file and board file exist.

**Step 5: Commit**

```bash
git add 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/signal-lane-scan.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/templates/signal-board.md \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/.thoughtseed/signal-lane/.gitkeep \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_contract.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/fixtures/signal-lane/minimal-state.json
git commit -m "feat: add signal lane state and board contract"
```

### Task 3: Teach the signal lane to notice the current real failure classes

**Files:**
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/signal-lane-scan.sh`
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_detection.sh`
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/fixtures/signal-lane/drifted-runtime/loop-runner.log`
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/fixtures/signal-lane/drifted-runtime/teamforge-sync-state.json`
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/fixtures/signal-lane/drifted-runtime/task-registry.json`

**Step 1: Write the failing test**

Create `tests/test_signal_lane_detection.sh` to assert detection of:

- runtime-root drift
- dead TeamForge feed
- stale Meru handoff
- task-registry drift
- skill-mirror drift

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/signal-lane/drifted-runtime"

"$REPO_ROOT/scripts/signal-lane-scan.sh" scan --fixture-dir "$FIXTURE_DIR" >/dev/null

jq -e '.signals[] | select(.signal_type == "runtime_root_drift")' "$REPO_ROOT/.thoughtseed/signal-lane/state.json" >/dev/null
jq -e '.signals[] | select(.signal_type == "teamforge_feed_down")' "$REPO_ROOT/.thoughtseed/signal-lane/state.json" >/dev/null
```

**Step 2: Run test to verify it fails**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_detection.sh
```

Expected: FAIL because `scan` does not yet emit these signal types.

**Step 3: Write minimal implementation**

Extend `signal-lane-scan.sh scan` to compute signals from:

- `scripts/runtime-root-guard.sh print`
- `.thoughtseed/teamforge/sync-state.json`
- `.thoughtseed/task-registry.json`
- `logs/loop-runner.log`
- `logs/babysitter.log`
- `/Volumes/madara/2026/twc-vault/_System/memory/archetypal-candidates/latest-run.json`
- `/Volumes/madara/2026/twc-vault/.claude/skills`
- `/Volumes/madara/2026/twc-vault/.agents/skills`

Minimum first-version signal types:

- `runtime_root_drift`
- `teamforge_feed_down`
- `loop_runner_idle_storm`
- `task_registry_drift`
- `meru_stale_run`
- `skill_mirror_drift`

Score only from deterministic evidence. Do not call models.

**Step 4: Run test to verify it passes**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_detection.sh
jq '.signals | length' 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/.thoughtseed/signal-lane/state.json
```

Expected: PASS, non-zero signal count.

**Step 5: Commit**

```bash
git add 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/signal-lane-scan.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_detection.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/fixtures/signal-lane/drifted-runtime
git commit -m "feat: detect recurrent runtime drift signals"
```

### Task 4: Add stable sync keys, cooldowns, and intent gating

**Files:**
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/signal-lane-scan.sh`
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/task-registry.sh`
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/dispatch-task.sh`
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_gating.sh`

**Step 1: Write the failing test**

Create `tests/test_signal_lane_gating.sh` to assert:

- repeated identical signals collapse to one `sync_key`
- a `ready` signal does not create duplicate active tasks
- cooldown suppresses rapid re-dispatch

**Step 2: Run test to verify it fails**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_gating.sh
```

Expected: FAIL because there is no signal-lane dedupe or cooldown path yet.

**Step 3: Write minimal implementation**

Add to `task-registry.sh` a query helper:

```bash
./scripts/task-registry.sh find-active-by-sync-key signal:runtime_root_drift:launchd
```

Use it from `signal-lane-scan.sh dispatch` before calling `dispatch-task.sh`.

Route rules:

- `runtime_root_drift` -> `clawd`
- `teamforge_feed_down` -> `clawd`
- `skill_mirror_drift` -> `atlas`
- `task_registry_drift` -> `sentinel`
- `meru_stale_run` -> `sage`
- cross-lane / conflicting / repeated unresolved -> `jarvis`

Only dispatch when:

- score crosses threshold
- cooldown is clear
- no active task exists for `sync_key`

**Step 4: Run test to verify it passes**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_gating.sh
```

Expected: PASS, one active task per signal identity.

**Step 5: Commit**

```bash
git add 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/signal-lane-scan.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/task-registry.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/dispatch-task.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_gating.sh
git commit -m "feat: gate signal lane intents with sync keys and cooldowns"
```

### Task 5: Integrate the signal lane into the deterministic Paperclip cycle

**Files:**
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/paperclip-cycle.sh`
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/loop-runner.sh`
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/manifest.yaml`
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_paperclip_cycle_signal_lane.sh`

**Step 1: Write the failing test**

Create `tests/test_paperclip_cycle_signal_lane.sh` to assert `paperclip-cycle.sh` runs signal-lane scan after reconcile.

**Step 2: Run test to verify it fails**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_paperclip_cycle_signal_lane.sh
```

Expected: FAIL because the cycle has no signal-lane step.

**Step 3: Write minimal implementation**

Add a new step order:

1. `teamforge-sync`
2. `paperclip-sync sync-issues`
3. `paperclip-reconcile-local`
4. `signal-lane-scan scan`
5. optional `paperclip-sync sync-heartbeats`

Add manifest settings:

```yaml
  signal_lane:
    enabled: true
    dispatch_enabled: true
    cooldown_minutes: 180
    ready_threshold: 70
    experiment_threshold: 50
```

Add loop-runner env passthrough:

- `LOOP_SIGNAL_LANE_ENABLED`
- `LOOP_SIGNAL_LANE_INTERVAL`

**Step 4: Run test to verify it passes**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_paperclip_cycle_signal_lane.sh
bash -n 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/paperclip-cycle.sh
```

Expected: PASS, syntax clean, step order enforced.

**Step 5: Commit**

```bash
git add 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/paperclip-cycle.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/loop-runner.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/manifest.yaml \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_paperclip_cycle_signal_lane.sh
git commit -m "feat: integrate signal lane into paperclip cycle"
```

### Task 6: Document the lane as a control-plane pattern, not a mythological persona

**Files:**
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/memory/reflective-signal-lane.md`
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/memory/architecture.md`
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/memory/twc-vault-integration.md`
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/memory/openclaw-integration.md`

**Step 1: Write the failing doc check**

Create a simple shell assertion inside `tests/test_signal_lane_docs.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

rg "signal lane|review-intent|build-intent" 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/memory/reflective-signal-lane.md >/dev/null
rg "Paperclip is the control plane" 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/memory/twc-vault-integration.md >/dev/null
```

**Step 2: Run test to verify it fails**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_docs.sh
```

Expected: FAIL because the signal-lane doc does not exist.

**Step 3: Write minimal implementation**

Document:

- why the repo is using a reflective lane instead of a new autonomous profile
- current folder mapping
- signal types and routing owners
- non-overlap rule
- operator gate
- relation to Meru, OpenClaw, `.claude/skills`, TeamForge, and Paperclip

Also fix stale path references while touching these docs.

**Step 4: Run test to verify it passes**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_docs.sh
```

Expected: PASS, docs updated.

**Step 5: Commit**

```bash
git add 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/memory/reflective-signal-lane.md \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/memory/architecture.md \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/memory/twc-vault-integration.md \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/memory/openclaw-integration.md
git commit -m "docs: define reflective signal lane control pattern"
```

### Task 7: Add a first-run backfill and operator brief from current drift evidence

**Files:**
- Modify: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/signal-lane-scan.sh`
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_backfill.sh`
- Create: `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/vault/leadership/signal-lane/README.md`

**Step 1: Write the failing test**

Create `tests/test_signal_lane_backfill.sh` to assert that a first `scan --backfill-current-drift` run produces:

- at least one `ready` or `candidate` signal
- one `daily-brief.md`
- one `signal-board.md`

**Step 2: Run test to verify it fails**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_backfill.sh
```

Expected: FAIL because backfill mode does not exist yet.

**Step 3: Write minimal implementation**

Add a one-shot operator bootstrap:

```bash
./scripts/signal-lane-scan.sh scan --backfill-current-drift --dispatch
```

The first run should deliberately collapse the current known failures into a bounded set of intents:

- one runtime-root repair intent -> `clawd`
- one TeamForge recovery intent -> `clawd`
- one skill-normalization review intent -> `atlas`
- one task-registry reconciliation intent -> `sentinel`
- one operator arbitration summary -> `jarvis`

**Step 4: Run test to verify it passes**

Run:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_backfill.sh
```

Expected: PASS, bounded initial output set.

**Step 5: Commit**

```bash
git add 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/signal-lane-scan.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_backfill.sh \
        01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/vault/leadership/signal-lane/README.md
git commit -m "feat: add signal lane backfill bootstrap"
```

## Acceptance Criteria

- The repo enforces one canonical Paperclip runtime root before claiming health.
- `paperclip-cycle.sh` runs the signal lane deterministically after sync + reconcile.
- The signal lane notices the current real drift classes without calling any model.
- One signal identity yields at most one active intent task.
- The board exposes explicit middle states instead of binary queue/not-queue.
- The lane never writes product code or approves its own builds.
- Docs describe the lane as a control-plane pattern and remove stale root references.

## Verification Suite

Run all of these before claiming completion:

```bash
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_runtime_root_guard.sh
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_contract.sh
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_detection.sh
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_gating.sh
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_paperclip_cycle_signal_lane.sh
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_docs.sh
bash 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/tests/test_signal_lane_backfill.sh
bash -n 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/scripts/*.sh
jq empty 01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/.thoughtseed/signal-lane/state.json
```

## First Execution Order

Do not start with "subconscious" language or any new agent profile. Execute in this order:

1. runtime-root guard
2. signal-lane state contract
3. recurrent-drift detection
4. sync-key gating
5. cycle integration
6. docs/path cleanup
7. one-shot backfill

Plan complete and saved to `01-Projects/tryambakam-noesis/tryambakamnoesis-paperclip/docs/plans/2026-04-19-reflective-signal-lane-implementation.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
