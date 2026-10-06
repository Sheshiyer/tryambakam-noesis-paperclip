import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { lstat, mkdtemp, mkdir, readFile, rm, symlink, writeFile } from 'node:fs/promises';
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

function runGen(args) {
  return spawnSync(process.execPath, [SCRIPT, ...args], { encoding: 'utf8' });
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
