# Loop-Runner PID Drift Hardening

Date: 2026-04-22  
Owner: CLAWD

## Scope

Harden `scripts/loop-runner.sh` daemon controls so operations do not rely solely on `.thoughtseed/loop-runner.pid`.

Observed failure mode:

- stale or drifted PID file did not represent actual long-running `loop-runner.sh run` processes
- `start` could launch additional runners in drift scenarios
- `stop` could terminate one runner while duplicates persisted

## Implementation

Updated `scripts/loop-runner.sh` with process-aware daemon controls:

- added `loop_runner_process_pids` to discover live runner processes by command signature
- added `collect_loop_runner_pids` to merge PID-file owner + discovered runner PIDs
- filtered discovered runner PIDs to top-level daemon roots (exclude per-agent child worker shells)
- updated `claim_pid_file` to reject startup when another live runner exists (even if PID file is stale)
- updated `start_daemon` to reconcile against live runners before launch and self-heal PID file
- updated `show_status` to report reconciled live runner PID set
- fixed signal handling (`TERM`/`INT`) so daemons exit after cleanup instead of swallowing stop signals
- updated `stop_daemon` to terminate all discovered runner roots, then re-check process table for immediate supervisor respawns and report survivors clearly

## Verification

- `bash -n scripts/loop-runner.sh`
- `./scripts/loop-runner.sh start` (correctly refuses when already running)
- `./scripts/loop-runner.sh status` (reports reconciled live PID set)
- `./scripts/loop-runner.sh stop` (kills duplicate runners and warns on survivors)

## Operational Notes

- On externally supervised hosts, one runner may legitimately survive stop attempts due to immediate respawn by supervisor policy.
- This is now surfaced as an explicit warning rather than a false clean-stop message.
