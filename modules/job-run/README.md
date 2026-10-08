# Job run

Host-agnostic contract for one scheduled job attempt: a timeout, a bounded retry with backoff, and a terminal state of `ok`, `failed`, or `dead-lettered`.

OpenClaw is an ingest source only. This module does not import it. Grok Bot, dots, Muse, and Hermes can apply the same policy. The host-agnostic module contract is the one named in [AGENTS.md](../../AGENTS.md).

Wiring this contract into the loop-runner, the dead-letter folder, stale recovery in the live loop, and the outbound delivery queue stays in [#9](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/9). That issue stays open. This module does not change live cron jobs.

Cost stays UNRESOLVED. Nothing here authorizes paid dispatch.

## Schema

[`job-run.schema.json`](job-run.schema.json) is JSON Schema draft 2020-12. The record's `schema` field is `job-run.v1`.

A record carries:

- `job_id` — stable id of the job
- `attempt` — 1-based attempt number
- `timeout_ms` — budget for this attempt
- `retry.max_attempts` — total attempts allowed, including the first
- `retry.backoff` — `fixed` (`delay_ms`) or `exponential` (`initial_ms`, `multiplier`, optional `max_ms`)
- `state` — `running` while the attempt is open; `ok`, `failed`, or `dead-lettered` when it is terminal
- `started_at`, `finished_at`, `next_attempt_at` — honest ISO-8601 UTC timestamps with millisecond precision (`YYYY-MM-DDTHH:mm:ss.sssZ`)
- `makes_model_call` and `cost_cap` — see Cost cap below
- `error` — null while running or `ok`; a non-empty string when `failed` or `dead-lettered`. `error` and `suggested_action` are rejected when they contain a home shortcut or an absolute host path (`~/`, `/Users`, `/home`, `/root`, `/Volumes`, `/mnt`, `/media`, `/private/var`, `/var/folders`, a drive letter, or a UNC share), in either slash style and any letter case. Repo-relative text such as `proofs/sample-job.txt` stays allowed.

`finished_at` and `next_attempt_at` are null on a running attempt. `next_attempt_at` is set only on a failed attempt that still has a retry. A dead-lettered attempt has no next attempt. The library rejects impossible calendar dates such as `2026-02-31`.

## Library

[`job-run.mjs`](job-run.mjs) has no dependencies. It does not read or write files, use the network, or call `Date.now`. Every timestamp comes from a clock function the caller passes in. The clock returns a `Date` or an ISO-8601 UTC string, and the library stores the canonical millisecond form.

- `openRun(config, clock)` starts attempt 1, or `config.attempt` when opening a later try. A later try that makes a model call requires an explicit `cost_cap`
- `recordSuccess(run, clock)` and `recordFailure(run, clock, { error })` close a running attempt
- `backoffDelayMs(backoff, attempt)` is the wait after that attempt fails
- `resolveFailure(run, clock)` returns `{ action: 'retry', next_attempt_at, run }` or `{ action: 'dead-letter', run }`
- `isStale(run, clock)` is true when a running attempt's elapsed time is past `timeout_ms` (the deadline itself is still inside the budget)
- `markStaleFailed(run, clock)` records that attempt as `failed` with error `stale: exceeded timeout`
- `toCockpitRunRecord(run, { proof_path, suggested_action })` projects a terminal attempt into the cockpit ledger shape below

A retry is a new attempt record. `resolveFailure` does not mutate the failed record it is given. The caller opens the next attempt when its clock reaches `next_attempt_at`.

The attempt that reaches `max_attempts` and fails is dead-lettered. Dead-letter is a stop, so it does not require a cost cap.

## Cost cap

A job with `makes_model_call: true` is not retried unless `cost_cap` is an explicit finite number greater than or equal to zero. Zero is an explicit ceiling. `null` and a missing `cost_cap` are not. `openRun` throws `RetryRefused` (`code` `cost-cap-required`) when `attempt` is greater than 1. `resolveFailure` throws the same error and leaves the failed attempt unchanged, with `next_attempt_at` still null.

The first attempt may start without a cap. Dead-lettering the attempt that has reached `max_attempts` does not start another model call. This module does not price a call and does not authorize spend.

## Cockpit run records

Antahkarana reads run records from this repo. The shape it reads is the one this repo already emits for the dashboard command `paperclip_run_records`, read model `PaperclipReadModel`. The reader is `normalizeRecord` in [`scripts/generate-antahkarana-fixtures.mjs`](../../scripts/generate-antahkarana-fixtures.mjs).

A ledger row is kept when:

- `ts` is a non-empty string. A job-run projection uses `finished_at`.
- `task` is a non-empty string. A job-run projection uses `job_id`.
- `status` is a non-empty string. A job-run projection uses the terminal state `ok`, `failed`, or `dead-lettered`.
- `duration_ms` is a finite number. A job-run projection uses `finished_at - started_at` in milliseconds.
- `proof_path` is a non-empty relative path. Absolute paths, a leading `~`, and any `..` segment are dropped.
- `error` is present and is kept when it is a non-empty string.
- `suggested_action` is present and is kept when it is a non-empty string.

Every other key on the ledger row is dropped. The reader then writes the fixture labels `source` `paperclip-tn`, `mode` `fixture`, and `schema` `paperclip-run-record.v1`. Those labels are applied on read. `toCockpitRunRecord` supplies the fields the reader keeps and leaves the fixture labels to that reader.

An empty ledger is reported as `state` `empty`, `reason` `cron has not run yet`. A ledger with at least one valid row is `state` `ok`.

## Dry-run

`npm test` includes `modules/job-run/job-run.test.mjs`. The dry-run drives one job through failure, a scheduled retry, and dead-letter, then marks a second run failed once the injected clock is past its timeout. No cron job is executed.
