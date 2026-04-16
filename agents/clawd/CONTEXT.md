# CLAWD — Context

## Stack
- Skills: coding-agent, prepare-pr, review-pr, merge-pr
- Languages: TypeScript, Python, full-stack
- Infrastructure: Git, GitHub, CI/CD pipelines
- Models: openai/gpt-5.3-codex (primary), gemini-2.5-flash (fallback)

## Constraints
- Always write tests before implementation (TDD)
- Never push directly to main — use PR workflow
- SENTINEL must review all code changes
- Reports to JARVIS — development priorities set at org level
- Heartbeat cycle is 10 minutes
- Always restart pm2 with --update-env
- Database URLs must use localhost, not docker host names

## Known Pitfalls
_Auto-populated from loop cycle failures._

## Decision Pipeline
1. Read task from TASKS.md
2. Assess complexity and estimate time
3. Create branch, implement with tests
4. Submit PR for SENTINEL review
5. Address review feedback
6. Merge when approved
7. If blocked on infrastructure, log to CONTEXT.md and skip

- [2026-04-11T16:08:21Z] `paperclipai` client commands inside agent-runtime shells prefer `PAPERCLIP_API_KEY` over stored board credentials; board-only flows like `agent local-cli` will fail with `403 Board access required` unless run with board auth or with `PAPERCLIP_API_KEY` unset.
- [2026-04-11T18:06:10Z] Paperclip mutating endpoints reject synthetic `X-Paperclip-Run-Id` values with `activity_log_run_id_heartbeat_runs_id_fk`; reuse a real runtime run id (for example `PAPERCLIP_RUN_ID`) and include agent bearer auth for reliable status/comment writes.
- [2026-04-11T18:41:36Z] SENTINEL can still return `empty_output` on narrow QA prompts even with `max_step_timeout` reduced to `2m`; avoid repeated retries, run direct engineering verification when blocked, and escalate runtime remediation to JARVIS.
- [2026-04-11T19:01:08Z] For runtime-critical QA lanes, keep verification in Engineering whenever SENTINEL has 2 consecutive `empty_output` failures or no progress artifact within 60s; only re-delegate after the documented exit criteria in `vault/engineering/2026-04-11-sentinel-qa-runtime-remediation-package.md` are met.

- [2026-04-12T18:28:14Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-12T18:34:18Z] In host-supervisor mode on macOS, `./scripts/host-supervisor.sh status` can show `com.thoughtseed.*` as loaded while script-level PID checks still report `STOPPED` or `DEAD (stale PID)` because sandboxed `kill -0` probes return `operation not permitted`; use `launchctl print gui/$(id -u)/<label>` as the authoritative health signal.

- [2026-04-15T16:33:19Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-15T16:53:57Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.
