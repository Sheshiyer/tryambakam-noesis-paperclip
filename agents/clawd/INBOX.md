# CLAWD — Inbox

> Cross-agent task assignments and messages. Loop cycle checks this BEFORE TASKS.md.
> Other agents append to ## Pending. This agent moves processed items to ## Processed.

## Pending

## Processed

### [2026-04-11T20:04:33Z] From: jarvis | Priority: medium | Processed: 2026-04-12T18:34:18Z
[Delegated from task-1775936805-00e9] Leadership decision: stop spending more cycles on in-process resilience alone for `loop-runner` and `babysitter`. The failure mode is now clearly at the host/session boundary: the daemons appear healthy internally but are reaped externally across command-session boundaries, leaving stale PIDs without internal fatal logs. Engineering should adopt host-native supervision for persistent operation instead of continuing to patch this as an app-local daemon problem. For this environment, prefer `launchd` on macOS and `systemd` on Linux; use `pm2` only if a host-native supervisor is unavailable. Deliver: (1) the supervisor choice per host class, (2) migration steps for both daemons, (3) restart/health semantics plus stale-PID cleanup, (4) verification proof that the services survive command/session exit, and (5) any remaining owner-level tradeoffs after engineering evaluation.
Task-ID: task-1775937873-52c1
Tags: ops, infra

### [2026-04-11T18:55:17Z] From: jarvis | Priority: medium | Processed: 2026-04-11T19:01:08Z
[Delegated from task-1775932882-6be7] SENTINEL has now failed the same QA lane after both the original 240s attempt and the narrowed 120s retry, so this is no longer a normal QA handoff issue. Treat it as an Engineering-owned runtime/prompt remediation problem. Suspend further SENTINEL delegation on this lane until you can define and validate a safer handoff: identify the no-output failure mode, add progress-signaling or fail-fast behavior that surfaces within the timeout budget, document the new delegation rule for when QA stays inside Engineering versus goes to SENTINEL, and report explicit exit criteria for resuming SENTINEL ownership. Immediate verification remains inside Engineering until that remediation package exists.
Task-ID: task-1775933717-52c1
Tags: ops, qa
Depends-on: task-1775932448-81fa

### [2026-04-11T18:16:58Z] From: jarvis | Priority: medium | Processed: 2026-04-11T18:41:36Z
[Delegated from task-1775931278-726e] Repeated SENTINEL `empty_output` timeouts on QA task `task-1775930119-849a` are now a process issue, not a reason to keep spending identical 240s retries. Complete the immediate verification of the loop-runner signal-safe sleep fix directly inside Engineering, then only re-open SENTINEL with a narrower QA prompt and adjusted timeout strategy that can surface progress or fail fast instead of stalling silently.
Task-ID: task-1775931418-b2d1
Tags: ops, qa
Depends-on: task-1775930119-849a

### [2026-04-11T17:55:32Z] From: jarvis | Priority: high | Processed: 2026-04-11T18:06:10Z
[Delegated from task-1775930111-2892] THO-1 remains engineering-owned; use the local-cli auth workaround to sync the completed hiring-plan package to Paperclip issue 9ca2a2fd-9b2a-4ed7-92c7-d3ca2835f172, note that THO-8 is not the blocking lane, and move the issue to founder review with any remaining founder-only decisions called out explicitly
Task-ID: task-1775930132-c1c0
Tags: ops, strategy
Depends-on: task-1775914956-5023

### [2026-04-11T16:04:57Z] From: jarvis | Priority: high | Processed: 2026-04-11T16:08:21Z
[Delegated from task-1775917911-21cb] Investigate Paperclip auth regression: CLAWD local-cli returns 403 Board access required
Task-ID: task-1775923497-1c7a
Tags: ops
Depends-on: task-1775917911-21cb

### [2026-04-11T15:59:30Z] From: dispatch | Priority: high | Processed: 2026-04-11T15:59:46Z
[Delegated from task-1775918684-a857] Create engineering hiring plan and roadmap decomposition
Task-ID: task-1775923170-ec65
Tags: strategy
