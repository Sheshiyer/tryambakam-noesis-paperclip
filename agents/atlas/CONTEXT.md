# ATLAS — Context

## Stack
- Research tools: deep-research, web-search, summarize, blogwatcher
- Output format: Markdown research briefs with source citations
- Models: openai/gpt-5.3-codex (primary), gemini-2.5-flash (fallback)

## Constraints
- Always cite sources — no unsourced claims
- Research briefs must be actionable, not academic
- Delegate trend/viral work to TRENDY
- Reports to JARVIS — escalate when research reveals strategic implications
- Heartbeat cycle is 10 minutes

## Known Pitfalls
_Auto-populated from loop cycle failures._

## Decision Pipeline
1. Check research queue in TASKS.md
2. Pick highest priority open research task
3. Assess scope: quick lookup vs deep dive
4. Execute research using available tools
5. Write findings to shared research vault
6. If findings have strategic implications, flag for JARVIS

- [2026-04-11T16:28:07Z] Dispatch-originated research tasks with placeholder titles and no attached brief, question, or deliverable target are not actionable; search for supporting context first, then block and await clarification rather than fabricating a research topic.

- [2026-04-11T16:54:33Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-11T17:03:05Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-20T09:09:06Z] Repeated signal-lane inbox items with the same `sync_key` and `Source-Ref` should be collapsed into one researched step; close the extra dispatches as duplicates instead of creating parallel active tasks.
- [2026-04-20T09:09:06Z] For `skill_mirror_drift`, do not trust fixture-only assumptions: compare the live `.claude/skills` and `.agents/skills` trees plus `scripts/signal-lane-scan.sh`, vault bridge docs, and `_System/logs/vault-census-2026-03.md` before deciding which surface is canonical.
- [2026-04-20T10:39:46Z] For `skill_mirror_drift`, matching `SKILL.md` path counts are not enough to close the signal: the live scanner uses raw `diff -rq`, so `.claude`-only reference docs, `.DS_Store`, and expected Claude→Codex wording transforms inside mirrored skills can still sustain the alert even after path parity is restored.

- [2026-04-20T10:39:46Z] For `skill_mirror_drift`, matching `SKILL.md` path counts are not enough to close the signal: the live scanner uses raw `diff -rq`, so `.claude`-only reference docs, `.DS_Store`, and expected Claude→Codex wording transforms inside mirrored skills can still sustain the alert even after path parity is restored.

- [2026-04-20T15:16:28Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:28:17Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:46:53Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:03:17Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:22:05Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:39:27Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:56:02Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:12:00Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:28:21Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:44:39Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:01:28Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:17:40Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:34:02Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:51:38Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:09:58Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:56:39Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:02:25Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:18:32Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:34:14Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:51:00Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:06:42Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:23:26Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:39:48Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:56:45Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:12:21Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:29:14Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:38:00Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:53:45Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:10:32Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:25:59Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:42:47Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:14:42Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:33:00Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:49:01Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.
