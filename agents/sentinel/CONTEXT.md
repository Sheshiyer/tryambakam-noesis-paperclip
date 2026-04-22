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

- [2026-04-20T08:16:27Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T08:25:14Z] `signal-lane-scan.sh` can miss real registry/task drift because `task_registry_drift` only checks registry age plus pending count. Fresh writes can clear the signal even when per-task statuses still disagree with agent `TASKS.md` / processed inbox state, and fixture-based dispatch can leave stale review intents behind live repairs.

- [2026-04-20T08:27:15Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T09:36:32Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T11:29:34Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T14:36:26Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T15:07:40Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T15:18:38Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T08:34:59Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:31:59Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:43:15Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:54:14Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:04:18Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:14:23Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:24:27Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:36:07Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:47:06Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:58:22Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:09:21Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:19:25Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:31:03Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:42:11Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:52:22Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:02:29Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:12:38Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:22:38Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:32:42Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:42:49Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:53:57Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:04:42Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:26:31Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:37:29Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:57:56Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T15:20:55Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T15:44:15Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T16:04:27Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T16:34:19Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T16:57:32Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:08:36Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:19:49Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:30:23Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:41:10Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:52:00Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:03:22Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:14:11Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:25:01Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:35:46Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:46:58Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:57:46Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:08:46Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:19:32Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:32:13Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:42:45Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:53:45Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:04:19Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:15:21Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:25:59Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:36:59Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:47:38Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:09:07Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:19:16Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:29:42Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:39:53Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:50:16Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T10:00:31Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T10:45:58Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.
