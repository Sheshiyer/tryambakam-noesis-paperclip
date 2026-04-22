# Loop Runner `NO_CHANGES` Protocol For Unchanged State Files

Date: 2026-04-22T11:26:12Z  
Owner: CLAWD (Engineering)

## Problem

CLAWD continued timing out (`empty_structured_output`) even after adaptive timeout scaling:

- prompt size was ~200 KB
- timeout increased to 420-480s
- cycles still timed out and fell back to stderr recovery

Root cause: the loop prompt contract required full-file `TASKS.md` and `INBOX.md` rewrites every cycle, even for idle cycles where no changes were needed. For large task histories, response generation overhead itself became the bottleneck.

## Changes

### 1. Prompt contract update

Updated `scripts/agent-prompt-assembler.sh` output format guidance:

- `TASKS.md` block:
  - full content when changed
  - exact `NO_CHANGES` when unchanged
- `INBOX.md` block:
  - full content when changed
  - exact `NO_CHANGES` when unchanged

Also added idle-phase guidance to emit `NO_CHANGES` for unchanged files.

### 2. Write-back compatibility

Updated `scripts/write-back.sh`:

- `TASKS.md` case now skips overwrite when content is `NO_CHANGES`
- `INBOX.md` case now skips overwrite when content is `NO_CHANGES`
- existing full-write behavior remains unchanged for modified files

### 3. Stderr-recovery template guard alignment

Updated `scripts/loop-runner.sh` `recover_structured_output_from_stderr()` disallowed template markers to include new prompt-template text for `TASKS.md` and `INBOX.md` blocks.

## Verification

- `bash -n scripts/agent-prompt-assembler.sh`
- `bash -n scripts/write-back.sh`
- `bash -n scripts/loop-runner.sh`
- write-back harness:
  - parsed JSON with `TASKS.md=NO_CHANGES`, `INBOX.md=NO_CHANGES`
  - verified unchanged SHA for both files
- direct CLAWD `codex exec` run on assembled prompt:
  - emitted parseable structured output with `NO_CHANGES` blocks
- live daemon evidence:
  - pre-patch timeout persisted at `2026-04-22T11:20:31Z`
  - first post-patch CLAWD cycle (`2026-04-22T11:23:53Z`) completed successfully in ~14s
- `./scripts/health-check.sh` reported `11/11 healthy`

## Regression Tests Added

- `tests/test_write_back_no_changes.sh`
  - proves `write-back.sh` does not overwrite `TASKS.md` or `INBOX.md` when block content is exact `NO_CHANGES`
  - proves `CONTEXT.md` is also untouched on `NO_CHANGES`
  - confirms `HEARTBEAT.md` append remains functional
- `tests/test_agent_prompt_no_changes_contract.sh`
  - verifies `agent-prompt-assembler.sh` still instructs `NO_CHANGES` usage for unchanged `TASKS.md` and `INBOX.md`
  - verifies `CONTEXT.md` empty-addition contract still mandates `NO_CHANGES`

Execution:

- `bash tests/test_write_back_no_changes.sh`
- `bash tests/test_agent_prompt_no_changes_contract.sh`
- `bash tests/test_loop_runner_signal_lane_config.sh`

## Follow-up Hardening (2026-04-22T11:49:27Z)

### 1. Malformed JSON resilience in write-back

Updated `scripts/write-back.sh` so malformed JSON input no longer hard-exits with traceback from secondary parses. It now:

- classifies malformed input as `invalid_json`
- appends a controlled error note to `CONTEXT.md`
- appends a parse-error cycle entry to `HEARTBEAT.md`
- exits cleanly (`0`) after recording failure context

### 2. Delimiter-collision-safe update transport

Replaced marker-delimited update-content framing with filename + base64-encoded content records from parsed JSON, then decoded per update before write application. This removes collision risk where literal payload text could contain parser delimiter tokens and corrupt/truncate write-back application.

### Additional Tests

- `tests/test_write_back_marker_collision.sh`
  - verifies payload containing prior delimiter strings is written intact
- `tests/test_write_back_malformed_json.sh`
  - verifies malformed JSON is handled as controlled `invalid_json` parse failure without non-zero crash

Execution:

- `bash -n scripts/write-back.sh`
- `bash tests/test_write_back_no_changes.sh`
- `bash tests/test_write_back_marker_collision.sh`
- `bash tests/test_write_back_malformed_json.sh`

## Stderr Recovery Structural Validation (2026-04-22T12:06:46Z)

Updated `scripts/loop-runner.sh` stderr fallback recovery guard to reduce template-coupling fragility:

- parse recovered block `FILE_UPDATE` sections directly
- require exact expected update key set: `TASKS.md`, `HEARTBEAT.md`, `INBOX.md`, `CONTEXT.md`
- reject unknown/duplicate/missing keys
- reject template-shaped placeholder content patterns (bracket-wrapped directives and placeholder heartbeat fields)

This replaces dependency on exact prompt prose fragments and prevents false recoveries when template wording changes.

Added integration regression:

- `tests/test_loop_runner_stderr_recovery_validation.sh`
  - template echo on stderr is rejected and does not overwrite state files
  - valid stderr-only structured output is recovered and applied

Execution:

- `bash -n scripts/loop-runner.sh`
- `bash tests/test_loop_runner_stderr_recovery_validation.sh`
- `bash tests/test_loop_runner_signal_lane_config.sh`

## Manifest Parsing Hardening (2026-04-22T12:21:54Z)

### Problem

`loop-runner.sh` manifest ingestion relied on `grep -A` window parsing, which is brittle to:

- quoted booleans (`"false"` vs `false`)
- key reordering and section growth
- path-shape drift between `org.paperclip.sync.*` and `org.paperclip.*`

### Change

Added path-based YAML scalar ingestion in `scripts/loop-runner.sh`:

- `yaml_path_get <file> <dot.path>` for nested scalar extraction
- `is_true_value` / `is_false_value` to normalize boolean-like string values

Replaced grep-window reads for:

- tier intervals
- Paperclip cycle flags
- signal-lane config
- chief lookup
- per-agent interval and timeout parsing

### Regression Coverage

- `tests/test_loop_runner_manifest_yaml_parsing.sh`
  - validates quoted `heartbeat_reporting: "true"` still enables `--with-heartbeats`
  - validates quoted signal-lane values map through correctly
  - validates quoted `issues_to_inbox: "false"` disables cycle invocation

Execution:

- `bash -n scripts/loop-runner.sh`
- `bash tests/test_loop_runner_manifest_yaml_parsing.sh`
- `bash tests/test_loop_runner_signal_lane_config.sh`

## Agent Prompt Assembler Manifest Parsing Hardening (2026-04-22T12:36:08Z)

### Problem

`scripts/agent-prompt-assembler.sh` still parsed `MANIFEST.yaml` via grep-window extraction, which is brittle for:

- quoted scalar values
- key reordering
- nested `loop.*` policy fields moving beyond fixed grep windows

### Change

Added path-based YAML scalar ingestion in `scripts/agent-prompt-assembler.sh`:

- `yaml_path_get <file> <dot.path>`

Replaced parser calls for:

- `role`
- `reports_to`
- `tier`
- `loop.max_step_timeout`
- `loop.on_blocked`
- `loop.on_failure`
- `loop.retry_blocked_after`

### Regression Coverage

- `tests/test_agent_prompt_manifest_yaml_parsing.sh`
  - validates quoted/reordered MANIFEST values still render correctly in prompt policy lines

Execution:

- `bash -n scripts/agent-prompt-assembler.sh`
- `bash tests/test_agent_prompt_manifest_yaml_parsing.sh`
- `bash tests/test_agent_prompt_no_changes_contract.sh`

## Shared YAML Helper Consolidation (2026-04-22T12:51:03Z)

### Problem

`yaml_path_get` logic existed in both:

- `scripts/loop-runner.sh`
- `scripts/agent-prompt-assembler.sh`

This duplication risks parser drift and inconsistent behavior over time.

### Change

Added shared helper:

- `scripts/yaml-helpers.sh`
  - `yaml_path_get`
  - `yaml_is_true`
  - `yaml_is_false`

Updated consumers:

- `scripts/loop-runner.sh` now sources `scripts/yaml-helpers.sh` and maps existing wrappers (`is_true_value`/`is_false_value`) to shared helper functions.
- `scripts/agent-prompt-assembler.sh` now sources `scripts/yaml-helpers.sh` directly.

Updated staged regressions that copy scripts into temp roots so they also copy `scripts/yaml-helpers.sh`.

Execution:

- `bash -n scripts/yaml-helpers.sh`
- `bash -n scripts/loop-runner.sh`
- `bash -n scripts/agent-prompt-assembler.sh`
- `bash tests/test_agent_prompt_manifest_yaml_parsing.sh`
- `bash tests/test_agent_prompt_no_changes_contract.sh`
- `bash tests/test_loop_runner_manifest_yaml_parsing.sh`
- `bash tests/test_loop_runner_signal_lane_config.sh`
- `bash tests/test_loop_runner_stderr_recovery_validation.sh`

## YAML Helper Edge-Case Smoke Coverage (2026-04-22T13:04:05Z)

Added direct parser smoke test:

- `tests/test_yaml_helpers_parsing.sh`

Coverage includes:

- quoted scalar extraction
- inline comment stripping for bare values
- preserving `#` characters inside quoted values
- nested dot-path lookups
- missing-path empty response behavior
- `yaml_is_true` / `yaml_is_false` normalization checks

Execution:

- `bash -n scripts/yaml-helpers.sh`
- `bash tests/test_yaml_helpers_parsing.sh`
- `bash tests/test_agent_prompt_manifest_yaml_parsing.sh`
- `bash tests/test_loop_runner_manifest_yaml_parsing.sh`

## Shared Fixture Helper For Temp-Root Tests (2026-04-22T13:18:38Z)

Added shared test fixture utility:

- `tests/lib/fixture-helpers.sh`
  - `copy_scripts_from_repo`
  - `write_runtime_root_guard_stub`

Refactored temp-root tests to consume this helper so script dependency staging is centralized:

- `tests/test_loop_runner_signal_lane_config.sh`
- `tests/test_loop_runner_manifest_yaml_parsing.sh`
- `tests/test_loop_runner_stderr_recovery_validation.sh`
- `tests/test_agent_prompt_no_changes_contract.sh`
- `tests/test_agent_prompt_manifest_yaml_parsing.sh`

Execution:

- `bash -n tests/lib/fixture-helpers.sh`
- `bash tests/test_loop_runner_signal_lane_config.sh`
- `bash tests/test_loop_runner_manifest_yaml_parsing.sh`
- `bash tests/test_loop_runner_stderr_recovery_validation.sh`
- `bash tests/test_agent_prompt_no_changes_contract.sh`
- `bash tests/test_agent_prompt_manifest_yaml_parsing.sh`
- `bash tests/test_yaml_helpers_parsing.sh`

## Outcome

Idle and no-op cycles no longer require large full-file rewrites for `TASKS.md`/`INBOX.md`, removing a major response-size timeout failure mode for large agent histories.

## Boolean Whitespace Normalization Hardening (2026-04-22T13:25:08Z)

### Problem

Shared boolean helpers in `scripts/yaml-helpers.sh` lowercased tokens but did not trim surrounding whitespace. Quoted YAML values like `" false "` or `" true "` therefore failed boolean checks and could bypass manifest gates.

### Change

Updated:

- `yaml_is_true`
- `yaml_is_false`

Both now trim leading/trailing whitespace before lowercase token evaluation.

### Regression Coverage

- `tests/test_yaml_helpers_parsing.sh`
  - added whitespace-padded true/false token assertions
- `tests/test_loop_runner_manifest_yaml_parsing.sh`
  - updated fixtures to use whitespace-padded quoted booleans for:
    - `heartbeat_reporting`
    - signal-lane toggles
    - `issues_to_inbox` disable gate
  - confirms loop-runner behavior remains correct under spaced tokens

### Execution

- `bash -n scripts/yaml-helpers.sh tests/test_yaml_helpers_parsing.sh tests/test_loop_runner_manifest_yaml_parsing.sh`
- `bash tests/test_yaml_helpers_parsing.sh`
- `bash tests/test_loop_runner_manifest_yaml_parsing.sh`
- `bash tests/test_loop_runner_signal_lane_config.sh`
- `bash tests/test_agent_prompt_manifest_yaml_parsing.sh`
- `./scripts/health-check.sh` (`11/11 healthy`)

## Fixture Helper Adoption Expansion (2026-04-22T13:39:09Z)

### Problem

After introducing `tests/lib/fixture-helpers.sh`, several temp-root regressions still used manual script-copy setup (`cp .../scripts/*.sh`). This duplicates fixture staging behavior and creates drift risk when script dependencies change.

### Change

Refactored these tests to use `copy_scripts_from_repo`:

- `tests/test_task_registry_reconcile_inbox.sh`
- `tests/test_dispatch_task_sync_key_dedupe.sh`
- `tests/test_teamforge_export_cmd_manifest.sh`

### Execution

- `bash -n tests/lib/fixture-helpers.sh tests/test_task_registry_reconcile_inbox.sh tests/test_dispatch_task_sync_key_dedupe.sh tests/test_teamforge_export_cmd_manifest.sh`
- `bash tests/test_task_registry_reconcile_inbox.sh`
- `bash tests/test_dispatch_task_sync_key_dedupe.sh`
- `bash tests/test_teamforge_export_cmd_manifest.sh`
- `bash tests/test_teamforge_clockify_policy.sh`
- `./scripts/health-check.sh` (`11/11 healthy`)

## TeamForge Fixture Helper Alignment (2026-04-22T13:52:20Z)

### Problem

Two high-churn TeamForge regressions still duplicated temp-root script staging with manual `cp` blocks, diverging from the shared fixture helper contract.

### Change

Refactored to `copy_scripts_from_repo` in:

- `tests/test_teamforge_reconcile_inbox_hook.sh`
- `tests/test_teamforge_clockify_policy.sh`

### Execution

- `bash -n tests/lib/fixture-helpers.sh tests/test_teamforge_reconcile_inbox_hook.sh tests/test_teamforge_clockify_policy.sh`
- `bash tests/test_teamforge_reconcile_inbox_hook.sh`
- `bash tests/test_teamforge_clockify_policy.sh`
- `bash tests/test_teamforge_export_cmd_manifest.sh`
- `./scripts/health-check.sh` (`11/11 healthy`)

## Signal-Lane Fixture Helper Alignment (2026-04-22T14:06:02Z)

### Problem

Signal-lane regressions still used manual script-copy staging, while newer tests had converged on `tests/lib/fixture-helpers.sh`.

### Change

Refactored to `copy_scripts_from_repo` in:

- `tests/test_signal_lane_gating.sh`
- `tests/test_paperclip_cycle_signal_lane.sh`

### Execution

- `bash -n tests/lib/fixture-helpers.sh tests/test_signal_lane_gating.sh tests/test_paperclip_cycle_signal_lane.sh`
- `bash tests/test_paperclip_cycle_signal_lane.sh`
- `bash tests/test_signal_lane_gating.sh`
- `bash tests/test_signal_lane_detection.sh`
- `./scripts/health-check.sh` (initial run: `10/11 healthy`, transient `jarvis` stale flag)
- `./scripts/health-check.sh` (follow-up run: `11/11 healthy`)

## Write-Back And TeamForge Status Fixture Helper Alignment (2026-04-22T14:20:38Z)

### Problem

Core compatibility suites still used manual script-copy staging:

- write-back protocol regressions
- TeamForge status backfill compatibility regression

This left fixture setup behavior duplicated outside the shared helper.

### Change

Refactored to `copy_scripts_from_repo` in:

- `tests/test_write_back_no_changes.sh`
- `tests/test_write_back_marker_collision.sh`
- `tests/test_write_back_malformed_json.sh`
- `tests/test_teamforge_status_failure_rate_backfill.sh`

### Execution

- `bash -n tests/lib/fixture-helpers.sh tests/test_write_back_no_changes.sh tests/test_write_back_marker_collision.sh tests/test_write_back_malformed_json.sh tests/test_teamforge_status_failure_rate_backfill.sh`
- `bash tests/test_write_back_no_changes.sh`
- `bash tests/test_write_back_marker_collision.sh`
- `bash tests/test_write_back_malformed_json.sh`
- `bash tests/test_teamforge_status_failure_rate_backfill.sh`
- `./scripts/health-check.sh` (`11/11 healthy`)

## Fixture Helper Missing-Script Validation (2026-04-22T14:33:25Z)

### Problem

`copy_scripts_from_repo` previously relied on raw `cp` failures, which produced less-direct diagnostics when script names drifted after refactors.

### Change

- Updated `tests/lib/fixture-helpers.sh`:
  - `copy_scripts_from_repo` now checks source existence per script before copy
  - emits explicit `Missing source script: <path>` and returns non-zero on failure
- Added dedicated regression:
  - `tests/test_fixture_helpers_copy_scripts.sh`

### Execution

- `bash -n tests/lib/fixture-helpers.sh tests/test_fixture_helpers_copy_scripts.sh`
- `bash tests/test_fixture_helpers_copy_scripts.sh`
- `bash tests/test_loop_runner_signal_lane_config.sh`
- `bash tests/test_teamforge_export_cmd_manifest.sh`
- `bash tests/test_write_back_no_changes.sh`
- `./scripts/health-check.sh` (`11/11 healthy`)

## Fixture Helper Invocation Guardrails (2026-04-22T14:46:17Z)

### Problem

Even with missing-script checks, helper failures could still be opaque when callers invoked `copy_scripts_from_repo` with malformed arguments or bad source roots.

### Change

Enhanced `copy_scripts_from_repo` in `tests/lib/fixture-helpers.sh` with:

- minimum argument validation
- explicit source scripts-directory validation
- existing per-script missing-file validation retained

Expanded `tests/test_fixture_helpers_copy_scripts.sh` to validate:

- usage failure when no script names are passed
- missing scripts-directory failure
- missing script failure
- success path for multi-script copy
- `write_runtime_root_guard_stub` behavior

### Execution

- `bash -n tests/lib/fixture-helpers.sh tests/test_fixture_helpers_copy_scripts.sh`
- `bash tests/test_fixture_helpers_copy_scripts.sh`
- `bash tests/test_loop_runner_signal_lane_config.sh`
- `bash tests/test_write_back_no_changes.sh`
- `./scripts/health-check.sh` (`11/11 healthy`)
