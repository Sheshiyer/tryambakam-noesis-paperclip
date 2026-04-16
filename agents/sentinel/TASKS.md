# SENTINEL — Tasks

Step-by-step work queue. The loop reads this file each cycle to pick the next incomplete step.

## Active Tasks

_No active tasks._

## Task Format

Each task follows this structure:
- **Step N**: [description]
  - Status: open | in-progress | blocked | done | failed
  - Priority: critical | high | medium | low
  - Blocked reason: (if blocked — WHY specifically)
  - Retry count: 0
  - Depends on: (step IDs if any)
  - Result: (written after completion or failure)

## Completed Tasks

- **Step 3**: QA review: assignee-aware Paperclip sync and blocked-issue skip behavior
  - Status: done
  - Priority: medium
  - Tags: qa
  - Task-ID: task-1775916033-a905
  - Retry count: 0
  - Depends on: —
  - Result: QA review completed with isolated mock-harness verification. Confirmed `scripts/paperclip-sync.sh sync-issues` routes issues with a mapped `assigneeAgentId` directly to the mapped local agent, falls back to tag routing when the mapped `urlKey` is not a local agent directory, and skips upstream `blocked` issues without dispatching them. Also confirmed `scripts/paperclip-reconcile-local.sh` updates existing Paperclip-backed local tasks to `blocked` and prunes their pending inbox entries when the upstream issue becomes terminal. No blocking issues found.

- **Step 2**: QA review: loop-runner Paperclip cycle integration + new paperclip-cycle subcommand
  - Status: done
  - Priority: medium
  - Tags: qa
  - Task-ID: task-1775918697-7ff8
  - Retry count: 0
  - Depends on: —
  - Result: QA review completed with isolated mock-harness verification. Confirmed `scripts/loop-runner.sh paperclip-cycle` returns success/failure correctly, passes `--with-heartbeats` from manifest config, exposes the new subcommand in help output, and that `scripts/loop-runner.sh run` invokes the Paperclip cycle on schedule. Found one robustness issue to escalate to CLAWD: `REPO_ROOT=<harness> bash scripts/loop-runner.sh run` with zero discovered agents exits at `scripts/loop-runner.sh:162` because `${#AGENT_TIERS[@]}` is treated as unbound under `set -u`.

- **Step 1**: QA review: paperclip-cron manager + stale lock recovery in paperclip-cycle
  - Status: done
  - Priority: medium
  - Tags: qa
  - Task-ID: task-1775919563-b5db
  - Retry count: 0
  - Depends on: —
  - Result: QA review completed with isolated mock-harness verification. Confirmed stale-lock recovery and active-lock skip behavior in `scripts/paperclip-cycle.sh`, and verified `scripts/paperclip-cron.sh` install/status/uninstall, idempotent managed-block upsert, and `run-now` execution/logging. No blocking issues found.
