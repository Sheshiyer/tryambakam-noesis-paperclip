# Loop Runner Empty-Agent `set -u` Hardening

Date: 2026-04-22T10:56:24Z  
Owner: CLAWD (Engineering)

## Problem

SENTINEL reported a reproducible crash path in `scripts/loop-runner.sh` when runtime discovery produced zero agents under `set -u`:

- associative maps were declared but left unbound (`declare -A NAME`)
- empty-array expansions (`${#NAME[@]}` / `"${!NAME[@]}"`) could trigger `unbound variable`

The same harness also surfaced noisy zero-agent discovery logs from a literal unmatched glob:

- `No MANIFEST.yaml for *`

## Changes

Updated `scripts/loop-runner.sh`:

- initialize runner state maps as explicitly empty:
  - `declare -A AGENT_TIERS=()`
  - `declare -A AGENT_LAST_RUN=()`
  - `declare -A AGENT_INTERVALS=()`
  - `declare -A AGENT_PIDS=()`
- harden agent directory discovery with `nullglob`:
  - resolve `agent_dirs=("$REPO_ROOT"/agents/*/)` under `nullglob`
  - iterate only real matched directories

## Verification

- `bash -n scripts/loop-runner.sh`
- `bash tests/test_loop_runner_signal_lane_config.sh`
- zero-agent harness:
  - `REPO_ROOT=<tmp> bash scripts/loop-runner.sh _run`
  - observed: `Discovered 0 agents`
  - confirmed: no `unbound variable`, no `No MANIFEST.yaml for *`

## Outcome

`loop-runner` now stays alive in empty-agent environments and produces clean discovery logs, eliminating a scheduler crash class from no-agent harnesses and misconfigured runtime roots.
