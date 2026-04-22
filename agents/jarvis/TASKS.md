# JARVIS — Tasks

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

- **Step 7**: Set Clockify TeamForge backlog-shaping policy and assign cleanup execution
  - Status: done
  - Priority: medium
  - Tags: ops, strategy
  - Retry count: 0
  - Depends on: batch-2026-04-20-clockify-backlog
  - Result: Classified the 197 `clockify.time_entry.logged` items as low-severity telemetry rather than actionable ops work. Set policy to keep raw Clockify info signals visible in active TeamForge surfaces for 14 days, collapse duplicates into a single aggregate per event type/day, and auto-archive older low-severity backlog from active queues while preserving auditability in `sync-state.json` and `task-registry.json`. Delegated implementation to `agents/clawd/INBOX.md` as `task-1776674844-a3f2`, keeping Engineering accountable for cleanup, automation, and verification that higher-severity signals remain unaffected.

- **Step 6**: Resolve CLAWD escalation on externally reaped `loop-runner` and `babysitter` daemons and decide whether persistent operation must move to host-native supervision
  - Status: done
  - Priority: medium
  - Tags: ops
  - Retry count: 0
  - Depends on: none
  - Result: Made the strategic call that this is no longer an app-local resilience lane. Delegated to `agents/clawd/INBOX.md` as `task-1775937873-52c1`, directing CLAWD to adopt host-native supervision for persistent daemons (`launchd` on macOS, `systemd` on Linux, `pm2` only as fallback), migrate `loop-runner` and `babysitter`, and return with restart/health semantics plus proof that the services survive command-session exit.

- **Step 5**: Resolve CLAWD escalation on persistent SENTINEL `empty_output` after the narrowed 120s QA retry and decide the remediation policy before further QA delegation
  - Status: done
  - Priority: medium
  - Tags: ops
  - Retry count: 0
  - Depends on: task-1775932448-81fa
  - Result: Declared the issue a department-level Engineering runtime/prompt remediation problem rather than a normal QA retry lane. Delegated to `agents/clawd/INBOX.md` as `task-1775933717-3f4c`, instructing CLAWD to suspend further SENTINEL delegation on this lane, keep immediate verification inside Engineering, and return with a bounded remediation package plus explicit exit criteria before SENTINEL owns QA again.

- **Step 4**: Resolve QA escalation for `task-1775930119-849a` after repeated SENTINEL `empty_output` timeouts and decide whether to reassign QA or change the execution strategy
  - Status: done
  - Priority: medium
  - Tags: ops
  - Retry count: 0
  - Depends on: task-1775930119-849a
  - Result: Chose a token-preserving management path: do not keep SENTINEL on the same 240s no-output retry loop. Delegated to `agents/clawd/INBOX.md` as `task-1775931418-b2d1`, directing CLAWD to complete the immediate verification of the signal-safe sleep fix inside Engineering and only re-open SENTINEL with a narrower prompt and adjusted timeout strategy once the QA lane is stable enough to avoid further waste.

- **Step 3**: Resolve THO-1 ownership and next action for blocked Paperclip issue `9ca2a2fd-9b2a-4ed7-92c7-d3ca2835f172` so `task-1775914956-5023` can unblock
  - Status: done
  - Priority: high
  - Tags: ops
  - Retry count: 0
  - Depends on: task-1775914956-5023
  - Result: Resolved the cross-department ambiguity by declaring THO-1 engineering-owned under CLAWD, treating THO-8 as non-blocking for this lane, and delegating the next action to `agents/clawd/INBOX.md` as `task-1775930132-c1c0` to sync the completed hiring-plan package to Paperclip using the documented local-cli auth workaround and move the issue toward founder review.

- **Step 1**: Delegate `task-1775918684-a857` engineering hiring plan and roadmap decomposition to CLAWD
  - Status: done
  - Priority: high
  - Tags: strategy
  - Retry count: 0
  - Depends on: none
  - Result: Delegated to `agents/clawd/INBOX.md` with CTO context, strategic purpose, and a clear definition of done for the engineering hiring plan and roadmap decomposition.

- **Step 2**: Delegate `task-1775917911-21cb` Paperclip auth regression investigation to CLAWD
  - Status: done
  - Priority: high
  - Tags: ops
  - Retry count: 0
  - Depends on: none
  - Result: Delegated to `agents/clawd/INBOX.md` as `task-1775923497-1c7a`, preserving the original dependency and the specific `403 Board access required` regression for CLAWD to investigate.
