# scripts

## Antahkarana fixtures

`generate-antahkarana-fixtures.mjs` (Node >= 20, no extra dependencies) reads a paperclip-tn tenant **read-only** and writes labelled dashboard fixtures for antahkarana.

```bash
node scripts/generate-antahkarana-fixtures.mjs --tenant-root . --out /tmp/antahkarana-fixtures
```

`--tenant-root` defaults to the repo root. `--out` defaults to a JSON document on stdout. `--clock` sets `scanned_at` and defaults to `2026-08-12T00:00:00Z`. It must be a real UTC timestamp: impossible dates such as `2026-99-99T99:99:99Z` exit 2. Record timestamps come from the ledger. The script does not call `Date.now` or `Math.random`, and it does not use the network.

It reads `.planning/run-records.jsonl` line by line. Malformed lines increment `skipped` and are left unchanged. Valid rows keep `ts`, `task`, `status`, `duration_ms`, and `proof_path`, with `source` `paperclip-tn`, `mode` `fixture`, and `schema` `paperclip-run-record.v1`. Non-empty string `error` and `suggested_action` values are kept; every other unknown key is dropped. A ledger with at least one valid row writes `paperclip_run_records.json` (variant `sample`) and `paperclip_run_records.ledger.jsonl` (those sample records). The empty variant is always written (`state` `empty`, `reason` `cron has not run yet`, `records` `[]`). A missing ledger or a ledger with no valid rows does not invent a sample file.

`vault_para_stats` uses read model `VaultParaStatsOk`. The payload is four buckets (`01-Projects` … `04-Archives`), each with `name`, `file_count`, and `dir_count`, plus `scanned_at`. A `sample` file with real counts is written only when those PARA directories exist. `vault_para_stats.empty.json` is always written, with all four counts at zero.

`index.json` lists one entry per command (`vault_para_stats`, then `paperclip_run_records`) with `sample` and `empty` filename keys. `sample` is `null` when that file was not produced. The paperclip entry gains a `ledger` key only when `paperclip_run_records.ledger.jsonl` is written.

The process refuses to write inside the tenant root, a `twc-vault` path, or `/Volumes/`. That check uses both the given path and the real path of `--out` (or its nearest existing ancestor, plus any directory the generator still has to create). A symlink at `--out` itself is refused. A pre-existing ancestor symlink, such as macOS `/tmp` pointing at `/private/tmp`, is allowed when that resolved location still passes the zone checks, so the `/tmp/antahkarana-fixtures` example works there. Each output file is opened without following symlinks, and an existing symlink or non-regular file at that name is left untouched. Planned files are written to temporary files in `--out` (`O_CREAT|O_EXCL|O_NOFOLLOW`, then `fsync`) and renamed into place only after every write succeeds, `index.json` last. If any staged write fails, the temporary files are removed and every existing fixture file is left unchanged. `PAPERCLIP_FIXTURES_FAULT_AFTER_WRITES` is a test-only hook (honoured only when `NODE_ENV=test` or `PAPERCLIP_FIXTURES_TEST_FAULT=1`) that fails the Nth staged write. A stale `paperclip_run_records.json`, `paperclip_run_records.ledger.jsonl`, or `vault_para_stats.json` is deleted only when the manifest read before that replacement is this generator's (`fixture`, `not_live`, `label` `FIXTURE`, and the fixture description), the manifest lists that filename, and the file itself is a regular file carrying the same fixture marker. A missing or forged manifest leaves those files alone. If a planned write fails, the previous sample, ledger, and index are left in place. It exits non-zero, without writing fixtures, if any output value contains a token marker (`nk_`, `sk-`, `ghp_`, `github_pat_`, `xox`, `AKIA`, `BEGIN PRIVATE`, `Bearer `, `api_key`, `password`, `/Volumes/`, `/Users/`) or a key named `token`, `password`, `secret`, `api_key`, or `authorization`. Paths in the output are relative.

`npm test` runs `scripts/generate-antahkarana-fixtures.test.mjs`.
