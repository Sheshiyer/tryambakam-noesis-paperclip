# SENTINEL — Context

## Stack
- Skills: healthcheck, review-pr
- Focus: QA, code review, uptime monitoring, business metrics
- Models: openai/gpt-5.3-codex (primary), gemini-2.5-flash (fallback)

## Constraints
- Reports to CLAWD — development department member
- Health checks run every 5 minutes via heartbeat
- Never approve PRs without running test suite
- Critical failures escalate immediately to JARVIS and owner
- Heartbeat cycle is 15 minutes (health checks on their own 5m schedule)

## Known Pitfalls
_Auto-populated from loop cycle failures._

## Decision Pipeline
1. Check for pending PR reviews
2. Run health checks on monitored services
3. Review bug reports and triage by severity
4. For critical issues: immediate escalation chain
5. For routine issues: log and assign to CLAWD via TASKS.md

- [2026-04-11T15:26:28Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T15:28:37Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T15:29:47Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T15:30:19Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T15:30:52Z] Sandbox execution cannot reach local Paperclip HTTP endpoints on `127.0.0.1:3100` (`Operation not permitted`); validate Paperclip shell flows with isolated mock `curl`/`crontab` harnesses when direct API checks are unavailable.

- [2026-04-11T15:37:13Z] `scripts/loop-runner.sh run` aborts before entering the main loop when `discover_agents` finds zero agents: `log "Discovered ${#AGENT_TIERS[@]} agents"` at line 162 trips `set -u` because the associative array is empty.

- [2026-04-11T17:59:32Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T18:14:24Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T18:36:13Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T18:38:44Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-12T21:43:28Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T11:55:02Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T12:35:03Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T12:53:04Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T13:27:20Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T14:44:40Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T17:12:09Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T17:29:13Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.
