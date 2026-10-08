# Job run

Host-agnostic contract for one scheduled job attempt: a timeout, a bounded retry with backoff, and a terminal state of `ok`, `failed`, or `dead-lettered`.

OpenClaw is an ingest source only. This module does not import it. Grok Bot, dots, Muse, and Hermes can apply the same policy. The host-agnostic module contract is the one named in [AGENTS.md](../../AGENTS.md).

Wiring this contract into the loop-runner, the dead-letter folder, stale recovery in the live loop, and the outbound delivery queue stays in [#9](https://github.com/Sheshiyer/tryambakam-noesis-paperclip/issues/9). That issue stays open. This module does not change live cron jobs.

Cost stays UNRESOLVED. Nothing here authorizes paid dispatch.

## Schema

[`job-run.schema.json`](job-run.schema.json) is JSON Schema draft 2020-12. The record's `schema` field is `job-run.v1`.

A record carries:

- `job_id` — stable id of the job. Length 1 to 200. The schema pattern and the library use the same rule: no `/` or `\`, no `..`, no ASCII control characters, no U+2028 or U+2029, and no leading or trailing whitespace. Those checks scan the whole id. A space in the middle is allowed.
- `attempt` — 1-based attempt number
- `timeout_ms` — budget for this attempt
- `retry.max_attempts` — total attempts allowed, including the first
- `retry.backoff` — `fixed` (`delay_ms`) or `exponential` (`initial_ms`, `multiplier`, optional `max_ms`). Exponential delay is `floor(initial_ms * multiplier^(attempt-1))`, then capped by `max_ms` when set. When `multiplier` is below 1 and `initial_ms` is already at least `max_ms`, the delay starts at the cap and then decays below it. The library computes that delay. The schema stores the policy fields.
- `state` — `running` while the attempt is open; `ok`, `failed`, or `dead-lettered` when it is terminal
- `started_at`, `finished_at`, `next_attempt_at` — honest ISO-8601 UTC timestamps with millisecond precision (`YYYY-MM-DDTHH:mm:ss.sssZ`)
- `makes_model_call` and `cost_cap` — see Cost cap below
- `error` — null while running or `ok`; a non-empty string when `failed` or `dead-lettered`. `error` and `suggested_action` are rejected when they contain a home shortcut or an absolute host path (`~` then any run of non-whitespace, non-separator characters, then `/` or `\`, at a token boundary, including `~/` and `~\`, plus `/Users`, `/home`, `/root`, `/Volumes`, `/mnt`, `/media`, `/private/var`, `/var/folders`, a drive letter, or a UNC share), in either slash style and any letter case. The name between `~` and the separator may contain `@`, `+`, or letters outside ASCII. A bare `~` in prose, such as `retry took ~5 seconds`, is not a home shortcut. An `http://` or `https://` URL is not a Windows drive path. Repo-relative text such as `proofs/sample-job.txt` stays allowed. The library home-path pattern and the schema `error` pattern's home alternative are the same source.

`finished_at` and `next_attempt_at` are null on a running attempt. `next_attempt_at` is set only on a failed attempt that still has a retry. When it is set, the library requires it to equal `finished_at` plus `backoffDelayMs(backoff, attempt)`. It is null once `attempt` equals `retry.max_attempts`. A dead-lettered attempt has no next attempt, and the library accepts that state only when `attempt` equals `retry.max_attempts`. The library rejects impossible calendar dates such as `2026-02-31`.

## Rules only the library enforces

The schema and the library share every rule the schema can express, including the `job_id` pattern, the model-call cost cap, and the absolute-path checks on `error`. These rules stay in the library because draft 2020-12 cannot express them:

- `next_attempt_at` is null when `attempt` equals `retry.max_attempts`. That compares two integers.
- A non-null `next_attempt_at` equals `finished_at` plus the backoff delay for that attempt. That computes the delay.
- `state` `dead-lettered` requires `attempt` to equal `retry.max_attempts`. That is the same integer comparison.
- Exponential decay below `max_ms` when `multiplier` is below 1. The schema stores `initial_ms`, `multiplier`, and `max_ms`. `backoffDelayMs` computes the delay.
- `proof_path` on a cockpit projection is not a schema field. The library rejects a URI scheme such as `https://example.com/proof` before the row is emitted. The ledger reader has its own relative-path check and is unchanged here.

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

A job with `makes_model_call: true` is not retried unless `cost_cap` is an explicit finite number greater than or equal to zero. Zero is an explicit ceiling. `null` and a missing `cost_cap` are not. The JSON Schema uses the same rule: `attempt` of 2 or more with `makes_model_call` true is valid only when `cost_cap` is a number. A failed model-call record with a null `cost_cap` cannot set `next_attempt_at`. `openRun` and `assertJobRun` throw `RetryRefused` (`code` `cost-cap-required`) for that record. `resolveFailure` throws the same error and leaves the failed attempt unchanged, with `next_attempt_at` still null.

The first attempt may start without a cap. Dead-lettering the attempt that has reached `max_attempts` does not start another model call. This module does not price a call and does not authorize spend.

## Cockpit run records

Antahkarana reads run records from this repo. The shape it reads is the one this repo already emits for the dashboard command `paperclip_run_records`, read model `PaperclipReadModel`. The reader is `normalizeRecord` in [`scripts/generate-antahkarana-fixtures.mjs`](../../scripts/generate-antahkarana-fixtures.mjs).

A ledger row is kept when:

- `ts` is a non-empty string. A job-run projection uses `finished_at`.
- `task` is a non-empty string. A job-run projection uses `job_id`.
- `status` is a non-empty string. A job-run projection uses the terminal state `ok`, `failed`, or `dead-lettered`.
- `duration_ms` is a finite number. A job-run projection uses `finished_at - started_at` in milliseconds.
- `proof_path` is a non-empty relative path. Absolute paths, a leading `~`, and any `..` segment are dropped. `toCockpitRunRecord` also rejects a URI scheme, such as `https://example.com/proof`, so that URL is not emitted as a proof path.
- `error` is present and is kept when it is a non-empty string.
- `suggested_action` is present and is kept when it is a non-empty string.

Every other key on the ledger row is dropped. The reader then writes the fixture labels `source` `paperclip-tn`, `mode` `fixture`, and `schema` `paperclip-run-record.v1`. Those labels are applied on read. `toCockpitRunRecord` supplies the fields the reader keeps and leaves the fixture labels to that reader.

An empty ledger is reported as `state` `empty`, `reason` `cron has not run yet`. A ledger with at least one valid row is `state` `ok`.

## Dry-run

`npm test` includes `modules/job-run/job-run.test.mjs`. The dry-run drives one job through failure, a scheduled retry, and dead-letter, then marks a second run failed once the injected clock is past its timeout. No cron job is executed.
