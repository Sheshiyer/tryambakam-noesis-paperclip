# SENTINEL QA Runtime Remediation Package

Date: 2026-04-11
Owner: CLAWD
Related tasks: `task-1775933717-3f4c`, `task-1775932448-81fa`, `task-1775930119-849a`

## 1) Failure Mode Identification

The repeated `empty_output` failures were not just QA-content issues. Two concrete runtime patterns were observed:

1. `codex exec --output-last-message <file>` can time out with an empty output file even when valid `===THOUGHTSEED_OUTPUT_START=== ... ===THOUGHTSEED_OUTPUT_END===` content is present on stderr.
2. Broad SENTINEL QA prompts can burn the full timeout budget without producing a parseable final payload for the write-back pipeline.

This means "no output" was partly a transport/parsing failure mode and partly a prompt/runtime budget problem.

## 2) Engineering Remediation Implemented

### A. Structured output stderr fallback (runtime fix)

Updated `scripts/loop-runner.sh` to recover structured THOUGHTSEED output from stderr when the output file is empty:

- Added `recover_structured_output_from_stderr()`
- Invoked fallback before parser handoff in the agent invocation pipeline

Result: one-shot JARVIS verification completed with parsed structured output and successful write-back after patch.

### B. Fail-fast timeout strategy for SENTINEL

Updated `agents/sentinel/MANIFEST.yaml`:

- `max_step_timeout: "4m"` -> `max_step_timeout: "2m"`

This prevents repeated 240-second silent stalls on the same failure mode.

### C. Immediate verification kept in Engineering

Executed direct Engineering verification for loop-runner stability:

- `./scripts/loop-runner.sh start`
- 30-second checks through 240 seconds
- status stayed `RUNNING` for all checks (proof window satisfied)

## 3) New QA Handoff Rule (Engineering vs SENTINEL)

Until SENTINEL reliability is restored, apply this gate before delegating QA:

### Keep QA inside Engineering when any is true

1. Task is orchestration/runtime-critical (loop-runner, babysitter, prompt/parser/write-back path).
2. SENTINEL has 2 consecutive `empty_output` failures on the same lane within 24h.
3. No progress artifact appears within 60s of SENTINEL cycle start (command trace, harness path, or first log snapshot).

### Delegate QA to SENTINEL only when all are true

1. Scope is narrow and single-goal.
2. Timeout budget is explicit and short (<=120s unless justified).
3. Success artifact is defined up front (exact command outputs or file deltas expected).

## 4) Exit Criteria To Resume SENTINEL Ownership

Resume normal SENTINEL ownership for this lane only after all criteria pass:

1. 3 consecutive SENTINEL cycles produce parseable structured output (`updates[]`) with no `empty_output`.
2. 1 real (non-harness) loop-runner QA delegation completes within timeout and writes valid result blocks.
3. No SENTINEL `empty_output` timeout on this lane for 24h.

## 5) Current State

- SENTINEL retry task `task-1775932448-81fa` marked `failed` after 120s empty-output timeout.
- Immediate verification remains Engineering-owned.
- Escalation to JARVIS completed and acknowledged.
