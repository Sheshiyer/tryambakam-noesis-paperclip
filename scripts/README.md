# scripts

## Antahkarana fixtures

`generate-antahkarana-fixtures.mjs` (Node >= 20, no extra dependencies) reads a paperclip-tn tenant **read-only** and writes labelled dashboard fixtures for antahkarana.

```bash
node scripts/generate-antahkarana-fixtures.mjs --tenant-root . --out /tmp/antahkarana-fixtures
```

`--tenant-root` defaults to the repo root. `--out` defaults to a JSON document on stdout. `--clock` sets `scanned_at` and defaults to `2026-08-12T00:00:00Z`. Record timestamps come from the ledger. The script does not call `Date.now` or `Math.random`, and it does not use the network.

It reads `.planning/run-records.jsonl` line by line. Malformed lines increment `skipped` and are left unchanged. Valid rows keep `ts`, `task`, `status`, `duration_ms`, and `proof_path`, with `source` `paperclip-tn`, `mode` `fixture`, and `schema` `paperclip-run-record.v1`. Non-empty string `error` and `suggested_action` values are kept; every other unknown key is dropped. A ledger with at least one valid row writes `paperclip_run_records.json` (variant `sample`) and `paperclip_run_records.ledger.jsonl` (those sample records). The empty variant is always written (`state` `empty`, `reason` `cron has not run yet`, `records` `[]`). A missing ledger or a ledger with no valid rows does not invent a sample file.

`vault_para_stats` uses read model `VaultParaStatsOk`. The payload is four buckets (`01-Projects` … `04-Archives`), each with `name`, `file_count`, and `dir_count`, plus `scanned_at`. A `sample` file with real counts is written only when those PARA directories exist. `vault_para_stats.empty.json` is always written, with all four counts at zero.

`index.json` lists one entry per command (`vault_para_stats`, then `paperclip_run_records`) with `sample` and `empty` filename keys. `sample` is `null` when that file was not produced. The paperclip entry gains a `ledger` key only when `paperclip_run_records.ledger.jsonl` is written.

The process refuses to write inside the tenant root, a `twc-vault` path, or `/Volumes/`. It exits non-zero, without writing fixtures, if any output value contains a token marker (`nk_`, `sk-`, `ghp_`, `github_pat_`, `xox`, `AKIA`, `BEGIN PRIVATE`, `Bearer `, `api_key`, `password`, `/Volumes/`, `/Users/`) or a key named `token`, `password`, `secret`, `api_key`, or `authorization`. Paths in the output are relative.

`npm test` runs `scripts/generate-antahkarana-fixtures.test.mjs`.
