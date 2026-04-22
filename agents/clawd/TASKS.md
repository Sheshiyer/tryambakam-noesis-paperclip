# CLAWD — Tasks

Step-by-step work queue. The loop reads this file each cycle to pick the next incomplete step.

## Active Tasks

_No active tasks._

## Task Format

Each task follows this structure:
- **Step N**: [description]
  - Status: open | in-progress | blocked | done | failed
  - Priority: critical | high | medium | low
  - Tags: [comma-separated tags]
  - Blocked reason: (if blocked — WHY specifically)
  - Retry count: 0
  - Depends on: (step IDs if any)
  - Result: (written after completion or failure)

## Completed Tasks

- **Step 121**: Add shared executable-bit fixture helper and adopt it in remaining temp-root suites
  - Status: done
  - Priority: medium
  - Tags: qa, reliability, maintainability, tests
  - Retry count: 0
  - Depends on: 120
  - Result: Added `make_scripts_executable` to `tests/lib/fixture-helpers.sh` with usage validation (`<scripts_dir> <script_name...>`) and explicit missing-target checks. Expanded `tests/test_fixture_helpers_copy_scripts.sh` to cover helper usage failure, success path, and missing-target failure. Refactored remaining manual chmod staging in `tests/test_signal_lane_gating.sh`, `tests/test_teamforge_reconcile_inbox_hook.sh`, and `tests/test_teamforge_clockify_policy.sh` to the shared helper. Re-verified with syntax checks, touched regressions, and runtime health (`11/11 healthy`).

- **Step 120**: Add argument and source-directory validation to fixture-helper copy API
  - Status: done
  - Priority: medium
  - Tags: qa, reliability, maintainability, tests
  - Retry count: 0
  - Depends on: 119
  - Result: Hardened `copy_scripts_from_repo` in `tests/lib/fixture-helpers.sh` with explicit guardrails: usage validation (`<source_repo> <target_dir> <script_name...>`) and source scripts-directory existence checks before copy. Expanded `tests/test_fixture_helpers_copy_scripts.sh` to cover usage failure, missing scripts-directory failure, missing-script failure, successful multi-script copy, and `write_runtime_root_guard_stub` behavior (`assert|check|other` exit paths). Re-verified with helper syntax checks, the expanded helper regression, representative dependent suites (`loop_runner_signal_lane_config`, `write_back_no_changes`), and runtime health (`11/11 healthy`).

- **Step 119**: Harden fixture-helper copy behavior with explicit missing-script validation
  - Status: done
  - Priority: medium
  - Tags: qa, reliability, maintainability, tests
  - Retry count: 0
  - Depends on: 118
  - Result: Updated `tests/lib/fixture-helpers.sh` `copy_scripts_from_repo` to validate each source script exists before copy and emit a clear failure (`Missing source script: ...`) when absent. Added `tests/test_fixture_helpers_copy_scripts.sh` to verify both successful multi-script copies and expected failure semantics for missing scripts. Re-verified with helper syntax checks, new helper regression, representative dependent suites (`loop_runner_signal_lane_config`, `teamforge_export_cmd_manifest`, `write_back_no_changes`), and runtime health (`11/11 healthy`).

- **Step 118**: Align write-back and TeamForge status regressions with shared fixture-helper staging
  - Status: done
  - Priority: medium
  - Tags: qa, maintainability, tests
  - Retry count: 0
  - Depends on: 117
  - Result: Refactored `tests/test_write_back_no_changes.sh`, `tests/test_write_back_marker_collision.sh`, `tests/test_write_back_malformed_json.sh`, and `tests/test_teamforge_status_failure_rate_backfill.sh` to source `tests/lib/fixture-helpers.sh` and use `copy_scripts_from_repo` for script staging. This removes remaining ad-hoc script-copy setup from write-back and TeamForge status compatibility suites. Re-verified with syntax checks, all touched regressions, and runtime health (`11/11 healthy`).

- **Step 117**: Align signal-lane regressions with shared fixture-helper script staging
  - Status: done
  - Priority: medium
  - Tags: qa, maintainability, tests
  - Retry count: 0
  - Depends on: 116
  - Result: Refactored `tests/test_signal_lane_gating.sh` and `tests/test_paperclip_cycle_signal_lane.sh` to source `tests/lib/fixture-helpers.sh` and stage scripts with `copy_scripts_from_repo` instead of manual per-script `cp` blocks. This extends fixture-helper consistency into signal-lane suites and reduces setup drift across orchestration tests. Re-verified with syntax checks plus signal-lane regressions (`paperclip_cycle_signal_lane`, `signal_lane_gating`, `signal_lane_detection`), then repeated runtime health validation after a transient `jarvis` stale window; final runtime status returned to `11/11 healthy`.

- **Step 116**: Extend fixture-helper staging to TeamForge inbox-reconcile and Clockify policy regressions
  - Status: done
  - Priority: medium
  - Tags: qa, maintainability, tests
  - Retry count: 0
  - Depends on: 115
  - Result: Refactored `tests/test_teamforge_reconcile_inbox_hook.sh` and `tests/test_teamforge_clockify_policy.sh` to source `tests/lib/fixture-helpers.sh` and stage scripts via `copy_scripts_from_repo` instead of repeated inline `cp` blocks. This aligns TeamForge regressions with the shared temp-root fixture contract and reduces setup drift. Re-verified with syntax checks, both touched TeamForge regressions, dependent export regression, and runtime health (`11/11 healthy`).

- **Step 115**: Expand fixture-helper usage across additional temp-root registry/teamforge tests
  - Status: done
  - Priority: medium
  - Tags: qa, maintainability, tests
  - Retry count: 0
  - Depends on: 114
  - Result: Refactored three remaining temp-root regressions to use `tests/lib/fixture-helpers.sh` `copy_scripts_from_repo` instead of inline `cp` boilerplate: `tests/test_task_registry_reconcile_inbox.sh`, `tests/test_dispatch_task_sync_key_dedupe.sh`, and `tests/test_teamforge_export_cmd_manifest.sh`. This keeps script staging logic centralized and reduces drift when script dependencies move. Re-verified with syntax checks, the three touched regressions, dependent TeamForge policy regression, and runtime health (`11/11 healthy`).

- **Step 114**: Normalize YAML boolean checks for whitespace-padded scalar values
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, config, qa
  - Retry count: 0
  - Depends on: 113
  - Result: Hardened `scripts/yaml-helpers.sh` boolean helpers so `yaml_is_true`/`yaml_is_false` now trim surrounding whitespace before lowercasing/token checks. This prevents manifest booleans like `" false "` or `" true "` from being misclassified in `loop-runner` config loading. Expanded regression coverage in `tests/test_yaml_helpers_parsing.sh` for whitespace-padded boolean-like tokens and updated `tests/test_loop_runner_manifest_yaml_parsing.sh` to assert end-to-end behavior with whitespace-padded quoted manifest booleans (`heartbeat_reporting`, signal-lane flags, `issues_to_inbox`). Re-verified with syntax checks, touched regression suite, and runtime health (`11/11 healthy`).

- **Step 113**: Add shared test fixture helper for temp-root script staging
  - Status: done
  - Priority: medium
  - Tags: qa, maintainability, tests
  - Retry count: 0
  - Depends on: 112
  - Result: Added `tests/lib/fixture-helpers.sh` with `copy_scripts_from_repo` and `write_runtime_root_guard_stub`, then refactored affected temp-root regressions to consume it (`test_loop_runner_signal_lane_config.sh`, `test_loop_runner_manifest_yaml_parsing.sh`, `test_loop_runner_stderr_recovery_validation.sh`, `test_agent_prompt_no_changes_contract.sh`, `test_agent_prompt_manifest_yaml_parsing.sh`). This removes repeated cp/stub boilerplate and centralizes fixture setup behavior. Re-verified with the full impacted regression set and runtime health check.

- **Step 112**: Add dedicated YAML helper edge-case smoke test
  - Status: done
  - Priority: medium
  - Tags: ops, qa, maintainability
  - Retry count: 0
  - Depends on: 111
  - Result: Added `tests/test_yaml_helpers_parsing.sh` to validate `scripts/yaml-helpers.sh` behavior for quoted values, inline comment stripping, hash preservation inside quoted strings, nested dot-path reads, missing-path empty behavior, and boolean normalization helpers (`yaml_is_true`/`yaml_is_false`). Re-verified with `bash -n scripts/yaml-helpers.sh`, `bash tests/test_yaml_helpers_parsing.sh`, and downstream manifest parser regressions in both assembler and loop-runner suites.

- **Step 111**: Consolidate YAML scalar parsing into shared helper script
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, maintainability
  - Retry count: 0
  - Depends on: 110
  - Result: Added shared `scripts/yaml-helpers.sh` with `yaml_path_get`, `yaml_is_true`, and `yaml_is_false`, then wired both `scripts/loop-runner.sh` and `scripts/agent-prompt-assembler.sh` to source it. Removed duplicated inline YAML parser implementations and kept loop-runner boolean wrappers mapped to shared helpers. Updated temp-root regressions that stage these scripts so they also copy `yaml-helpers.sh` (`test_loop_runner_signal_lane_config.sh`, `test_loop_runner_stderr_recovery_validation.sh`, `test_loop_runner_manifest_yaml_parsing.sh`, `test_agent_prompt_no_changes_contract.sh`, `test_agent_prompt_manifest_yaml_parsing.sh`). Re-verified with syntax checks and the full touched regression set.

- **Step 110**: Replace agent-prompt-assembler grep-window MANIFEST parsing with path-based YAML reads
  - Status: done
  - Priority: high
  - Tags: ops, reliability, config
  - Retry count: 0
  - Depends on: 109
  - Result: Added `yaml_path_get` to `scripts/agent-prompt-assembler.sh` and replaced manifest extraction for `role`, `reports_to`, `tier`, `loop.max_step_timeout`, `loop.on_blocked`, `loop.on_failure`, and `loop.retry_blocked_after`. This removes `grep -A` window fragility for quoted/reordered MANIFEST values and keeps prompt policy rendering stable. Added `tests/test_agent_prompt_manifest_yaml_parsing.sh` to validate quoted/reordered manifest fields are rendered correctly in the prompt policy section. Re-verified with `bash -n scripts/agent-prompt-assembler.sh`, `bash tests/test_agent_prompt_manifest_yaml_parsing.sh`, `bash tests/test_agent_prompt_no_changes_contract.sh`, and cross-suite loop-runner regressions.

- **Step 109**: Replace loop-runner grep-window manifest parsing with path-based YAML scalar reads
  - Status: done
  - Priority: high
  - Tags: ops, reliability, config
  - Retry count: 0
  - Depends on: 108
  - Result: Added a built-in path-based YAML scalar reader (`yaml_path_get`) plus normalized boolean helpers (`is_true_value`/`is_false_value`) in `scripts/loop-runner.sh`, replacing brittle `grep -A` window parsing for manifest-driven intervals, Paperclip sync flags, signal-lane settings, chief agent lookup, per-agent loop interval, and per-agent timeout parsing. Added regression `tests/test_loop_runner_manifest_yaml_parsing.sh` to validate quoted boolean/numeric handling (`"true"`, `"false"`, quoted thresholds) and quoted `issues_to_inbox` disable behavior. Re-verified with `bash -n scripts/loop-runner.sh`, `bash tests/test_loop_runner_manifest_yaml_parsing.sh`, `bash tests/test_loop_runner_signal_lane_config.sh`, and `bash tests/test_loop_runner_stderr_recovery_validation.sh`.

- **Step 108**: Harden loop-runner stderr recovery with structural validation
  - Status: done
  - Priority: high
  - Tags: ops, reliability, qa
  - Retry count: 0
  - Depends on: 107
  - Result: Reworked `recover_structured_output_from_stderr()` in `scripts/loop-runner.sh` to validate recovered blocks structurally (parse `FILE_UPDATE` blocks, enforce expected files, reject unknown/duplicate/missing update keys) and reject template-shaped placeholder payloads without relying on brittle exact prompt text fragments. Added `tests/test_loop_runner_stderr_recovery_validation.sh` with two integration cases: template-echo rejection and valid stderr-only recovery acceptance. Re-verified with `bash -n scripts/loop-runner.sh`, `bash tests/test_loop_runner_stderr_recovery_validation.sh`, `bash tests/test_loop_runner_signal_lane_config.sh`, plus the write-back/prompt regression suite.

- **Step 107**: Harden `write-back.sh` against malformed JSON and marker-collision payloads
  - Status: done
  - Priority: high
  - Tags: ops, reliability, qa
  - Retry count: 0
  - Depends on: 106
  - Result: Patched `scripts/write-back.sh` to gracefully handle malformed JSON input (`invalid_json` context/heartbeat failure entry, no hard crash) and replaced marker-delimited update streaming with filename + base64 content records to eliminate delimiter-collision truncation risk when file content contains parser marker strings. Added `tests/test_write_back_marker_collision.sh` and `tests/test_write_back_malformed_json.sh`, and re-verified with `bash -n scripts/write-back.sh`, `bash tests/test_write_back_no_changes.sh`, `bash tests/test_write_back_marker_collision.sh`, `bash tests/test_write_back_malformed_json.sh`, `bash tests/test_agent_prompt_no_changes_contract.sh`, and `bash tests/test_loop_runner_signal_lane_config.sh`.

- **Step 106**: Add regression tests for `NO_CHANGES` prompt/write-back protocol
  - Status: done
  - Priority: high
  - Tags: ops, reliability, qa
  - Retry count: 0
  - Depends on: 105
  - Result: Added `tests/test_write_back_no_changes.sh` to verify `write-back.sh` preserves `TASKS.md`/`INBOX.md`/`CONTEXT.md` when update content is `NO_CHANGES` while still appending `HEARTBEAT.md`. Added `tests/test_agent_prompt_no_changes_contract.sh` to verify `agent-prompt-assembler.sh` retains mandatory `NO_CHANGES` output-contract guidance for unchanged files. Verified with `bash tests/test_write_back_no_changes.sh`, `bash tests/test_agent_prompt_no_changes_contract.sh`, and `bash tests/test_loop_runner_signal_lane_config.sh`. Runtime health remained green (`./scripts/health-check.sh` -> `11/11 healthy`).

- **Step 105**: Add `NO_CHANGES` protocol for unchanged TASKS/INBOX cycle writes
  - Status: done
  - Priority: high
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated loop prompt contract and write-back behavior so agents can emit `NO_CHANGES` for unchanged `TASKS.md` and `INBOX.md`, while retaining full-file writes when those files actually change. Patched `scripts/agent-prompt-assembler.sh` output rules, `scripts/write-back.sh` handling for `TASKS.md`/`INBOX.md`, and stderr-recovery template guards in `scripts/loop-runner.sh`. Verified with `bash -n scripts/agent-prompt-assembler.sh scripts/write-back.sh scripts/loop-runner.sh`, a write-back harness proving unchanged-file SHA stability, a direct CLAWD `codex exec` prompt run producing parseable `NO_CHANGES` blocks, and live daemon evidence (`2026-04-22T11:23:53Z` CLAWD cycle completed in ~14s after prior repeated timeout/parse-error failures).

- **Step 104**: Harden loop-runner empty-agent paths under `set -u`
  - Status: done
  - Priority: high
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Fixed a `set -u` crash path in `scripts/loop-runner.sh` when discovery yields zero agents by initializing associative state maps as explicitly empty (`declare -A ...=()`) instead of unbound declarations. Also hardened zero-agent discovery by switching to a `nullglob`-based directory list so the runner no longer emits noisy `No MANIFEST.yaml for *` warnings when `agents/*/` has no matches. Re-verified with `bash -n scripts/loop-runner.sh`, `bash tests/test_loop_runner_signal_lane_config.sh`, and a zero-agent temp harness run (`REPO_ROOT=<tmp> bash scripts/loop-runner.sh _run`) confirming no `unbound variable` failures and clean discovery logs.

- **Step 103**: Harden loop-runner daemon control against PID-file drift and duplicate run processes
  - Status: done
  - Priority: high
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/loop-runner.sh` daemon control to be process-aware instead of PID-file-only. Added `loop_runner_process_pids` + `collect_loop_runner_pids`, with root-runner filtering so per-agent child worker shells are excluded from daemon PID sets. Expanded `claim_pid_file` to fail when another runner already exists (even if PID file drifted), and hardened `start_daemon`/`show_status` to self-heal PID drift by reconciling against live runner roots. Fixed signal handling by replacing cleanup-only `INT/TERM` trap behavior with `handle_termination` so TERM actually exits the daemon. Reworked `stop_daemon` to terminate all discovered runner roots and re-check live processes post-stop, emitting explicit warnings when an external supervisor auto-restarts the service. Verified with `bash -n scripts/loop-runner.sh`, `./scripts/loop-runner.sh start`, `./scripts/loop-runner.sh status`, and `./scripts/loop-runner.sh stop`.

- **Step 102**: Restore loop-runner agent execution when Codex config has legacy `features.notify` shape
  - Status: done
  - Priority: high
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Diagnosed recurring multi-agent `empty_output` parse failures to a Codex startup crash (`Error loading config.toml: invalid type: sequence, expected a boolean in features`) captured in `logs/loop-runner.log`. Implemented a loop-runner compatibility override in `scripts/loop-runner.sh` so every agent invocation passes `-c "features.notify=<value>"` (default `true`, configurable via `CODEX_FEATURES_NOTIFY_OVERRIDE`) before normal exec flags. This prevents legacy array-shaped `features.notify` user configs from aborting `codex exec` before structured output is emitted. Re-verified with `bash -n scripts/loop-runner.sh` and a direct loop-runner-equivalent smoke call: `codex exec -c 'features.notify=true' --model gpt-5.4 --full-auto -C "$PWD" --output-last-message ...`, confirming `exit=0`, output emitted, and no config parse error in stderr.

- **Step 101**: Extract `.source` tokens from object entries in coverage source arrays
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` shared coverage source-value normalization for array containers so object entries are no longer stringified; array objects now contribute canonical source tokens only via valid `.sources`/`.source` payloads. Unsupported object rows in coverage arrays now normalize to empty (instead of generic key extraction), closing source leakage where metadata keys (for example `{note:"ignored"}`) could inflate expected source sets and distort coverage ratios. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for both object-array `.source` extraction/filtering and nested object-array `.sources` extraction. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 100**: Drop boolean/null entries from direct coverage source arrays
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` coverage normalization so direct array containers (`expectedSources|seenSources`) now pass through shared source-value normalization, filtering boolean/null entries before canonicalization. This prevents phantom `"true"`/`"false"` tokens from direct coverage arrays and aligns direct-array behavior with nested/object coverage source hardening. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating boolean/null entries in direct coverage arrays are excluded while ratio/warning semantics remain stable. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 99**: Prefer non-empty `.sources` sets over `.source` when both exist
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Refined coverage object-container precedence in `scripts/teamforge-sync.sh` so when both `.source` and `.sources` are present, normalization prefers non-empty `.sources` sets and falls back to `.source` only when `.sources` is empty/invalid. This preserves multi-source payload fidelity for mixed legacy shapes (for example `{source:"clockify",sources:["clockify","huly"]}`) and avoids collapsing coverage sets to a single source token. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating `.sources` precedence with `.source` coexistence and expected ratio/warning behavior. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 98**: Fallback to `.sources` when `.source` is invalid in coverage object containers
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` coverage object-container precedence so when `.source` is present but invalid (for example boolean/null), normalization no longer falls through to generic key extraction; it now prefers valid `.sources` payloads and otherwise resolves to `[]`. This prevents phantom `"source"` canonical tokens and preserves valid nested source sets when both fields are present (`{source:false,sources:[...]}`). Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating `.source` invalid + `.sources` valid fallback behavior and stable ratio/warning semantics. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 97**: Filter boolean/null `.source` field values in coverage object containers
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Added `source_field_to_list` in `scripts/teamforge-sync.sh` and routed `expectedSources|seenSources` object containers with `.source` through this helper so only string/number source values are admitted; boolean/null/non-scalar `.source` values now normalize to `[]`. This prevents phantom `"true"`/`"false"` source tokens from legacy object containers like `{source:false}` and stabilizes coverage ratio/warning semantics. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating boolean `.source` values are filtered for both expected and seen source containers. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 96**: Ignore boolean scalar coverage source containers in `status` normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` coverage source extraction so direct and nested scalar boolean containers (`expectedSources|seenSources`, `{sources:true|false}`) normalize to `[]` instead of emitting phantom `"true"`/`"false"` source tokens. This keeps boolean flags as control values rather than canonical source identities and stabilizes coverage ratio/warning semantics for legacy boolean payload shapes. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for both direct and nested boolean scalar coverage containers. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 95**: Normalize invalid nested `coverage.sources` wrapper fallbacks to empty sets
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` coverage nested-wrapper extraction so invalid nested `sources` payload types now normalize to `[]` instead of falling back to wrapper keys like `"sources"`. This prevents placeholder key leakage into canonical `expectedSources|seenSources` when legacy snapshots encode `{"sources": null}` or other invalid nested forms. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating invalid nested wrapper payloads yield empty canonical source sets with stable ratio/warning semantics. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 94**: Exclude blank-string scalar flags in coverage object-map source extraction
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `source_keys_from_object` so string scalar values are trimmed before bool interpretation and blank strings are dropped (`null`-equivalent) rather than treated as unknown include-values. This prevents placeholder object-map flags like `"source": "   "` from being counted as covered source keys while preserving unknown non-empty scalar labels and per-key mixed-map filtering. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating blank-string scalar entries are excluded from canonical `expectedSources|seenSources` and ratio derivation in evaluated coverage payloads. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 93**: Filter mixed object-map coverage source entries per-key while preserving unknown scalar labels
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `source_keys_from_object` to evaluate object-map source entries per key instead of using all-or-nothing scalar branching. Mixed maps now exclude explicit false/null scalar entries (`false|0|no|null`) while preserving unknown scalar labels and non-scalar entries, preventing false source keys from leaking into canonical `expectedSources|seenSources` when maps include nested objects. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating mixed object-map coverage payloads with object + false scalar + unknown scalar values produce correct canonical sources and ratio semantics. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 92**: Preserve unknown scalar object-map source tokens in coverage normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `source_keys_from_object` so scalar object-map source extraction now excludes only explicit false/null entries and preserves unknown scalar tokens (for example `"enabled"`, `"active"`) instead of coercing them to false. This keeps legacy source maps with non-standard truthy labels from silently dropping valid source keys while preserving existing handling for explicit false values (`false|0|no`). Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating object-map coverage source sets with unknown scalar labels normalize to expected canonical source sets and derived ratio semantics. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 91**: Exclude source-less lag rows from derived `maxSourceLagSeconds` fallback
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` max-lag fallback derivation to consider only lag rows with non-null canonical `source` when computing `maxSourceLagSeconds` from normalized row lag values. This prevents malformed/source-less lag rows from inflating max-lag fallback and alert semantics when explicit `maxSourceLagSeconds` is absent. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating source-less high-lag rows are preserved for visibility but excluded from max-lag derivation (`maxSourceLagSeconds` derived from valid source rows only). Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 90**: Drop boolean lag scalar entries in source-array normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` lag source-array scalar-row normalization so boolean scalar entries are ignored (both `true` and `false`) instead of being surfaced as canonical lag source rows. This aligns scalar-array behavior with object-map boolean-flag filtering and avoids placeholder source rows from legacy flag-style lag arrays. Expanded regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` by adding both boolean scalar values to lag-source array fixtures and asserting canonical output excludes them while preserving string/number/object rows and max-lag derivation. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 89**: Drop false boolean scalar rows in lag source-array normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` lag source-array scalar normalization so boolean scalars are handled explicitly: `false` rows are dropped while `true` can emit a source-only scalar row. This prevents explicit false flags in legacy lag source arrays from producing placeholder canonical rows and preserves existing string/number scalar row behavior plus max-lag derivation semantics. Expanded regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` by adding `false` to lag scalar-row fixtures and asserting canonical output excludes the false row while preserving other rows and derived max lag. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 88**: Filter false boolean lag object-map entries during source-row expansion
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` lag source object-map expansion (both direct and nested wrapper paths) so boolean map values are handled explicitly: `false` entries are dropped, while `true` entries produce source-only rows. This prevents placeholder lag rows from explicitly false source flags in legacy lag maps while preserving existing numeric/string lag scalar behavior and max-lag derivation. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating a lag map containing `\"huly\": false` emits only canonical rows for truthy/structured sources and derived `maxSourceLagSeconds=12`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 87**: Filter scalar object-map coverage keys by truthiness in `status` normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` coverage source normalization for object-map containers to apply scalar truthy filtering (`true/false`, `1/0`, recognized string booleans) before key extraction, while preserving fallback to full key extraction for non-scalar map values. This prevents explicitly false object-map entries from being miscounted as covered sources in `expectedSources|seenSources` normalization. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating truthy filtering semantics for object-map source sets (`true/false/1/0/yes/no`) and stable ratio/warning derivation. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 86**: Support nested object-wrapped lag source containers in `status` normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` lag-source normalization to unwrap nested object-wrapped lag payloads (`lag.sources = { sources: ... }`) across array/scalar/object forms before canonical row normalization. Nested object-map payloads now expand into per-source rows, and nested scalar/array payloads preserve existing canonical lag row semantics, including derived `maxSourceLagSeconds`. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating nested lag source wrappers normalize into canonical rows and derive `maxSourceLagSeconds=18` from nested payload entries. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 85**: Support nested object-wrapped coverage source sets in `status` normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` coverage source normalization to support object-wrapped source payloads like `{ \"sources\": [...] }` for `expectedSources|expected_sources` and `seenSources|seen_sources`. Nested `sources` values now normalize across array/scalar/object forms before canonical trimming/lowercasing/dedupe and ratio derivation. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating nested object-wrapped coverage source sets normalize to canonical sets with derived `ratio=0.5` and computed `coverageWarning=true` when below threshold. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 84**: Support source-keyed lag object-map containers in `status` normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` lag-source normalization to detect source-keyed object-map containers (for example `{ \"clockify\": {...}, \"huly\": 11 }`) and expand them into canonical lag source rows before row-level normalization, instead of treating the entire object as one opaque row. Map-object entries now inherit source labels from keys when value objects omit `.source`, and scalar map values are mapped to `{source:key, lagSeconds:value}` for derived max-lag semantics. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating object-map `lag.sources` payloads normalize to canonical rows and derive `maxSourceLagSeconds` from expanded entries. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 83**: Support object-map coverage source containers in `status` normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` coverage source normalization to support object-shaped source containers for `expectedSources|expected_sources` and `seenSources|seen_sources`. Object containers now normalize via source key extraction (or explicit `.source` when present) before canonical lowercase trimming, dedupe, and ratio derivation. This preserves legacy source-set payloads that use object maps instead of arrays/scalars. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating object-map coverage sets normalize to canonical `expectedSources`/`seenSources`, derive `ratio=0.5`, and raise computed `coverageWarning` when below threshold. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 82**: Preserve single-object lag source containers in `status` normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` lag-source container normalization to treat object-shaped `lag.sources|lag_sources|lagSources` payloads as one-item source arrays before canonical row coercion, instead of dropping them as non-array containers. This preserves explicit legacy single-source metadata and keeps max-lag derivation behavior when `maxSourceLagSeconds` is missing. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating `lag.sources` object payloads normalize to canonical lag rows and derived `maxSourceLagSeconds`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 81**: Preserve scalar lag source containers as canonical source rows
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` lag-source container normalization to treat scalar `lag.sources|lag_sources|lagSources` payloads (`string|number|boolean`) as single-element source arrays before canonical row coercion, instead of collapsing them to `[]`. This preserves explicit legacy source identifiers while keeping iteration safety for malformed non-array containers. Expanded regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` to validate `sources: "legacy_scalar_blob"` now emits `metrics.lag.sources=[{source:"legacy_scalar_blob",entity:null,lastSyncAt:null,lagSeconds:null}]` with normalized lag scalar fields intact. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 80**: Support scalar coverage source containers in `status` normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` coverage source normalization to accept scalar legacy source containers (`expectedSources|expected_sources`, `seenSources|seen_sources`) as one-item sets before token canonicalization. This preserves explicit single-source payloads instead of defaulting `expectedSources` to the 3-source baseline and `seenSources` to empty. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating scalar coverage containers normalize to `expectedSources=["clockify"]`, `seenSources=["clockify"]`, and derived `ratio=1` when evaluated. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 79**: Emit canonical JSON defaults when health snapshot is missing
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Added `default_status_payload()` in `scripts/teamforge-sync.sh` and updated `print_status` so missing health snapshots now emit canonical JSON defaults instead of plain-text `"No TeamForge health snapshot found."`, preserving machine-readable status semantics for automation. Reused the same helper for invalid-JSON parse fallback to keep fallback payloads consistent. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating missing-file fallback returns canonical default JSON fields. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 78**: Add invalid-JSON fallback in `status` output normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` to catch jq parse failures for malformed health snapshots and emit a canonical default status payload instead of exiting non-zero. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for invalid JSON (`{ this is not valid json`) verifying stable defaults (`generatedAt=null`, zero counters, default coverage sources, false alerts). Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 77**: Guard non-array lag source containers in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` lag-source normalization to require array-shaped source containers before `map` iteration; non-array legacy values (`string|number|object|null`) now normalize to `[]` instead of triggering jq iteration errors. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating `metrics.lag.sources=\"legacy_scalar_blob\"` yields canonical lag output (`projectionLagSeconds=4`, `maxSourceLagSeconds=9`, `sources=[]`) without crashing. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 76**: Guard non-object root payloads in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` root binding to coerce non-object health payloads into `{}` before field lookup, preventing jq indexing failures when legacy/corrupted snapshots are scalar/array JSON values. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating a root scalar payload (`\"legacy_scalar_blob\"`) emits canonical default status output (`generatedAt=null`, zeroed counters, default coverage set, and false alerts) instead of crashing. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 75**: Guard scalar `metrics.*` sub-containers in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` with object-aware sub-container selection (`first_object`) so `lag`, `coverage`, `quality`, `outcomes`, and `runs` only index object containers and transparently fall back to root-level objects when `metrics.*` values are malformed scalars/arrays. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating scalar `metrics.*` sub-containers (`"legacy_scalar_blob"`) still backfill from root objects and emit canonical normalized output, including derived `failureRate=0.25` from root runs. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 74**: Guard scalar `metrics`/`alerts` containers in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` to treat root `metrics` and `alerts` as object-only containers, defaulting scalar/array legacy values to `{}` before field lookup. This prevents jq indexing crashes on malformed legacy snapshots and preserves root-level fallback semantics for counters/alert evaluation. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating scalar `metrics`/`alerts` payloads (`\"legacy_scalar_blob\"`) still emit canonical counters and computed alert values instead of failing. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 73**: Support root-level alert key fallback in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` alert normalization to fallback from `alerts.*` to root-level alert keys for `maxLagWarning|max_lag_warning`, `failureRateWarning|failure_rate_warning`, and `coverageWarning|coverage_warning` when legacy snapshots place alerts at the root. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating root alert keys override computed fallback alerts (high lag + error + low coverage) and preserve canonical false alert output. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 72**: Support root-level core counter fallback in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` counter normalization to fallback from `metrics.*` to root-level fields for `newSignals`, `skippedSignals`, `suppressedSignals`, `dispatchedSignals`, and `errors` (including snake_case/camelCase error aliases) when legacy snapshots place counters at the root. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating root counter payloads backfill canonical counter output and preserve current-cycle failure semantics (`failureRateCurrent=1`, `failureRateWarning=true` when root `error_count=3`). Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 71**: Support root-level failure-rate fields fallback in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` failure-rate normalization to fallback from `metrics.*` to root-level keys for `failureRate`, `failureRateCurrent`, and `failureRateScope` (including snake_case aliases) when legacy snapshots place these fields at the root. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating root-level `failure_rate`, `failure_rate_current`, and `failure_rate_scope` override run-derived/current-error defaults and emit canonical normalized output. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 70**: Support root-level `outcomes` fallback in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` outcomes normalization to read root-level `outcomes` when `metrics.outcomes` is absent, preserving legacy snapshot layouts that place outcome telemetry at the root. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating root outcomes payloads backfill canonical outcomes fields (`resolved|partial|noChange|regressed|validatedSignals|avgTimeToResolutionSeconds|recurrenceSignals`). Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 69**: Support root-level `quality` fallback in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` quality normalization to read root-level `quality` when `metrics.quality` is absent, preserving legacy snapshot layouts that place quality metadata at the root. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating root quality payloads backfill canonical `score`, `findingCount`, and `findingsByType`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 68**: Support root-level `coverage` fallback in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` coverage normalization to read root-level `coverage` when `metrics.coverage` is absent, preserving legacy snapshot layouts that place coverage metadata at the root. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating root coverage payloads backfill canonical `expectedSources`, `seenSources`, `evaluated`, and explicit `ratio`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 67**: Support root-level `lag` fallback in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` lag normalization to read root-level `lag` when `metrics.lag` is absent, preserving legacy snapshot layouts that place lag metadata at the root. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating root `lag` payloads backfill canonical `projectionLagSeconds`, `sources`, and derived `maxSourceLagSeconds`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 66**: Support root-level `runs` fallback in `status` failure-rate backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` failure-rate fallback to read root-level `runs` when `metrics.runs` is absent, preserving historical failure-rate derivation for legacy snapshot layouts. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating root `runs.total=5` and `runs.failed=2` produce canonical `metrics.failureRate=0.4`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 65**: Support object-map quality findings in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` quality normalization to accept legacy object-map shapes for `quality.findingsByType` (for example `{ "timestamp_drift": 2, "orphan_owner": 1 }`) in addition to array forms. Map entries are coerced into canonical `{type,count}` records before existing normalization/scoring, preserving historical finding counts and weighted quality scoring semantics. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating object-map findings backfill to canonical `findingsByType`, `findingCount=3`, and weighted `score=82`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 64**: Support legacy quality score aliases in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` quality score normalization to accept legacy aliases (`quality_score`, `qualityScore`) in addition to canonical `score`. This preserves explicit legacy quality scores instead of always falling back to derived weighted scoring. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating `quality.qualityScore=91` emits canonical `metrics.quality.score=91` with stable findings/count output. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 63**: Support camelCase lag source-array key in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` lag normalization to accept legacy camelCase `lagSources` as an alias for the lag source-array key, in addition to canonical `sources` and snake_case `lag_sources`. This preserves legacy lag source rows and max-lag derivation instead of emitting empty lag sources. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating `lag.lagSources` payloads emit canonical `metrics.lag.sources` and `maxSourceLagSeconds`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 62**: Support camelCase coverage-evaluated aliases in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` coverage evaluation normalization to accept legacy camelCase aliases (`isEvaluated`, `coverageEvaluated`) in addition to canonical `evaluated` and snake_case aliases. This preserves explicit not-evaluated semantics for legacy payloads and prevents fallback `newSignals > 0` from incorrectly forcing coverage evaluation. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating both camelCase aliases emit canonical `coverage.evaluated=false`, `coverage.ratio=null`, and no coverage warning. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 61**: Support camelCase coverage-ratio alias in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` coverage normalization to accept legacy camelCase `coverageRatio` in addition to canonical `ratio` and snake_case `coverage_ratio`. This preserves explicit legacy coverage ratios instead of always recomputing from expected/seen source overlap. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating `coverageRatio=0.75` emits canonical `metrics.coverage.ratio=0.75`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 60**: Support camelCase error counters in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` error normalization to accept legacy camelCase counters (`errorCount`, `errorsCount`) in addition to canonical `errors` and snake_case aliases. This preserves current-cycle failure semantics (`failureRateCurrent`, `failureRateWarning`) for pre-snake legacy snapshots. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating `errorCount=3` backfills to canonical `metrics.errors=3` and raises current-cycle failure flags. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 59**: Support camelCase run counters in `status` failure-rate backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` failure-rate run fallback to also accept legacy camelCase run counter keys (`totalRuns`, `failedRuns`) inside `metrics.runs`, in addition to canonical `total|failed` and snake_case `total_runs|failed_runs`. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` proving `runs.totalRuns=10` and `runs.failedRuns=3` derive canonical `failureRate=0.3`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 58**: Support snake_case lag source array key in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` lag normalization to accept `lag.lag_sources` as a snake_case alias for `lag.sources`. This preserves legacy lag source arrays, including max-lag derivation from source rows, instead of emitting empty lag source output. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating `lag_sources` payloads emit canonical lag sources and `maxSourceLagSeconds`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 57**: Support legacy evaluated-flag aliases in `status` coverage backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` coverage evaluation normalization to accept legacy evaluated aliases (`is_evaluated`, `coverage_evaluated`) in addition to `evaluated`. This preserves explicit evaluated=false semantics in legacy payloads and prevents unintended ratio derivation from fallback defaults. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating `is_evaluated="false"` produces canonical `coverage.evaluated=false` with `ratio=null` and no coverage warning. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 56**: Support snake_case coverage ratio in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` coverage normalization to accept snake_case `coverage_ratio` as an alias for `coverage.ratio`. This preserves explicit legacy ratio payloads instead of always recomputing from expected/seen source overlap. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` proving `coverage_ratio` overrides derived overlap ratio during evaluated coverage. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 55**: Support snake_case error counters in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` error normalization to accept legacy snake_case error counters (`error_count`, `errors_count`) in addition to `errors`. This preserves current-cycle failure semantics (`failureRateCurrent`, `failureRateWarning`) when snapshots provide snake_case error metrics. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating snake_case error counters map to canonical `metrics.errors` and drive failure-current/alert fallbacks correctly. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 54**: Restore TeamForge feed ingestion
  - Status: done
  - Priority: high
  - Tags: ops
  - Retry count: 0
  - Depends on: —
  - Result: Verified the live TeamForge ingestion path is healthy and the new `signal:teamforge_feed_down` alert was stale. Confirmed `.thoughtseed/teamforge/sync-state.json` and `.thoughtseed/teamforge/health.json` show a successful run at `2026-04-21T09:18:12Z` with `lastError=null`, `itemsCount=0`, `quality.score=100`, and all alerts false; `./scripts/teamforge-sync.sh status` reported `errors=0`; `./scripts/teamforge-sync.sh sync --dry-run --no-dispatch` completed with `new=0 skipped=195 suppressed=195 dispatched=0 errors=0 clockify_archived=0 has_more=false`; and `bash -n scripts/teamforge-sync.sh && ./tests/test_teamforge_export_cmd_manifest.sh` passed. No code change was required because TeamForge export resolution and slice materialization were already restored in the live runtime.

- **Step 53**: Support snake_case root timestamp in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` to accept root-level `generated_at` as a legacy alias for `generatedAt`, with trimmed-string normalization before emitting canonical `generatedAt` output. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` asserting `generated_at` inputs are preserved in status output. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 52**: Support snake_case run counters for failure-rate fallback in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` failure-rate fallback to accept snake_case `metrics.runs` keys (`total_runs`, `failed_runs`) in addition to camelCase (`total`, `failed`) when deriving historical `failureRate` from run history. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` verifying snake_case run counters produce the expected fallback failure rate (`0.25`). Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 51**: Support snake_case quality fields in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` quality normalization to accept legacy snake_case quality keys (`findings_by_type`, `finding_count`) in addition to camelCase fields. This prevents legacy snapshots from dropping quality findings/counts during status backfill. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating snake_case quality payloads emit canonical quality output (`findingsByType`, `findingCount`) while preserving explicit `score`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 50**: Support snake_case lag fields in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` lag normalization to accept legacy snake_case lag fields (`projection_lag_seconds`, `max_source_lag_seconds`, `last_sync_at`, `lag_seconds`) in addition to camelCase fields. This prevents legacy snapshots from silently dropping lag values and source timestamps during status backfill. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` validating snake_case lag input emits canonical lag output (`projectionLagSeconds`, `maxSourceLagSeconds`, `sources[*].lastSyncAt`, `sources[*].lagSeconds`). Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 49**: Support snake_case core counter keys in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` counter normalization to accept legacy snake_case metric keys (`new_signals`, `skipped_signals`, `suppressed_signals`, `dispatched_signals`) in addition to camelCase fields. This prevents legacy snapshots from silently emitting zeroed counters during status backfill. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` verifying snake_case counter payloads are preserved in canonical status output (`newSignals`, `skippedSignals`, `suppressedSignals`, `dispatchedSignals`). Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 48**: Support snake_case `failure_rate` in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` failure-rate normalization to read `metrics.failure_rate` as a legacy alias for `metrics.failureRate` before applying numeric coercion/clamping and `runs`-based fallback. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` proving snake_case `failure_rate` overrides `runs` fallback (`failed/total`) and emits canonical `metrics.failureRate`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 47**: Support snake_case failure-rate keys in `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` normalization to accept legacy snake_case failure-rate fields (`failure_rate_current`, `failure_rate_scope`) in addition to camelCase keys. This prevents legacy snapshots from dropping explicit current-cycle failure flags or scope labels during status backfill. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for snake_case `failure_rate_current` (`"yes"` -> `failureRateCurrent=1`) and mixed-case snake_case `failure_rate_scope` normalization (`"  Historical_Lifetime_Runs  "` -> `"historical_lifetime_runs"`). Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 46**: Preserve explicit boolean `false` values during status backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Fixed boolean backfill precedence in `scripts/teamforge-sync.sh` `print_status` by replacing jq `//`-based boolean selection with null-aware selection that preserves explicit `false` values. This corrected false-value drops for `coverage.evaluated`, `failureRateCurrent`, and alert overrides (including snake_case alert keys). Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for snake_case alerts with explicit false values, explicit boolean `failureRateCurrent=false`, and explicit boolean `coverage.evaluated=false` on new-signal cycles. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 45**: Support snake_case coverage source keys in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` coverage normalization to accept legacy snake_case source arrays (`expected_sources`, `seen_sources`) in addition to camelCase keys. This prevents legacy snapshots from silently falling back to default expected/empty seen source sets, which could distort coverage ratios and warnings. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for snake_case coverage keys and verified canonical coverage output (`expectedSources`, `seenSources`, `ratio=1`). Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 44**: Normalize `failureRateCurrent` with shared boolean coercion
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` to normalize `metrics.failureRateCurrent` via shared `to_bool(...)` semantics instead of numeric-only coercion, with fallback to `errors > 0` when absent/unusable. Also enhanced `to_bool(...)` string handling to parse numeric strings (for example `"3"` -> true) before token checks, while preserving unknown-string fallback behavior. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for string-boolean `failureRateCurrent` overrides (`"yes"`, `"no"`) and verified canonical 0/1 output. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 43**: Canonicalize `failureRateScope` case in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` failure-rate scope normalization to lowercase `failureRateScope` after whitespace trimming, while preserving the non-empty fallback contract (`historical_lifetime_runs`). This prevents mixed-case legacy scope values from fragmenting dashboard/grouping semantics. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for mixed-case scope input (`"  Historical_Lifetime_Runs  "`) and verified canonical output (`"historical_lifetime_runs"`). Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 42**: Support snake_case legacy outcomes aliases in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` outcomes normalization to accept additional legacy snake_case aliases: `no_change`, `avg_time_to_resolution_seconds`, `recurrence_signals`, and `validated_signals` (in addition to existing camelCase/kebab variants). This prevents legacy snapshots from silently dropping outcomes fields during status backfill. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for alias-key outcomes payloads and verified canonical outcomes output (`noChange`, `avgTimeToResolutionSeconds`, `recurrenceSignals`, `validatedSignals`). Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 41**: Canonicalize legacy lag source tokens in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` lag normalization to canonicalize lag source labels as trimmed lowercase tokens (`source`) and trim textual lag metadata fields (`entity`, `lastSyncAt`) before output. This prevents legacy case/whitespace drift in `lag.sources` from producing duplicate/misaligned source rows in status dashboards. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for mixed-case/whitespace lag source rows (object + scalar) and verified canonical output plus stable lag alerts. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 40**: Canonicalize legacy quality finding types in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` quality normalization so `metrics.quality.findingsByType` type tokens are canonicalized as trimmed lowercase strings (with empty values mapped to `unknown`) before grouping and weighted score computation. This prevents legacy case/whitespace drift (for example `" TIMESTAMP_DRIFT "`, `"Stale_Mapping"`) from bypassing canonical severity weights and mis-scoring quality. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for mixed-case/whitespace quality finding types and verified canonical grouped output plus weighted score (`62`). Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 39**: Canonicalize legacy coverage source tokens in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` coverage source normalization so `expectedSources` and `seenSources` are canonicalized as trimmed lowercase string sets before dedupe and ratio evaluation. This prevents whitespace/case drift in legacy snapshots from creating false coverage mismatches. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for mixed-case and whitespace-padded source arrays and verified canonical output (`["clockify","huly","slack"]`) with ratio `1`. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 38**: Tighten boolean parsing fallback semantics for legacy `status` fields
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` `to_bool(...)` normalization to trim whitespace, parse explicit true/false string tokens (`true|1|yes` and `false|0|no`), and treat unknown strings as unusable so fallback semantics are applied instead of forcing false. Also wired `coverage.evaluated` normalization through `to_bool(...)` so unknown legacy evaluated strings correctly fallback to `newSignals > 0`. Expanded `tests/test_teamforge_status_failure_rate_backfill.sh` with regression cases for unknown alert strings (fallback to computed alerts), whitespace-padded alert booleans, unknown `coverage.evaluated` strings (fallback to evaluated), and whitespace-padded `coverage.evaluated=" false "` parsing. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`, `./scripts/task-registry.sh stats`.

- **Step 37**: Support scalar entries in legacy `lag.sources` during `status` normalization
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` lag-source normalization to accept object and scalar source rows. Object rows keep structured fields with numeric lag coercion; scalar rows (string/number) now map to canonical records (`source=tostring`, `entity/lastSyncAt/lagSeconds=null`) instead of failing jq indexing. Added regression coverage in `tests/test_teamforge_status_failure_rate_backfill.sh` for mixed scalar/object lag source arrays and `maxSourceLagSeconds` derivation from object lag rows. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 36**: Normalize lag payload scalar types and clamp negative lag values in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` lag normalization to coerce lag source fields (`source`, `entity`, `lastSyncAt`) to stable string/null output, coerce lag numerics (`lagSeconds`, `projectionLagSeconds`, `maxSourceLagSeconds`) to numeric/null, and clamp negative lag values to `0` before alert evaluation. Expanded `tests/test_teamforge_status_failure_rate_backfill.sh` with a malformed lag snapshot case (negative/string lag fields and mixed scalar types) and verified canonical lag output + alert behavior. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 35**: Normalize `failureRateScope` typing and whitespace in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` to normalize `metrics.failureRateScope` as a non-empty trimmed string with fallback to `"historical_lifetime_runs"` for malformed/non-string legacy values. Added regression cases in `tests/test_teamforge_status_failure_rate_backfill.sh` covering non-string scope fallback (`0`) and whitespace-trimmed custom scope values. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 34**: Normalize legacy alert value types in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` to coerce alert fields (`maxLagWarning`, `failureRateWarning`, `coverageWarning`) across boolean/number/string legacy forms, falling back to computed alert defaults only when alert fields are absent/unusable. Added regression cases in `tests/test_teamforge_status_failure_rate_backfill.sh` for typed overrides (`"false"`, `0`, `"no"`, `"yes"`, `"1"`, `"TRUE"`) and verified normalized boolean output. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 33**: Coerce and clamp legacy `coverage.ratio` values in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` coverage normalization to coerce string numeric `coverage.ratio` values and clamp them to `[0,1]` when coverage is evaluated. This prevents malformed legacy ratios (for example `1.8` or `-0.4`) from leaking out-of-range values into status output and alert evaluation. Expanded `tests/test_teamforge_status_failure_rate_backfill.sh` with high/low ratio clamp cases and corresponding `coverageWarning` assertions. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 32**: Normalize legacy coverage source arrays and `evaluated` typing in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` coverage normalization to coerce mixed-type `expectedSources`/`seenSources` arrays into canonical non-empty string sets (with dedupe), and to normalize `coverage.evaluated` across boolean/number/string legacy forms (`true|1|yes`). Ratio and `coverageWarning` now operate on this canonicalized coverage model; explicit string `evaluated="false"` keeps ratio `null`. Expanded `tests/test_teamforge_status_failure_rate_backfill.sh` with mixed-type coverage arrays + string-boolean evaluated cases and adjusted existing ratio assertions for canonical set ordering. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 31**: Coerce and clamp legacy numeric metric fields in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Hardened `scripts/teamforge-sync.sh` `print_status` numeric normalization to coerce string-encoded legacy values and clamp invalid ranges across counters, lag values, quality score/count, failure-rate fields, and outcomes stats. Added fallback safety so missing optional numeric fields cannot empty the jq pipeline. Expanded `tests/test_teamforge_status_failure_rate_backfill.sh` with a malformed numeric snapshot case (string counters, out-of-range quality/failure rates, negative outcomes values) and asserted canonical/clamped output. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task Registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 30**: Backfill core metric counters and lag defaults in `status`
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` to normalize sparse legacy core metric fields (`newSignals`, `skippedSignals`, `suppressedSignals`, `dispatchedSignals`, `errors`) to deterministic numeric defaults and to canonicalize `lag` output (`projectionLagSeconds`, normalized `sources`, and derived `maxSourceLagSeconds` from per-source lag values when missing). Alert fallback now evaluates `maxLagWarning` from normalized lag and `failureRateWarning` from normalized errors. Expanded `tests/test_teamforge_status_failure_rate_backfill.sh` with a sparse-legacy snapshot case asserting counter defaults, lag max derivation, and max-lag alert fallback. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task Registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 29**: Normalize legacy quality/outcome/failure fields in `status` output
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Extended `scripts/teamforge-sync.sh` `print_status` to normalize legacy/malformed `metrics.quality` and sparse `metrics.outcomes` payloads: `findingsByType` now canonicalizes to `{type,count}` objects (including legacy string arrays), `findingCount`/`score` backfill when missing, and outcomes now emit deterministic defaults (`resolved|partial|noChange|regressed|validatedSignals|avgTimeToResolutionSeconds|recurrenceSignals`). Added `failureRate` fallback derivation from `metrics.runs` when missing. Expanded `tests/test_teamforge_status_failure_rate_backfill.sh` with legacy quality/outcome compatibility assertions and re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 28**: Backfill alert defaults in `status` for legacy health snapshots
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Extended `scripts/teamforge-sync.sh` `print_status` to synthesize `alerts` when legacy snapshots omit them, with defaults derived from normalized metrics and manifest thresholds: `maxLagWarning`, `failureRateWarning`, and `coverageWarning`. Added alert-backfill assertions to `tests/test_teamforge_status_failure_rate_backfill.sh` (missing alerts with high lag, current-cycle errors, and low computed coverage) and re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 26**: Derive legacy evaluated coverage ratios during `status` backfill
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Enhanced `scripts/teamforge-sync.sh` `print_status` coverage normalization so if a legacy snapshot has `evaluated=true` but no `ratio`, it computes ratio from `expectedSources` vs normalized unique `seenSources` instead of forcing `0`. Expanded `tests/test_teamforge_status_failure_rate_backfill.sh` with a second legacy snapshot case (missing ratio, duplicate seen source) and asserted computed ratio (`0.5`) plus deduplicated seen sources. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 25**: Normalize legacy coverage fields in `status` output
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Extended `scripts/teamforge-sync.sh` `print_status` to backfill coverage defaults for legacy snapshots (`expectedSources`, `seenSources`, `evaluated`, `ratio`) using current-cycle context when fields are missing. Expanded `tests/test_teamforge_status_failure_rate_backfill.sh` to omit coverage entirely and assert normalized coverage output alongside failure-rate backfills. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 24**: Backfill failure-rate defaults in `status` for legacy health snapshots
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` `print_status` to emit non-null defaults when legacy health files lack newly added failure-rate fields: `failureRateCurrent` now derives from `.metrics.errors` when absent, and `failureRateScope` defaults to `"historical_lifetime_runs"`. Added `tests/test_teamforge_status_failure_rate_backfill.sh` to validate compatibility on old snapshots and re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_status_failure_rate_backfill.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 23**: Disambiguate current-cycle vs historical failure-rate semantics in health output
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Extended `scripts/teamforge-sync.sh` health metrics with `failureRateCurrent` (0/1 current-cycle flag) and `failureRateScope="historical_lifetime_runs"` alongside existing historical `failureRate`, while preserving alert logic (`failureRateWarning` remains current-cycle). Updated status output to include the new fields and expanded `tests/test_teamforge_clockify_policy.sh` assertions for the no-new-signal path. Re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 22**: Mark no-new-signal coverage as not-evaluated in TeamForge health output
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/teamforge-sync.sh` health snapshot generation so cycles with `newSignals == 0` emit `metrics.coverage.evaluated=false` and `metrics.coverage.ratio=null` instead of `ratio=0`, while retaining current alert gating (`coverageWarning` still only on new-signal cycles). Updated `tests/test_teamforge_clockify_policy.sh` to assert the new coverage semantics and re-verified with `bash -n scripts/teamforge-sync.sh tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 21**: Make registry reconciliation reporting overlap-safe and deterministic
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Updated `scripts/task-registry.sh reconcile-inbox` to compute the reported reconcile total as a unique active-task count, preventing over-reporting when a task matches multiple reconciliation lanes (`Task-ID`, processed `Sync-Key`, and duplicate sync-key lineage). Kept per-lane counters for debugging and marked them as overlap-capable in output messaging. Expanded `tests/test_task_registry_reconcile_inbox.sh` with an intentional overlap case (`Task-ID` + `Sync-Key`) and asserted the reported total remains `3` (actual unique reconciles). Re-verified with `bash -n scripts/task-registry.sh tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_dispatch_task_sync_key_dedupe.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, and live `./scripts/teamforge-sync.sh sync --no-dispatch`.

- **Step 18**: Add persistent review-intent sync-key reuse to stop cyclical redispatch churn
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Extended `scripts/dispatch-task.sh` sync-key dedupe to reuse existing `review-intent` tasks even when prior tasks are completed (not only active), preventing recurring recreation of identical review-intent tickets each cycle. Updated `tests/test_dispatch_task_sync_key_dedupe.sh` to validate active-duplicate and completed-reuse paths, then re-ran registry/TeamForge regressions and live sync/reconcile checks; repeated 195-record replay batches now stay `newSignals=0`, `quality.score=100`, alerts false, and registry pending remains zero after reconciliation.

- **Step 17**: Prevent duplicate dispatch creation for recurring sync-key signals
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Added active `--sync-key` dedupe in `scripts/dispatch-task.sh` so dispatch returns an existing active task instead of creating duplicate registry/inbox entries. Expanded reconciliation coverage in `tests/test_task_registry_reconcile_inbox.sh` (processed `Sync-Key` path) and added `tests/test_dispatch_task_sync_key_dedupe.sh` for direct dispatch guard validation. Re-verified all TeamForge/registry tests and live state; registry now self-cleans to `Pending: 0` while health remains stable (`quality.score=100`, alerts false on clean cycles).

- **Step 16**: Document TeamForge registry/alert hardening for operations continuity
  - Status: done
  - Priority: medium
  - Tags: ops, documentation
  - Retry count: 0
  - Depends on: —
  - Result: Updated `memory/teamforge-ops-feed.md` with reconciliation and alert/quality semantics, and added `vault/engineering/2026-04-20-teamforge-registry-and-alert-hardening.md` capturing scope, implementation, verification commands, and operational outcomes.

- **Step 15**: Eliminate remaining TeamForge registry drift and alert noise in live cycles
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Extended `task-registry.sh reconcile-inbox` to reconcile from processed `Sync-Key` entries and review-intent duplicate sync keys (in addition to direct `Task-ID` matches), then integrated and validated those paths with updated regression coverage. Hardened `teamforge-sync.sh` quality/alert behavior so no-new-signal cycles force empty quality findings and `failureRateWarning` reflects current-cycle errors only. Live reconciliation + sync now reports `Task Registry Pending: 0`, `quality.score=100`, and all health alerts false on clean cycles. Verified with `bash -n scripts/teamforge-sync.sh`, `bash -n scripts/task-registry.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_teamforge_clockify_policy.sh`, `./tests/test_teamforge_export_cmd_manifest.sh`, and live `./scripts/task-registry.sh reconcile-inbox`, `./scripts/teamforge-sync.sh sync --no-dispatch`, `./scripts/teamforge-sync.sh status`.

- **Step 14**: Auto-apply inbox reconciliation during TeamForge sync
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Integrated `task-registry.sh reconcile-inbox` into `scripts/teamforge-sync.sh` (non-dry-run path) so sync cycles automatically close registry tasks that inbox owners already marked processed, then compute outcomes from the reconciled state. Added integration regression `tests/test_teamforge_reconcile_inbox_hook.sh` to prove sync-time reconciliation works, and validated end-to-end with `bash -n scripts/teamforge-sync.sh`, `bash -n scripts/task-registry.sh`, `bash -n tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_teamforge_reconcile_inbox_hook.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_teamforge_clockify_policy.sh`, and `./tests/test_teamforge_export_cmd_manifest.sh`.

- **Step 13**: Add deterministic inbox→registry reconciliation for processed task drift
  - Status: done
  - Priority: medium
  - Tags: ops, reliability, code
  - Retry count: 0
  - Depends on: —
  - Result: Added `reconcile-inbox` command to `scripts/task-registry.sh` to parse `agents/*/INBOX.md` processed sections and mark matching pending registry tasks as `completed`, with metadata refresh. Fixed parser portability for macOS/BSD awk by avoiding `match(..., array)` captures. Ran live reconciliation and closed 11 stale pending records from inbox-recovery drift, leaving only currently active pending work. Added regression test `tests/test_task_registry_reconcile_inbox.sh` and verified with `bash -n scripts/task-registry.sh`, `bash -n tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_task_registry_reconcile_inbox.sh`, `./tests/test_teamforge_clockify_policy.sh`, and `./tests/test_teamforge_export_cmd_manifest.sh`.

- **Step 10**: Implement the Clockify TeamForge info-policy batching, archive the 197-item backlog, and document the rule
  - Status: done
  - Priority: medium
  - Tags: ops, triage, code
  - Retry count: 0
  - Depends on: batch-2026-04-20-clockify-backlog
  - Result: Updated `scripts/teamforge-sync.sh` so low-severity `clockify.time_entry.logged` signals materialize as 14-day daily aggregates in active TeamForge surfaces, archive informational Clockify registry tasks with `clockify_info_non_actionable` / `clockify_info_retention_window`, and persist audit totals in `.thoughtseed/teamforge/sync-state.json`; fixed the temp TeamForge test harnesses to pin `REPO_ROOT`; passed `bash tests/test_teamforge_clockify_policy.sh` and `bash tests/test_teamforge_export_cmd_manifest.sh`; documented the rule at `vault/engineering/2026-04-20-teamforge-clockify-info-policy.md`; and verified live state with `./scripts/teamforge-sync.sh sync --no-dispatch`, leaving `teamforgePendingClockify=0`, `teamforgeArchivedClockify=197`, `totals.aggregatesVisible=12`, and no higher-severity/non-Clockify items in the current cursor window.

- **Step 9**: Escalate the 197-item Clockify TeamForge inbox backlog to jarvis for triage and backlog-shaping
  - Status: done
  - Priority: medium
  - Tags: ops, code, triage
  - Retry count: 0
  - Depends on: —
  - Result: Dispatched escalation `task-1776674244-7681` to `agents/jarvis/INBOX.md` with backlog scope (197 `clockify.time_entry.logged` items), triage context, and explicit ask for leadership policy on retention/collapse/auto-archive.

- **Step 8**: Normalize the Paperclip runtime root and reconcile host supervision from the canonical repo
  - Status: done
  - Priority: high
  - Tags: ops, infra
  - Retry count: 0
  - Depends on: —
  - Result: Verified canonical root alignment via `./scripts/runtime-root-guard.sh assert` (`status: ok`), reconciled host supervision from canonical root, fixed launchd restart race in `scripts/host-supervisor.sh` (`launchd_start_one` now uses bounded bootstrap retries/backoff after bootout), and validated live restart+status. Details documented at `vault/engineering/2026-04-20-runtime-root-and-host-supervision-reconciliation.md`.

- **Step 7**: Restore TeamForge feed ingestion
  - Status: done
  - Priority: high
  - Tags: ops
  - Retry count: 0
  - Depends on: —
  - Result: Verified live TeamForge export resolution instead of trusting the stale drifted-runtime fixture: `.thoughtseed/teamforge/latest-feed.json` was generated at `2026-04-20T08:29:56Z` with `schemaVersion=teamforge-ingest/v1`, `feedSchemaVersion=agent_feed/v1`, `quality.score=100`, and `items=[]`; `./scripts/teamforge-sync.sh status` reported `newSignals=0` and `errors=0`; and `./scripts/teamforge-sync.sh sync --dry-run --no-dispatch` fetched the feed successfully with `items=0`, `hasMore=false`, and no errors.

- **Step 6**: Evaluate host-native supervision migration for `loop-runner` and `babysitter` and return engineering recommendation
  - Status: done
  - Priority: medium
  - Tags: ops, infra
  - Retry count: 0
  - Depends on: task-1775936805-00e9
  - Result: Confirmed the repo already implements host-native supervision in `scripts/host-supervisor.sh`, verified live macOS LaunchAgents via `./scripts/host-supervisor.sh status` and `launchctl print gui/$(id -u)/com.thoughtseed.loop-runner` / `launchctl print gui/$(id -u)/com.thoughtseed.babysitter`, and documented the supervisor choice, migration steps, restart/health semantics, stale-PID cleanup, verification proof, and remaining tradeoffs in `vault/engineering/2026-04-12-host-supervisor-migration-and-verification.md` with supporting runtime observations in `vault/engineering/2026-04-12-daemon-persistence-runtime-observations.md`.

- **Step 5**: Build SENTINEL QA handoff remediation package and suspend unsafe delegation lane
  - Status: done
  - Priority: medium
  - Tags: ops, qa
  - Retry count: 0
  - Depends on: task-1775933717-b3f4c
  - Result: Identified the no-output failure mode (`--output-last-message` empty with structured markers still present on stderr), implemented runtime fallback recovery in `scripts/loop-runner.sh`, documented the remediation package and QA delegation policy at `vault/engineering/2026-04-11-sentinel-qa-runtime-remediation-package.md`, and set explicit exit criteria for resuming SENTINEL ownership of this QA lane.

- **Step 4**: Verify loop-runner signal-safe sleep fix and execute fail-fast QA retry strategy
  - Status: done
  - Priority: medium
  - Tags: ops, qa
  - Retry count: 1
  - Depends on: task-1775931418-b2d1
  - Result: Verified daemon stability directly in Engineering (`./scripts/loop-runner.sh start` followed by 30-second checks through 240 seconds, all RUNNING; PID 33808). Re-opened SENTINEL with a narrower QA task (`task-1775932448-81fa`) and reduced SENTINEL `max_step_timeout` to `2m` for fail-fast behavior; SENTINEL still returned `empty_output` timeout at 120s, so the retry task was marked failed and escalated to JARVIS as `task-1775932882-6be7`.

- **Step 3**: Sync THO-1 engineering package and move issue to founder review
  - Status: done
  - Priority: high
  - Tags: ops, strategy
  - Retry count: 0
  - Depends on: task-1775914956-5023
  - Result: Updated Paperclip issue `THO-1` (`9ca2a2fd-9b2a-4ed7-92c7-d3ca2835f172`) to `in_review` via authenticated API mutation using runtime `PAPERCLIP_RUN_ID`, and posted founder-review handoff comment `13e5cd5a-4a1a-4fea-8b75-1bedbf7edf16` summarizing delivered engineering artifacts and explicit founder-only decisions.

- **Step 1**: Create engineering hiring plan and roadmap decomposition
  - Status: done
  - Priority: high
  - Tags: strategy
  - Retry count: 0
  - Depends on: task-1775918684-a857
  - Result: Completed delegated task `task-1775923170-ec65` and created `vault/engineering/2026-04-11-engineering-hiring-plan-and-roadmap.md` with the hiring sequence, interview loop, 30/60/90 expectations, phase-based roadmap decomposition, and explicit hiring triggers.

- **Step 2**: Investigate Paperclip auth regression: CLAWD local-cli returns 403 Board access required
  - Status: done
  - Priority: high
  - Tags: ops
  - Retry count: 0
  - Depends on: task-1775917911-21cb
  - Result: Using existing Paperclip server logs plus CLI source, traced the `403` to `paperclipai agent local-cli` inheriting the agent runtime `PAPERCLIP_API_KEY` and authenticating as CLAWD against the board-only `/api/agents/:id/keys` route. Wrote the diagnosis and workaround to `vault/engineering/2026-04-11-paperclip-local-cli-auth-regression.md`.
