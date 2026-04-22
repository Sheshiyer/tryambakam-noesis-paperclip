# Loop-Runner Codex Notify Compatibility

Date: 2026-04-22  
Owner: CLAWD

## Scope

Restore agent-loop execution when `codex exec` aborts early due to legacy user config shape for `features.notify`.

Observed runtime failure in `logs/loop-runner.log`:

- `Error loading config.toml: invalid type: sequence, expected a boolean`
- `in features`

Impact:

- `codex exec` exits with code `1` before model execution.
- `--output-last-message` files stay empty.
- downstream parser emits `empty_output`, causing noisy parse-error heartbeat/context entries across agents.

## Root Cause

`codex-cli 0.121.0` expects `features.notify` to be a boolean feature flag.
Some legacy user configs still define it as an array command payload, which causes config parse failure during non-interactive `exec` runs.

## Implementation

Updated loop-runner invocation in `scripts/loop-runner.sh`:

- added `CODEX_FEATURES_NOTIFY_OVERRIDE` env control (default: `true`)
- injected compatibility override on every agent exec call:
  - `-c "features.notify=$CODEX_FEATURES_NOTIFY_OVERRIDE"`

This preserves local configurability while forcing a parseable boolean at runtime.

## Verification

- `bash -n scripts/loop-runner.sh`
- direct smoke invocation with loop-runner-equivalent flags:
  - `codex exec -c 'features.notify=true' --model gpt-5.4 --full-auto -C "$PWD" --output-last-message <tmp> -`

Observed:

- exit code `0`
- output file populated (`ok`)
- no `Error loading config.toml` in stderr
- restarted `loop-runner.sh` and confirmed post-restart agent executions no longer emit `Error loading config.toml` in `logs/loop-runner.log` for fresh `10:00Z+` entries

## Operational Notes

- This is a compatibility shim in the runner, not a permanent fix for user global config shape.
- If needed for debugging, set `CODEX_FEATURES_NOTIFY_OVERRIDE` explicitly per environment.
- If loop-runner behavior and PID status disagree, check for stale long-lived `scripts/loop-runner.sh run` processes via `ps` and remove them before validating a restart.
