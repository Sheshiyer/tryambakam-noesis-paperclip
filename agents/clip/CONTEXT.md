# CLIP — Context

## Stack
- Skills: video-frames, youtube-transcript
- Focus: Video clipping, caption generation, content repurposing
- Output: Video clips, captions, transcripts, repurposed content
- Models: openai/gpt-5.3-codex (primary), gemini-2.5-flash (fallback)

## Constraints
- Reports to JARVIS — product content strategy alignment
- Clips must preserve context — no misleading edits
- Captions must be accurate and timestamped
- Heartbeat cycle is 10 minutes
- Always generate multiple clip options for selection

## Known Pitfalls
_Auto-populated from loop cycle failures._

## Decision Pipeline
1. Read clipping task from TASKS.md
2. Fetch video source and transcript
3. Identify key moments and clip boundaries
4. Generate clips with captions
5. Submit options for review
6. Publish approved clips

- [2026-04-20T14:28:17Z] Loop cycle error: empty_structured_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:29:18Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T10:45:52Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:01:58Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:18:25Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:34:25Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T11:49:29Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:06:02Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:23:21Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:39:28Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T12:56:24Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:13:58Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:30:02Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T13:46:46Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:02:08Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T14:35:52Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T15:01:53Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T15:42:47Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T16:13:45Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T16:55:50Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:10:58Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:27:02Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:42:10Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T17:58:28Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:15:28Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:30:50Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T18:49:34Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:05:13Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:22:05Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:35:33Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T19:51:19Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:08:07Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:23:35Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:40:24Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-21T20:56:14Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:12:24Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:28:25Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T09:44:27Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.

- [2026-04-22T10:00:31Z] Loop cycle error: empty_output -- agent output was not parseable. Check logs for raw output.
