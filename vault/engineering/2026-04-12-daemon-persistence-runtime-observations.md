# Daemon Persistence Runtime Observations

Date: 2026-04-12
Owner: CLAWD

## Summary

`loop-runner` and `babysitter` behaviors are now script-hardened for common internal failures (signal-interrupted sleeps, stderr structured-output fallback, retry cooldowns), but processes are still observed as dead/stale after command-session boundaries in this execution runtime.

## What Was Verified

1. `loop-runner` can remain alive for >120s and up to ~480s in controlled soak runs.
2. `babysitter` no longer exits immediately on max respawns; it now rate-limits retries with cooldown and remains alive during active stress commands.
3. Despite (1) and (2), both daemons can later appear as stale with no corresponding internal fatal log line, suggesting external process reaping beyond script control.

## Evidence

- During active tests, status showed:
  - `Babysitter: RUNNING (PID 3030)`
  - `Loop Runner: RUNNING (PID 12187)`
- After a later delayed status check from a new command session, both appeared stale:
  - `Babysitter: DEAD (stale PID) (PID 3030)`
  - `Loop Runner: DEAD (stale PID) (PID 12187)`
- `logs/babysitter.log` ended at cooldown messages (no script-side fatal exit trace after that point).

## Engineering Interpretation

Most likely cause is environment/supervisor lifecycle constraints (detached shell children being reaped when command sessions terminate), not a single deterministic script crash path.

## Recommended Next Step

Move daemon supervision to a host-native long-lived supervisor (launchd/systemd/pm2) instead of relying on `nohup ... &` from transient command sessions.
