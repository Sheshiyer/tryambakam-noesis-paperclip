import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { lstat, mkdtemp, mkdir, readdir, readFile, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const SCRIPT = fileURLToPath(new URL('./generate-antahkarana-fixtures.mjs', import.meta.url));
const INDEX_DESCRIPTION = 'Labelled dashboard command fixtures. Not live vault, Selemene, sidecar, or cron data.';

function expectedIndex({ vaultSample, paperclipSample, ledger = false }) {
  const paperclip = {
    command: 'paperclip_run_records',
    read_model: 'PaperclipReadModel',
    sample: paperclipSample,
    empty: 'paperclip_run_records.empty.json',
  };
  if (ledger) paperclip.ledger = 'paperclip_run_records.ledger.jsonl';
  return {
    fixture: true,
    label: 'FIXTURE',
    not_live: true,
    description: INDEX_DESCRIPTION,
    commands: [
      {
        command: 'vault_para_stats',
        read_model: 'VaultParaStatsOk',
        sample: vaultSample,
        empty: 'vault_para_stats.empty.json',
      },
      paperclip,
    ],
  };
}

function runGen(args, env = process.env) {
  return spawnSync(process.execPath, [SCRIPT, ...args], { encoding: 'utf8', env });
}

async function makeTenant() {
  const root = await mkdtemp(path.join(tmpdir(), 'paperclip-tenant-'));
  await mkdir(path.join(root, '.planning'), { recursive: true });
  return root;
}

const SAMPLE_ROWS = [
  {
    ts: '2026-08-11T03:04:05Z',
    task: 'reconcile-local',
    status: 'ok',
    duration_ms: 1200,
    proof_path: '.planning/proofs/reconcile.md',
    source: 'somewhere-else',
    mode: 'live',
    schema: 'other',
    notes: 'dropped',
  },
  {
    ts: '2026-08-11T04:00:00Z',
    task: 'sync-issues',
    status: 'failed',
    duration_ms: 40,
    proof_path: 'proofs/sync-issues.txt',
  },
];

test('temp-dir ledger emits the sample variant, ledger, empty variant, and an index row', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const ledger = `${SAMPLE_ROWS.map((row) => JSON.stringify(row)).join('\n')}\n`;
  await writeFile(path.join(tenant, '.planning', 'run-records.jsonl'), ledger);

  const result = runGen(['--tenant-root', tenant, '--out', out, '--clock', '2026-08-12T00:00:00Z']);
  assert.equal(result.status, 0, result.stderr);

  const sample = JSON.parse(await readFile(path.join(out, 'paperclip_run_records.json'), 'utf8'));
  const empty = JSON.parse(await readFile(path.join(out, 'paperclip_run_records.empty.json'), 'utf8'));
  const index = JSON.parse(await readFile(path.join(out, 'index.json'), 'utf8'));
  const ledgerOut = await readFile(path.join(out, 'paperclip_run_records.ledger.jsonl'), 'utf8');

  assert.deepEqual(Object.keys(sample), ['fixture', 'label', 'not_live', 'command', 'read_model', 'variant', 'payload']);
  assert.equal(sample.fixture, true);
  assert.equal(sample.label, 'FIXTURE');
  assert.equal(sample.not_live, true);
  assert.equal(sample.command, 'paperclip_run_records');
  assert.equal(sample.read_model, 'PaperclipReadModel');
  assert.equal(sample.variant, 'sample');
  assert.deepEqual(Object.keys(sample.payload), ['state', 'reason', 'records', 'source', 'ledger', 'skipped']);
  assert.equal(sample.payload.state, 'ok');
  assert.equal(sample.payload.reason, null);
  assert.equal(sample.payload.source, 'paperclip-tn');
  assert.equal(sample.payload.ledger, '.planning/run-records.jsonl');
  assert.equal(sample.payload.skipped, 0);
  assert.equal(sample.payload.records.length, 2);
  for (const record of sample.payload.records) {
    assert.deepEqual(Object.keys(record), ['ts', 'task', 'status', 'duration_ms', 'proof_path', 'source', 'mode', 'schema']);
    assert.equal(record.source, 'paperclip-tn');
    assert.equal(record.mode, 'fixture');
    assert.equal(record.schema, 'paperclip-run-record.v1');
    assert.ok(record.proof_path.length > 0);
    assert.equal(record.proof_path.startsWith('/'), false);
  }
  assert.equal(sample.payload.records[0].ts, '2026-08-11T03:04:05Z');
  assert.equal(sample.payload.records[0].task, 'reconcile-local');
  assert.equal(sample.payload.records[1].duration_ms, 40);

  const ledgerRecords = ledgerOut.trim().split('\n').map((line) => JSON.parse(line));
  assert.deepEqual(ledgerRecords, sample.payload.records);

  assert.equal(empty.variant, 'empty');
  assert.equal(empty.payload.state, 'empty');
  assert.equal(empty.payload.reason, 'cron has not run yet');
  assert.deepEqual(empty.payload.records, []);
  assert.equal(empty.payload.skipped, 0);

  assert.deepEqual(index, expectedIndex({
    vaultSample: null,
    paperclipSample: 'paperclip_run_records.json',
    ledger: true,
  }));

  const para = JSON.parse(await readFile(path.join(out, 'vault_para_stats.empty.json'), 'utf8'));
  assert.equal(para.command, 'vault_para_stats');
  assert.equal(para.read_model, 'VaultParaStatsOk');
  assert.equal(para.variant, 'empty');
  assert.equal(para.payload.scanned_at, '2026-08-12T00:00:00Z');
  assert.deepEqual(para.payload.buckets.map((bucket) => bucket.name), [
    '01-Projects',
    '02-Areas',
    '03-Resources',
    '04-Archives',
  ]);
  for (const bucket of para.payload.buckets) {
    assert.equal(bucket.file_count, 0);
    assert.equal(bucket.dir_count, 0);
  }

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('missing ledger emits only the honest empty paperclip variant', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));

  const result = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(result.status, 0, result.stderr);

  const empty = JSON.parse(await readFile(path.join(out, 'paperclip_run_records.empty.json'), 'utf8'));
  assert.equal(empty.variant, 'empty');
  assert.equal(empty.payload.state, 'empty');
  assert.equal(empty.payload.reason, 'cron has not run yet');
  assert.deepEqual(empty.payload.records, []);
  assert.equal(empty.payload.skipped, 0);
  assert.equal(empty.payload.source, 'paperclip-tn');
  assert.equal(empty.payload.ledger, '.planning/run-records.jsonl');

  await assert.rejects(readFile(path.join(out, 'paperclip_run_records.json'), 'utf8'));
  await assert.rejects(readFile(path.join(out, 'paperclip_run_records.ledger.jsonl'), 'utf8'));

  const index = JSON.parse(await readFile(path.join(out, 'index.json'), 'utf8'));
  assert.deepEqual(index, expectedIndex({ vaultSample: null, paperclipSample: null }));
  const paraEmpty = JSON.parse(await readFile(path.join(out, 'vault_para_stats.empty.json'), 'utf8'));
  assert.equal(paraEmpty.read_model, 'VaultParaStatsOk');
  assert.equal(paraEmpty.variant, 'empty');

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('a malformed ledger line is counted in skipped and is not repaired', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const good = {
    ts: '2026-08-11T03:04:05Z',
    task: 'reconcile-local',
    status: 'ok',
    duration_ms: 15,
    proof_path: 'proofs/reconcile.md',
  };
  const text = `${JSON.stringify(good)}\n{this is not json\n{"task":"partial"}\n`;
  await writeFile(path.join(tenant, '.planning', 'run-records.jsonl'), text);

  const result = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(result.status, 0, result.stderr);

  const sample = JSON.parse(await readFile(path.join(out, 'paperclip_run_records.json'), 'utf8'));
  assert.equal(sample.payload.skipped, 2);
  assert.equal(sample.payload.records.length, 1);
  assert.equal(sample.payload.records[0].task, 'reconcile-local');
  assert.equal(sample.payload.records[0].proof_path, 'proofs/reconcile.md');
  assert.equal(JSON.stringify(sample).includes('partial'), false);
  assert.equal(JSON.stringify(sample).includes('this is not json'), false);

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('zero valid rows emit only the empty variant and keep the skipped count', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  await writeFile(path.join(tenant, '.planning', 'run-records.jsonl'), 'not-json\n{"duration_ms":"12"}\n');

  const result = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(result.status, 0, result.stderr);

  await assert.rejects(readFile(path.join(out, 'paperclip_run_records.json'), 'utf8'));
  const empty = JSON.parse(await readFile(path.join(out, 'paperclip_run_records.empty.json'), 'utf8'));
  assert.equal(empty.payload.state, 'empty');
  assert.deepEqual(empty.payload.records, []);
  assert.equal(empty.payload.skipped, 2);
  const index = JSON.parse(await readFile(path.join(out, 'index.json'), 'utf8'));
  assert.deepEqual(index, expectedIndex({ vaultSample: null, paperclipSample: null }));
  assert.equal(Object.hasOwn(index.commands[1], 'ledger'), false);

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('secrets guard exits non-zero and does not write the marker', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const leaked = {
    ts: '2026-08-11T03:04:05Z',
    task: 'ghp_exampleleakedtoken',
    status: 'ok',
    duration_ms: 1,
    proof_path: 'proofs/ok.md',
  };
  await writeFile(path.join(tenant, '.planning', 'run-records.jsonl'), `${JSON.stringify(leaked)}\n`);

  const result = runGen(['--tenant-root', tenant, '--out', out]);
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout.includes('ghp_'), false);
  assert.equal(result.stderr.includes('ghp_'), false);
  assert.match(result.stderr, /secrets guard/);
  await assert.rejects(readFile(path.join(out, 'paperclip_run_records.json'), 'utf8'));
  await assert.rejects(readFile(path.join(out, 'index.json'), 'utf8'));

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('failed rows keep error and suggested_action and drop every other unknown key', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const failed = {
    ts: '2026-08-11T05:00:00Z',
    task: 'sync-issues',
    status: 'failed',
    duration_ms: 40,
    proof_path: 'proofs/sync-issues.txt',
    error: 'exit 1',
    suggested_action: 'rerun reconcile',
    notes: 'dropped',
    token: 'not-copied',
  };
  const blankOptional = {
    ts: '2026-08-11T06:00:00Z',
    task: 'reconcile-local',
    status: 'ok',
    duration_ms: 8,
    proof_path: 'proofs/reconcile.md',
    error: '',
    suggested_action: '',
    extra: { nested: true },
  };
  await writeFile(
    path.join(tenant, '.planning', 'run-records.jsonl'),
    `${JSON.stringify(failed)}\n${JSON.stringify(blankOptional)}\n`,
  );

  const result = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(result.status, 0, result.stderr);
  const sample = JSON.parse(await readFile(path.join(out, 'paperclip_run_records.json'), 'utf8'));
  const [withOptional, withoutOptional] = sample.payload.records;
  assert.deepEqual(Object.keys(withOptional), [
    'ts',
    'task',
    'status',
    'duration_ms',
    'proof_path',
    'source',
    'mode',
    'schema',
    'error',
    'suggested_action',
  ]);
  assert.equal(withOptional.error, 'exit 1');
  assert.equal(withOptional.suggested_action, 'rerun reconcile');
  assert.equal(Object.hasOwn(withOptional, 'notes'), false);
  assert.equal(Object.hasOwn(withOptional, 'token'), false);
  assert.deepEqual(Object.keys(withoutOptional), [
    'ts',
    'task',
    'status',
    'duration_ms',
    'proof_path',
    'source',
    'mode',
    'schema',
  ]);
  assert.equal(JSON.stringify(sample).includes('dropped'), false);
  assert.equal(JSON.stringify(sample).includes('not-copied'), false);

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('secrets guard trips when a preserved error field contains a marker', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const leaked = {
    ts: '2026-08-11T05:00:00Z',
    task: 'sync-issues',
    status: 'failed',
    duration_ms: 40,
    proof_path: 'proofs/sync-issues.txt',
    error: 'sk-exampleleaked',
    suggested_action: 'rerun reconcile',
  };
  await writeFile(path.join(tenant, '.planning', 'run-records.jsonl'), `${JSON.stringify(leaked)}\n`);

  const result = runGen(['--tenant-root', tenant, '--out', out]);
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout.includes('sk-'), false);
  assert.equal(result.stderr.includes('sk-'), false);
  assert.match(result.stderr, /secrets guard/);
  await assert.rejects(readFile(path.join(out, 'paperclip_run_records.json'), 'utf8'));

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('generator source does not call Math.random', () => {
  const result = spawnSync('grep', ['-n', 'Math.random', SCRIPT], { encoding: 'utf8' });
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, '');
});

test('refuses to write inside the tenant root, twc-vault, or /Volumes', async () => {
  const tenant = await makeTenant();
  const inside = path.join(tenant, 'fixtures-out');
  const insideResult = runGen(['--tenant-root', tenant, '--out', inside]);
  assert.notEqual(insideResult.status, 0);
  assert.match(insideResult.stderr, /tenant root/);

  const vaultParent = await mkdtemp(path.join(tmpdir(), 'vault-parent-'));
  const vaultOut = path.join(vaultParent, 'twc-vault', 'out');
  const vaultResult = runGen(['--tenant-root', tenant, '--out', vaultOut]);
  assert.notEqual(vaultResult.status, 0);
  assert.match(vaultResult.stderr, /twc-vault/);

  const volumesResult = runGen(['--tenant-root', tenant, '--out', '/Volumes/paperclip-fixtures']);
  assert.notEqual(volumesResult.status, 0);
  assert.match(volumesResult.stderr, /\/Volumes\//);

  await rm(tenant, { recursive: true, force: true });
  await rm(vaultParent, { recursive: true, force: true });
});

test('real PARA directories produce counted buckets and no invented paperclip rows', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const projects = path.join(tenant, '01-Projects');
  await mkdir(path.join(projects, 'alpha'), { recursive: true });
  await writeFile(path.join(projects, 'alpha', 'note.md'), 'hello\n');
  await mkdir(path.join(tenant, '03-Resources'), { recursive: true });

  const result = runGen(['--tenant-root', tenant, '--out', out, '--clock', '2026-08-12T00:00:00Z']);
  assert.equal(result.status, 0, result.stderr);

  const para = JSON.parse(await readFile(path.join(out, 'vault_para_stats.json'), 'utf8'));
  assert.equal(para.variant, 'sample');
  assert.equal(para.read_model, 'VaultParaStatsOk');
  assert.equal(para.payload.scanned_at, '2026-08-12T00:00:00Z');
  const byName = Object.fromEntries(para.payload.buckets.map((bucket) => [bucket.name, bucket]));
  assert.equal(byName['01-Projects'].file_count, 1);
  assert.equal(byName['01-Projects'].dir_count, 1);
  assert.equal(byName['02-Areas'].file_count, 0);
  assert.equal(byName['03-Resources'].file_count, 0);
  assert.equal(byName['03-Resources'].dir_count, 0);
  assert.equal(byName['04-Archives'].file_count, 0);
  const paraEmpty = JSON.parse(await readFile(path.join(out, 'vault_para_stats.empty.json'), 'utf8'));
  assert.equal(paraEmpty.read_model, 'VaultParaStatsOk');
  assert.equal(paraEmpty.variant, 'empty');
  for (const bucket of paraEmpty.payload.buckets) {
    assert.equal(bucket.file_count, 0);
    assert.equal(bucket.dir_count, 0);
  }
  await assert.rejects(readFile(path.join(out, 'paperclip_run_records.json'), 'utf8'));
  const index = JSON.parse(await readFile(path.join(out, 'index.json'), 'utf8'));
  assert.deepEqual(index, expectedIndex({
    vaultSample: 'vault_para_stats.json',
    paperclipSample: null,
  }));

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('symlinked index.json pointing into the tenant is refused and the tenant file is unchanged', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const target = path.join(tenant, 'kept.txt');
  await writeFile(target, 'original\n');
  await symlink(target, path.join(out, 'index.json'));

  const result = runGen(['--tenant-root', tenant, '--out', out]);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /symlink|non-regular/);
  assert.equal(await readFile(target, 'utf8'), 'original\n');
  const linkStat = await lstat(path.join(out, 'index.json'));
  assert.equal(linkStat.isSymbolicLink(), true);

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('--out that is a symlink into the tenant is refused', async () => {
  const tenant = await makeTenant();
  const realOut = path.join(tenant, 'escaped-out');
  await mkdir(realOut);
  const linkParent = await mkdtemp(path.join(tmpdir(), 'paperclip-out-link-'));
  const link = path.join(linkParent, 'out');
  await symlink(realOut, link);

  const result = runGen(['--tenant-root', tenant, '--out', link]);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /symlink|tenant root/);
  await assert.rejects(readFile(path.join(realOut, 'index.json'), 'utf8'));
  await assert.rejects(readFile(path.join(realOut, 'paperclip_run_records.empty.json'), 'utf8'));

  await rm(tenant, { recursive: true, force: true });
  await rm(linkParent, { recursive: true, force: true });
});

test('rerun with a missing ledger removes stale sample and ledger files', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const ledgerPath = path.join(tenant, '.planning', 'run-records.jsonl');
  const row = {
    ts: '2026-08-11T03:04:05Z',
    task: 'reconcile-local',
    status: 'ok',
    duration_ms: 15,
    proof_path: 'proofs/reconcile.md',
  };
  await writeFile(ledgerPath, `${JSON.stringify(row)}\n`);
  await writeFile(path.join(out, 'keep.txt'), 'keep\n');

  const first = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(first.status, 0, first.stderr);
  await readFile(path.join(out, 'paperclip_run_records.json'), 'utf8');
  await readFile(path.join(out, 'paperclip_run_records.ledger.jsonl'), 'utf8');

  await rm(ledgerPath);
  const second = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(second.status, 0, second.stderr);
  await assert.rejects(readFile(path.join(out, 'paperclip_run_records.json'), 'utf8'));
  await assert.rejects(readFile(path.join(out, 'paperclip_run_records.ledger.jsonl'), 'utf8'));
  const index = JSON.parse(await readFile(path.join(out, 'index.json'), 'utf8'));
  assert.equal(index.commands[1].sample, null);
  assert.equal(Object.hasOwn(index.commands[1], 'ledger'), false);
  await readFile(path.join(out, 'paperclip_run_records.empty.json'), 'utf8');
  assert.equal(await readFile(path.join(out, 'keep.txt'), 'utf8'), 'keep\n');

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

function generatorManifest({ sample = null, ledger = false } = {}) {
  const paperclip = {
    command: 'paperclip_run_records',
    read_model: 'PaperclipReadModel',
    sample,
    empty: 'paperclip_run_records.empty.json',
  };
  if (ledger) paperclip.ledger = 'paperclip_run_records.ledger.jsonl';
  return {
    fixture: true,
    label: 'FIXTURE',
    not_live: true,
    description: INDEX_DESCRIPTION,
    commands: [
      {
        command: 'vault_para_stats',
        read_model: 'VaultParaStatsOk',
        sample: null,
        empty: 'vault_para_stats.empty.json',
      },
      paperclip,
    ],
  };
}

function fixtureSampleFile() {
  return `${JSON.stringify({
    fixture: true,
    label: 'FIXTURE',
    not_live: true,
    command: 'paperclip_run_records',
    read_model: 'PaperclipReadModel',
    variant: 'sample',
    payload: { records: [] },
  }, null, 2)}\n`;
}

test('a user-created reserved file with no manifest survives', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const reserved = path.join(out, 'paperclip_run_records.json');
  await writeFile(reserved, 'user-owned\n');

  const result = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(await readFile(reserved, 'utf8'), 'user-owned\n');
  const index = JSON.parse(await readFile(path.join(out, 'index.json'), 'utf8'));
  assert.equal(index.commands[1].sample, null);

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('a file listed by a genuine earlier manifest is removed', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  await writeFile(path.join(out, 'index.json'), `${JSON.stringify(generatorManifest({
    sample: 'paperclip_run_records.json',
    ledger: true,
  }), null, 2)}\n`);
  await writeFile(path.join(out, 'paperclip_run_records.json'), fixtureSampleFile());
  await writeFile(path.join(out, 'paperclip_run_records.ledger.jsonl'), `${JSON.stringify({
    ts: '2026-08-11T03:04:05Z',
    task: 'reconcile-local',
    status: 'ok',
    duration_ms: 15,
    proof_path: 'proofs/reconcile.md',
    source: 'paperclip-tn',
    mode: 'fixture',
    schema: 'paperclip-run-record.v1',
  })}\n`);
  await writeFile(path.join(out, 'vault_para_stats.json'), 'unlisted-user\n');

  const result = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(result.status, 0, result.stderr);
  await assert.rejects(readFile(path.join(out, 'paperclip_run_records.json'), 'utf8'));
  await assert.rejects(readFile(path.join(out, 'paperclip_run_records.ledger.jsonl'), 'utf8'));
  assert.equal(await readFile(path.join(out, 'vault_para_stats.json'), 'utf8'), 'unlisted-user\n');

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('a forged or missing manifest does not delete reserved files', async () => {
  const tenant = await makeTenant();
  const forgedOut = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const forged = {
    fixture: true,
    not_live: true,
    label: 'FIXTURE',
    description: 'forged manifest',
    commands: [
      {
        command: 'paperclip_run_records',
        read_model: 'PaperclipReadModel',
        sample: 'paperclip_run_records.json',
        empty: 'paperclip_run_records.empty.json',
        ledger: 'paperclip_run_records.ledger.jsonl',
      },
    ],
  };
  await writeFile(path.join(forgedOut, 'index.json'), `${JSON.stringify(forged)}\n`);
  await writeFile(path.join(forgedOut, 'paperclip_run_records.json'), fixtureSampleFile());
  await writeFile(path.join(forgedOut, 'paperclip_run_records.ledger.jsonl'), 'forged-ledger\n');

  const forgedResult = runGen(['--tenant-root', tenant, '--out', forgedOut]);
  assert.equal(forgedResult.status, 0, forgedResult.stderr);
  assert.equal(await readFile(path.join(forgedOut, 'paperclip_run_records.json'), 'utf8'), fixtureSampleFile());
  assert.equal(await readFile(path.join(forgedOut, 'paperclip_run_records.ledger.jsonl'), 'utf8'), 'forged-ledger\n');

  const missingOut = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  await writeFile(path.join(missingOut, 'vault_para_stats.json'), fixtureSampleFile());
  await writeFile(path.join(missingOut, 'paperclip_run_records.ledger.jsonl'), 'keep-me\n');
  const missingResult = runGen(['--tenant-root', tenant, '--out', missingOut]);
  assert.equal(missingResult.status, 0, missingResult.stderr);
  assert.equal(await readFile(path.join(missingOut, 'vault_para_stats.json'), 'utf8'), fixtureSampleFile());
  assert.equal(await readFile(path.join(missingOut, 'paperclip_run_records.ledger.jsonl'), 'utf8'), 'keep-me\n');

  const replacedOut = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  await writeFile(path.join(replacedOut, 'index.json'), `${JSON.stringify(generatorManifest({
    sample: 'paperclip_run_records.json',
  }), null, 2)}\n`);
  await writeFile(path.join(replacedOut, 'paperclip_run_records.json'), 'replaced-by-user\n');
  const replacedResult = runGen(['--tenant-root', tenant, '--out', replacedOut]);
  assert.equal(replacedResult.status, 0, replacedResult.stderr);
  assert.equal(await readFile(path.join(replacedOut, 'paperclip_run_records.json'), 'utf8'), 'replaced-by-user\n');

  await rm(tenant, { recursive: true, force: true });
  await rm(forgedOut, { recursive: true, force: true });
  await rm(missingOut, { recursive: true, force: true });
  await rm(replacedOut, { recursive: true, force: true });
});

test('a manifest with sample null and a ledger does not delete the ledger', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const ledgerBody = `${JSON.stringify({
    ts: '2026-08-11T03:04:05Z',
    task: 'reconcile-local',
    status: 'ok',
    duration_ms: 15,
    proof_path: 'proofs/reconcile.md',
    source: 'paperclip-tn',
    mode: 'fixture',
    schema: 'paperclip-run-record.v1',
  })}\n`;
  const ledgerOut = path.join(out, 'paperclip_run_records.ledger.jsonl');
  await writeFile(path.join(out, 'index.json'), `${JSON.stringify(generatorManifest({
    sample: null,
    ledger: true,
  }), null, 2)}\n`);
  await writeFile(ledgerOut, ledgerBody);

  const result = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(await readFile(ledgerOut, 'utf8'), ledgerBody);

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('impossible --clock exits 2', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  for (const clock of ['2026-99-99T99:99:99Z', '2026-02-31T00:00:00Z', '2026-01-01T24:00:00Z']) {
    const result = runGen(['--tenant-root', tenant, '--out', out, '--clock', clock]);
    assert.equal(result.status, 2, `${clock}\n${result.stderr}`);
    await assert.rejects(readFile(path.join(out, 'index.json'), 'utf8'));
  }

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('a failed write leaves the previous sample, ledger, and index intact', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const ledgerPath = path.join(tenant, '.planning', 'run-records.jsonl');
  const row = {
    ts: '2026-08-11T03:04:05Z',
    task: 'reconcile-local',
    status: 'ok',
    duration_ms: 15,
    proof_path: 'proofs/reconcile.md',
  };
  await writeFile(ledgerPath, `${JSON.stringify(row)}\n`);
  const first = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(first.status, 0, first.stderr);

  const samplePath = path.join(out, 'paperclip_run_records.json');
  const ledgerOut = path.join(out, 'paperclip_run_records.ledger.jsonl');
  const indexPath = path.join(out, 'index.json');
  const emptyPath = path.join(out, 'paperclip_run_records.empty.json');
  const emptyBefore = await readFile(emptyPath, 'utf8');
  const sampleBefore = await readFile(samplePath, 'utf8');
  const ledgerBefore = await readFile(ledgerOut, 'utf8');
  const indexBefore = await readFile(indexPath, 'utf8');

  const second = runGen(['--tenant-root', tenant, '--out', out], {
    ...process.env,
    NODE_ENV: 'test',
    PAPERCLIP_FIXTURES_FAULT_AFTER_WRITES: '2',
  });
  assert.notEqual(second.status, 0);
  assert.match(second.stderr, /staged write failed/);
  assert.equal(await readFile(emptyPath, 'utf8'), emptyBefore);
  assert.equal(await readFile(samplePath, 'utf8'), sampleBefore);
  assert.equal(await readFile(ledgerOut, 'utf8'), ledgerBefore);
  assert.equal(await readFile(indexPath, 'utf8'), indexBefore);
  const names = await readdir(out);
  assert.equal(names.some((name) => name.startsWith('.paperclip-fixture-stage.')), false);

  const quietEnv = {
    ...process.env,
    NODE_ENV: 'production',
    PAPERCLIP_FIXTURES_FAULT_AFTER_WRITES: '1',
  };
  delete quietEnv.PAPERCLIP_FIXTURES_TEST_FAULT;
  const ignored = runGen(['--tenant-root', tenant, '--out', out], quietEnv);
  assert.equal(ignored.status, 0, ignored.stderr);

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('a failed commit rename restores every prior fixture file', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const ledgerPath = path.join(tenant, '.planning', 'run-records.jsonl');
  const firstRow = {
    ts: '2026-08-11T03:04:05Z',
    task: 'reconcile-local',
    status: 'ok',
    duration_ms: 15,
    proof_path: 'proofs/reconcile.md',
  };
  await writeFile(ledgerPath, `${JSON.stringify(firstRow)}\n`);
  const first = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(first.status, 0, first.stderr);

  const watched = [
    'paperclip_run_records.json',
    'paperclip_run_records.empty.json',
    'paperclip_run_records.ledger.jsonl',
    'vault_para_stats.empty.json',
    'index.json',
  ];
  const before = new Map();
  for (const name of watched) {
    before.set(name, await readFile(path.join(out, name), 'utf8'));
  }

  const secondRow = {
    ts: '2026-08-11T09:00:00Z',
    task: 'sync-issues',
    status: 'failed',
    duration_ms: 40,
    proof_path: 'proofs/sync-issues.txt',
    error: 'exit 1',
    suggested_action: 'rerun reconcile',
  };
  await writeFile(ledgerPath, `${JSON.stringify(secondRow)}\n`);
  const second = runGen(['--tenant-root', tenant, '--out', out], {
    ...process.env,
    NODE_ENV: 'test',
    PAPERCLIP_FIXTURES_FAULT_AFTER_RENAMES: '2',
  });
  assert.notEqual(second.status, 0);
  assert.match(second.stderr, /commit rename failed/);
  for (const name of watched) {
    assert.equal(await readFile(path.join(out, name), 'utf8'), before.get(name), name);
  }
  const names = await readdir(out);
  assert.equal(names.some((name) => name.startsWith('.paperclip-fixture-stage.')), false);
  assert.equal(names.some((name) => name.startsWith('.paperclip-fixture-backup.')), false);

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('a failed restore keeps the backup of the previous fixture', async () => {
  const tenant = await makeTenant();
  const out = await mkdtemp(path.join(tmpdir(), 'paperclip-fixtures-'));
  const ledgerPath = path.join(tenant, '.planning', 'run-records.jsonl');
  const firstRow = {
    ts: '2026-08-11T03:04:05Z',
    task: 'reconcile-local',
    status: 'ok',
    duration_ms: 15,
    proof_path: 'proofs/reconcile.md',
  };
  await writeFile(ledgerPath, `${JSON.stringify(firstRow)}\n`);
  const first = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(first.status, 0, first.stderr);

  const watched = [
    'paperclip_run_records.json',
    'paperclip_run_records.empty.json',
    'paperclip_run_records.ledger.jsonl',
    'vault_para_stats.empty.json',
    'index.json',
  ];
  const before = new Map();
  for (const name of watched) {
    before.set(name, await readFile(path.join(out, name), 'utf8'));
  }

  const secondRow = {
    ts: '2026-08-11T09:00:00Z',
    task: 'sync-issues',
    status: 'failed',
    duration_ms: 40,
    proof_path: 'proofs/sync-issues.txt',
    error: 'exit 1',
    suggested_action: 'rerun reconcile',
  };
  await writeFile(ledgerPath, `${JSON.stringify(secondRow)}\n`);
  const second = runGen(['--tenant-root', tenant, '--out', out], {
    ...process.env,
    NODE_ENV: 'test',
    PAPERCLIP_FIXTURES_FAULT_AFTER_RENAMES: '3',
    PAPERCLIP_FIXTURES_FAULT_AFTER_RESTORES: '2',
  });
  assert.notEqual(second.status, 0);
  assert.match(second.stderr, /commit rename failed/);
  const match = second.stderr.match(/retained backup after failed restore: (\S+)/);
  assert.ok(match, second.stderr);
  const backupPath = match[1];
  assert.equal(path.dirname(backupPath), out);
  assert.match(path.basename(backupPath), /^\.paperclip-fixture-backup\./);
  assert.equal(await readFile(backupPath, 'utf8'), before.get('paperclip_run_records.json'));
  assert.notEqual(await readFile(path.join(out, 'paperclip_run_records.json'), 'utf8'), before.get('paperclip_run_records.json'));
  for (const name of watched) {
    if (name === 'paperclip_run_records.json') continue;
    assert.equal(await readFile(path.join(out, name), 'utf8'), before.get(name), name);
  }
  const names = await readdir(out);
  assert.equal(names.some((name) => name.startsWith('.paperclip-fixture-stage.')), false);
  assert.deepEqual(
    names.filter((name) => name.startsWith('.paperclip-fixture-backup.')),
    [path.basename(backupPath)],
  );

  await rm(tenant, { recursive: true, force: true });
  await rm(out, { recursive: true, force: true });
});

test('a symlinked ancestor is allowed when its real path passes zone checks', async () => {
  const tenant = await makeTenant();
  const realBase = await mkdtemp(path.join(tmpdir(), 'paperclip-real-'));
  const linkParent = await mkdtemp(path.join(tmpdir(), 'paperclip-anc-'));
  const ancestor = path.join(linkParent, 'tmp-like');
  await symlink(realBase, ancestor);
  const out = path.join(ancestor, 'fixtures');

  const result = runGen(['--tenant-root', tenant, '--out', out]);
  assert.equal(result.status, 0, result.stderr);
  const index = JSON.parse(await readFile(path.join(realBase, 'fixtures', 'index.json'), 'utf8'));
  assert.equal(index.fixture, true);
  assert.equal(index.not_live, true);

  await rm(tenant, { recursive: true, force: true });
  await rm(realBase, { recursive: true, force: true });
  await rm(linkParent, { recursive: true, force: true });
});

test('a symlinked ancestor into a forbidden zone is refused', async () => {
  const tenant = await makeTenant();
  const linkParent = await mkdtemp(path.join(tmpdir(), 'paperclip-anc-'));
  const ancestor = path.join(linkParent, 'into-tenant');
  await symlink(tenant, ancestor);
  const out = path.join(ancestor, 'fixtures');

  const result = runGen(['--tenant-root', tenant, '--out', out]);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /tenant root/);
  await assert.rejects(readFile(path.join(tenant, 'fixtures', 'index.json'), 'utf8'));
  await assert.rejects(readFile(path.join(tenant, 'index.json'), 'utf8'));

  await rm(tenant, { recursive: true, force: true });
  await rm(linkParent, { recursive: true, force: true });
});
