# CLAWD — Tasks

Step-by-step work queue. The loop reads this file each cycle to pick the next incomplete step.

## Active Tasks

_No active tasks._

## Task Format

Each task follows this structure:
- **Step N**: [description]
  - Status: open | in-progress | blocked | done | failed
  - Priority: critical | high | medium | low
  - Tags: [comma-separated tags]
  - Blocked reason: (if blocked — WHY specifically)
  - Retry count: 0
  - Depends on: (step IDs if any)
  - Result: (written after completion or failure)

## Completed Tasks

- **Step 6**: Evaluate host-native supervision migration for `loop-runner` and `babysitter` and return engineering recommendation
  - Status: done
  - Priority: medium
  - Tags: ops, infra
  - Retry count: 0
  - Depends on: task-1775936805-00e9
  - Result: Confirmed the repo already implements host-native supervision in `scripts/host-supervisor.sh`, verified live macOS LaunchAgents via `./scripts/host-supervisor.sh status` and `launchctl print gui/$(id -u)/com.thoughtseed.loop-runner` / `launchctl print gui/$(id -u)/com.thoughtseed.babysitter`, and documented the supervisor choice, migration steps, restart/health semantics, stale-PID cleanup, verification proof, and remaining tradeoffs in `vault/engineering/2026-04-12-host-supervisor-migration-and-verification.md` with supporting runtime observations in `vault/engineering/2026-04-12-daemon-persistence-runtime-observations.md`.

- **Step 5**: Build SENTINEL QA handoff remediation package and suspend unsafe delegation lane
  - Status: done
  - Priority: medium
  - Tags: ops, qa
  - Retry count: 0
  - Depends on: task-1775933717-b3f4c
  - Result: Identified the no-output failure mode (`--output-last-message` empty with structured markers still present on stderr), implemented runtime fallback recovery in `scripts/loop-runner.sh`, documented the remediation package and QA delegation policy at `vault/engineering/2026-04-11-sentinel-qa-runtime-remediation-package.md`, and set explicit exit criteria for resuming SENTINEL ownership of this QA lane.

- **Step 4**: Verify loop-runner signal-safe sleep fix and execute fail-fast QA retry strategy
  - Status: done
  - Priority: medium
  - Tags: ops, qa
  - Retry count: 1
  - Depends on: task-1775931418-b2d1
  - Result: Verified daemon stability directly in Engineering (`./scripts/loop-runner.sh start` followed by 30-second checks through 240 seconds, all RUNNING; PID 33808). Re-opened SENTINEL with a narrower QA task (`task-1775932448-81fa`) and reduced SENTINEL `max_step_timeout` to `2m` for fail-fast behavior; SENTINEL still returned `empty_output` timeout at 120s, so the retry task was marked failed and escalated to JARVIS as `task-1775932882-6be7`.

- **Step 3**: Sync THO-1 engineering package and move issue to founder review
  - Status: done
  - Priority: high
  - Tags: ops, strategy
  - Retry count: 0
  - Depends on: task-1775914956-5023
  - Result: Updated Paperclip issue `THO-1` (`9ca2a2fd-9b2a-4ed7-92c7-d3ca2835f172`) to `in_review` via authenticated API mutation using runtime `PAPERCLIP_RUN_ID`, and posted founder-review handoff comment `13e5cd5a-4a1a-4fea-8b75-1bedbf7edf16` summarizing delivered engineering artifacts and explicit founder-only decisions.

- **Step 1**: Create engineering hiring plan and roadmap decomposition
  - Status: done
  - Priority: high
  - Tags: strategy
  - Retry count: 0
  - Depends on: task-1775918684-a857
  - Result: Completed delegated task `task-1775923170-ec65` and created `vault/engineering/2026-04-11-engineering-hiring-plan-and-roadmap.md` with the hiring sequence, interview loop, 30/60/90 expectations, phase-based roadmap decomposition, and explicit hiring triggers.

- **Step 2**: Investigate Paperclip auth regression: CLAWD local-cli returns 403 Board access required
  - Status: done
  - Priority: high
  - Tags: ops
  - Retry count: 0
  - Depends on: task-1775917911-21cb
  - Result: Using existing Paperclip server logs plus CLI source, traced the `403` to `paperclipai agent local-cli` inheriting the agent runtime `PAPERCLIP_API_KEY` and authenticating as CLAWD against the board-only `/api/agents/:id/keys` route. Wrote the diagnosis and workaround to `vault/engineering/2026-04-11-paperclip-local-cli-auth-regression.md`.
