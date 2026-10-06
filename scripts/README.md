# scripts

## Antahkarana fixtures

`generate-antahkarana-fixtures.mjs` (Node >= 20, no extra dependencies) reads a paperclip-tn tenant **read-only** and writes labelled dashboard fixtures for antahkarana.

```bash
node scripts/generate-antahkarana-fixtures.mjs --tenant-root . --out /tmp/antahkarana-fixtures
```

`--tenant-root` defaults to the repo root. `--out` defaults to a JSON document on stdout. `--clock` sets `scanned_at` and defaults to `2026-08-12T00:00:00Z`. Record timestamps come from the ledger. The script does not call `Date.now` or `Math.random`, and it does not use the network.

It reads `.planning/run-records.jsonl` line by line. Malformed lines increment `skipped` and are left unchanged. Valid rows keep `ts`, `task`, `status`, `duration_ms`, and `proof_path`, with `source` `paperclip-tn`, `mode` `fixture`, and `schema` `paperclip-run-record.v1`. A ledger with at least one valid row writes `paperclip_run_records.json` (variant `sample`), `paperclip_run_records.empty.json` (variant `empty`), `paperclip_run_records.ledger.jsonl` (those sample records), and an `index.json` row. A missing ledger or a ledger with no valid rows writes only the honest empty variant (`state` `empty`, `reason` `cron has not run yet`, `records` `[]`) and does not invent rows.

`vault_para_stats` is a `sample` with `file_count` / `dir_count` when real `01-Projects` … `04-Archives` directories exist under the tenant root. Otherwise the script writes the empty variant: four buckets, all counts zero.

The process refuses to write inside the tenant root, a `twc-vault` path, or `/Volumes/`. It exits non-zero, without writing fixtures, if any output value contains a token marker (`nk_`, `sk-`, `ghp_`, `github_pat_`, `xox`, `AKIA`, `BEGIN PRIVATE`, `Bearer `, `api_key`, `password`, `/Volumes/`, `/Users/`) or a key named `token`, `password`, `secret`, `api_key`, or `authorization`. Paths in the output are relative.

`npm test` runs `scripts/generate-antahkarana-fixtures.test.mjs`.
