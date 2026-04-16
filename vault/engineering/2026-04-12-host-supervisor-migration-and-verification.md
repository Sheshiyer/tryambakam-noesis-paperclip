# Host-Native Supervisor Migration and Verification

Date: 2026-04-12
Owner: CLAWD
Task: task-1775937873-52c1

## Decision

Use host-native supervision for persistent daemon operation:

| Host class | Chosen supervisor | Why |
| --- | --- | --- |
| macOS user workstation | `launchd` LaunchAgents | Native lifecycle manager, survives shell/session exit, already implemented in `scripts/host-supervisor.sh` |
| Linux user workstation/server | `systemd --user` services | Native lifecycle manager with restart policy and journaled status |
| Host without usable `launchd`/`systemd` | `pm2` fallback only | Better than `nohup ... &`, but not the preferred control plane |

`pm2` is not the primary answer for Thoughtseed. The right default is encoded in `scripts/host-supervisor.sh`.

## Current Engineering State

The repo already contains the host-supervisor wrapper:

- `scripts/host-supervisor.sh` writes and manages:
  - macOS `~/Library/LaunchAgents/com.thoughtseed.loop-runner.plist`
  - macOS `~/Library/LaunchAgents/com.thoughtseed.babysitter.plist`
  - Linux `~/.config/systemd/user/thoughtseed-loop-runner.service`
  - Linux `~/.config/systemd/user/thoughtseed-babysitter.service`
- Both service definitions inject:
  - `REPO_ROOT`
  - `THOUGHTSEED_SUPERVISOR_MODE=host`
  - explicit `PATH`
- `babysitter.sh` already has host-mode behavior: in host mode it stops self-respawning the loop runner and waits for the host supervisor to do the restart.

This means the engineering lane is no longer "design the solution." It is "standardize the cutover and treat the host supervisor as the source of truth."

## Migration Steps

### macOS

1. Stop legacy shell-started daemons:
   - `./scripts/babysitter.sh stop`
   - `./scripts/loop-runner.sh stop`
2. Clean stale PID files if either script reports dead/stale:
   - `.thoughtseed/babysitter.pid`
   - `.thoughtseed/loop-runner.pid`
3. Install and start host-native services:
   - `./scripts/host-supervisor.sh install`
4. Verify supervisor state:
   - `launchctl print gui/$(id -u)/com.thoughtseed.loop-runner`
   - `launchctl print gui/$(id -u)/com.thoughtseed.babysitter`
5. Use `./scripts/host-supervisor.sh status` for the combined view, but treat `launchctl print` as authoritative if script-level PID checks disagree inside sandboxed shells.

### Linux

1. Stop legacy shell-started daemons:
   - `./scripts/babysitter.sh stop`
   - `./scripts/loop-runner.sh stop`
2. Clean stale PID files if needed.
3. Install and start host-native services:
   - `./scripts/host-supervisor.sh install`
4. Verify supervisor state:
   - `systemctl --user status thoughtseed-loop-runner.service`
   - `systemctl --user status thoughtseed-babysitter.service`
5. If these services must survive logout, enable lingering for the service user:
   - `loginctl enable-linger <user>`

## Restart, Health, and Stale-PID Semantics

### Authoritative health source

- In host mode, `launchd`/`systemd` is the authoritative liveness signal.
- Script-local PID files are a convenience layer, not the primary health contract.

### Restart behavior

- `launchd` units use `KeepAlive=true` and `RunAtLoad=true`.
- `systemd` units use `Restart=always` and `RestartSec=5`.
- `babysitter.sh` in host mode does not continuously self-respawn the loop runner. It logs and waits for the host supervisor restart path.

### Stale-PID cleanup

- `loop-runner.sh stop` removes a stale PID file if the recorded PID is not alive.
- `loop-runner.sh claim_pid_file` removes stale PID files before foreground ownership.
- `babysitter.sh start`, `stop`, and `claim_pid_file` all perform stale-PID cleanup before taking ownership.
- Recommended cutover rule:
  - stop legacy daemons first,
  - remove stale PID files,
  - then hand control to the host supervisor.

## Verification Evidence

This cycle verified the host-native services from fresh command invocations.

### Supervisor-level evidence

`./scripts/host-supervisor.sh status` reported:

- `com.thoughtseed.loop-runner: loaded`
- `com.thoughtseed.babysitter: loaded`

Direct `launchctl print` inspection reported both labels as active LaunchAgents:

- `com.thoughtseed.loop-runner`
  - `state = running`
  - `active count = 1`
  - `pid = 81898`
- `com.thoughtseed.babysitter`
  - `state = running`
  - `active count = 1`
  - `pid = 969`

That is the proof that the services are being managed independently of the transient shell that originally invoked the loop cycle.

### Sandbox limitation observed during verification

Inside this Codex runtime, direct host-process interrogation is restricted:

- `kill -0 81898` returned `operation not permitted`
- `launchctl kickstart -k gui/$(id -u)/com.thoughtseed.loop-runner` returned `operation not permitted`
- `launchctl kickstart -k gui/$(id -u)/com.thoughtseed.babysitter` returned `operation not permitted`

As a result, script-level status that relies on `kill -0` can report false negatives inside the sandbox even while `launchctl` shows the service as loaded/running.

This is an observability mismatch, not evidence that host-native supervision is the wrong strategy.

## Remaining Tradeoffs

These are the only owner-level choices left after engineering evaluation:

1. Keep `babysitter` as a second logical monitor, or simplify later to host supervisor plus loop runner only.
   - Recommendation: keep it for now because the host-mode path is already implemented and low risk.
   - Later simplification is reasonable once the host-supervisor cutover has been stable for a full operating window.

2. Decide whether to invest a follow-up in host-aware status reporting.
   - Recommendation: yes, small follow-up.
   - Reason: `host-supervisor.sh status` should prefer `launchctl print` / `systemctl --user status` in host mode instead of relying only on sandbox-sensitive `kill -0`.

3. On Linux, decide whether logout survival is required.
   - If yes, enable `systemd --user` lingering.
   - If no, the current per-user service model is sufficient.

4. On macOS, decide whether per-user LaunchAgents are sufficient or whether a system LaunchDaemon is needed.
   - Recommendation: LaunchAgent is correct for this repo today because the workflow expects the logged-in user environment and user-scoped credentials.

## Engineering Conclusion

The strategic call is correct:

- macOS -> `launchd`
- Linux -> `systemd --user`
- `pm2` only as fallback

The remaining gap is not "what supervisor should we use." The remaining gap is "make host-mode status reporting authoritative and less PID-file-centric inside sandboxed agent shells."
