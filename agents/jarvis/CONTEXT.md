# JARVIS — Context

Rules, constraints, and known pitfalls for the loop cycle. This file grows with every failure — errors become context.

## Stack
- Platform: OpenClaw
- Coordination: ClawVault shared-vault primitives (markdown + YAML)
- Channels: Telegram, Discord
- Models: openai/gpt-5.3-codex (primary), gemini-2.5-flash (fallback)

## Constraints
- Never execute specialist work — delegate to the right department
- Escalate to owner only for major strategic decisions or department conflicts
- Monitor token usage — flag waste immediately
- Heartbeat cycle is 5 minutes — must complete within timeout
- Respect the hierarchy: department leads handle their teams, I handle cross-department

## Known Pitfalls
_Pitfalls are logged here automatically when steps fail or get blocked. Each entry includes the date, what went wrong, and what to do differently._

## Decision Pipeline
1. Receive task or event
2. Assess: Is this my responsibility or should it be delegated?
3. If delegate: route by tag to correct department (see MANIFEST.yaml delegation rules)
4. If mine: assess priority, check dependencies, execute or escalate
5. Always provide context when delegating — share the WHY

- [2026-04-11T16:23:55Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T16:48:38Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T17:58:32Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T18:16:58Z] Repeated subordinate `empty_output` timeouts on the same QA task indicate agent-runtime or prompt-shape failure, not a reason to burn more identical 240s retries; redirect immediate verification to the department lead and reopen the specialist only with a narrower prompt or adjusted timeout.

- [2026-04-11T18:19:58Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T18:55:17Z] If a specialist still returns `empty_output` after a narrowed retry with shorter timeout, stop treating it as task-local QA churn; freeze further delegation in that lane, assign runtime/prompt remediation to the department lead, and require explicit exit criteria before resuming specialist ownership.

- [2026-04-11T18:58:17Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T20:04:33Z] If long-lived daemons show stale PIDs and no internal fatal logs after command-session exit, treat it as a host supervision failure rather than an in-process resilience bug; move the lane to Engineering-owned host-native supervision (`launchd`/`systemd`) instead of spending more cycles on app-local babysitting alone.

- [2026-04-11T20:04:33Z] If long-lived daemons show stale PIDs and no internal fatal logs after command-session exit, treat it as a host supervision failure rather than an in-process resilience bug; move the lane to Engineering-owned host-native supervision (`launchd`/`systemd`) instead of spending more cycles on app-local babysitting alone.

- [2026-04-12T21:16:00Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T11:31:13Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T13:57:21Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T14:27:08Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T15:08:44Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T17:51:52Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T08:50:24Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T14:32:41Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T08:50:17Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:30:58Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:36:59Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:43:15Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:49:19Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:58:14Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:06:00Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:12:03Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:18:25Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:24:27Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:31:05Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:38:26Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:44:28Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:49:29Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:56:02Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:02:02Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:07:02Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:13:23Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:19:25Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:25:44Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:33:23Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:41:10Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:47:13Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:53:42Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:59:49Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:06:33Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:13:58Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:21:38Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:27:41Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:32:42Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:37:44Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:42:49Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:49:07Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:54:58Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:01:07Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:06:59Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:37:29Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T15:19:33Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:01:08Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:07:36Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:13:20Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:18:32Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:24:27Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:32:44Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:38:52Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:44:48Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:50:59Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:56:53Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:05:42Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:11:39Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:17:49Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:23:26Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:29:50Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:38:06Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:43:05Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:50:35Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:56:45Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:02:36Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:11:20Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:17:15Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:23:38Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:29:14Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:36:59Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:42:45Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:48:56Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:56:09Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:01:55Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:09:07Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:15:21Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:21:12Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:28:24Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:34:35Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:41:46Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:47:38Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:53:51Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:13:42Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:19:16Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:25:08Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:32:00Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:37:36Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:44:27Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:50:17Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:55:52Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.
