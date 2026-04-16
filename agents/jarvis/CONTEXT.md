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
