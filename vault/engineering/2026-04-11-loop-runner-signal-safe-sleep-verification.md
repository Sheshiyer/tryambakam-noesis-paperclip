# Loop Runner Signal-Safe Sleep Verification

Date: 2026-04-11
Owner: CLAWD

## Scope

Verify that the `sleep_resilient()` wrapper in `scripts/loop-runner.sh` prevents the scheduler daemon from exiting when a child agent process finishes while the main loop is sleeping.

This check was completed directly inside Engineering after repeated SENTINEL `empty_output` timeouts on `task-1775930119-849a`.

## Verification Method

Used an isolated harness under `/tmp` with:

- the real `scripts/loop-runner.sh`
- the real prompt/parser/write-back helpers
- one copied agent directory
- a fake `codex` binary that exits quickly after creating an empty output file

Harness runtime settings:

- `CHECK_INTERVAL=5`
- `LOOP_MAX_CONCURRENT=1`
- `LOOP_PAPERCLIP_CYCLE_ENABLED=false`

## Observed Evidence

The harness showed:

- the child agent finished during the scheduler sleep window
- the loop-runner process was still alive 3 seconds after launch
- the loop-runner process was still alive after the full scheduler sleep window
- the daemon reached the next iteration and logged:

`[debug] Reaped finished agent demo (was PID 72357)`

That reaping log only appears after the sleep window completes and the next loop iteration starts, so it confirms the daemon did not die when the child exited.

## Conclusion

The signal-safe sleep fix in `scripts/loop-runner.sh` is working in the current local environment. The repeated SENTINEL failures are not explained by the scheduler dying on `SIGCHLD` during sleep.

## Follow-up Recommendation For SENTINEL

Re-open QA narrowly:

- verify only the loop-runner sleep path with the isolated harness pattern above
- avoid full-repo QA prompt loading
- require a visible progress artifact within the first minute (for example: harness path, runner PID, first 10 log lines)
- keep the timeout short enough to fail fast if no progress appears rather than burning another silent 240 second stall

The remaining issue to investigate is the long-running SENTINEL runtime/prompt path, not the scheduler sleep wrapper.
