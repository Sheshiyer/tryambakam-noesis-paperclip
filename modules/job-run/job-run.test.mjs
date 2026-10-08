import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import { normalizeRecord } from '../../scripts/generate-antahkarana-fixtures.mjs';
import {
  RetryRefused,
  SCHEMA_ID,
  TERMINAL_STATES,
  assertJobRun,
  backoffDelayMs,
  formatTimestamp,
  isStale,
  markStaleFailed,
  openRun,
  recordFailure,
  recordSuccess,
  resolveFailure,
  toCockpitRunRecord,
} from './job-run.mjs';

const SCHEMA_URL = new URL('./job-run.schema.json', import.meta.url);
const LIBRARY_URL = new URL('./job-run.mjs', import.meta.url);
const PROOF = 'proofs/sample-job.txt';

function manualClock(start) {
  let current = start;
  const calls = [];
  const clock = () => {
    calls.push(current);
    return current;
  };
  clock.calls = calls;
  clock.set = (value) => {
    current = value;
  };
  return clock;
}

function sampleConfig(overrides = {}) {
  return {
    job_id: 'sample-job',
    timeout_ms: 5_000,
    retry: {
      max_attempts: 2,
      backoff: { strategy: 'fixed', delay_ms: 1_000 },
    },
    makes_model_call: false,
    ...overrides,
  };
}

function assertSchemaShape(run, schema) {
  for (const key of schema.required) {
    assert.ok(Object.hasOwn(run, key), `missing ${key}`);
  }
  assert.deepEqual(Object.keys(run).sort(), Object.keys(schema.properties).sort());
  assert.equal(run.schema, schema.properties.schema.const);
  assert.ok(schema.properties.state.enum.includes(run.state));
  assert.match(run.started_at, new RegExp(schema.$defs.timestamp.pattern));
  if (run.finished_at !== null) assert.match(run.finished_at, new RegExp(schema.$defs.timestamp.pattern));
  if (run.next_attempt_at !== null) assert.match(run.next_attempt_at, new RegExp(schema.$defs.timestamp.pattern));
  assertJobRun(run);
}

function assertCockpitRow(run, proofPath = PROOF) {
  const row = toCockpitRunRecord(run, { proof_path: proofPath });
  const normalized = normalizeRecord(row);
  assert.ok(normalized);
  assert.equal(normalized.ts, run.finished_at);
  assert.equal(normalized.task, run.job_id);
  assert.equal(normalized.status, run.state);
  assert.equal(normalized.duration_ms, row.duration_ms);
  assert.equal(normalized.proof_path, proofPath);
  assert.equal(normalized.source, 'paperclip-tn');
  assert.equal(normalized.mode, 'fixture');
  assert.equal(normalized.schema, 'paperclip-run-record.v1');
  if (run.error === null) assert.equal(Object.hasOwn(normalized, 'error'), false);
  else assert.equal(normalized.error, run.error);
  assert.deepEqual(Object.keys(row).filter((key) => key !== 'error' && key !== 'suggested_action'), [
    'ts',
    'task',
    'status',
    'duration_ms',
    'proof_path',
  ]);
  return normalized;
}

test('dry-run walks one job through fail, retry, and dead-letter, and marks a stale run failed', async () => {
  const schema = JSON.parse(await readFile(SCHEMA_URL, 'utf8'));
  const clock = manualClock('2026-08-12T00:00:00.000Z');
  const config = sampleConfig();

  const first = openRun(config, clock);
  assert.equal(first.state, 'running');
  assert.equal(first.attempt, 1);
  assert.equal(first.started_at, '2026-08-12T00:00:00.000Z');
  assert.equal(first.finished_at, null);
  assertSchemaShape(first, schema);

  clock.set('2026-08-12T00:00:01.000Z');
  const failed = recordFailure(first, clock, { error: 'upstream unavailable' });
  assert.equal(failed.state, 'failed');
  assert.equal(failed.finished_at, '2026-08-12T00:00:01.000Z');
  assert.equal(failed.next_attempt_at, null);
  assert.equal(first.state, 'running');

  const retry = resolveFailure(failed, clock);
  assert.equal(retry.action, 'retry');
  assert.equal(retry.next_attempt_at, '2026-08-12T00:00:02.000Z');
  assert.equal(retry.run.state, 'failed');
  assert.equal(retry.run.next_attempt_at, '2026-08-12T00:00:02.000Z');
  assert.equal(failed.next_attempt_at, null);
  assertSchemaShape(retry.run, schema);
  assert.equal(assertCockpitRow(retry.run).status, 'failed');
  assert.equal(assertCockpitRow(retry.run).duration_ms, 1_000);

  clock.set(retry.next_attempt_at);
  const second = openRun({ ...config, attempt: 2 }, clock);
  assert.equal(second.state, 'running');
  assert.equal(second.attempt, 2);
  assert.equal(second.started_at, '2026-08-12T00:00:02.000Z');

  clock.set('2026-08-12T00:00:02.400Z');
  const failedAgain = recordFailure(second, clock, { error: 'upstream unavailable' });
  const dead = resolveFailure(failedAgain, clock);
  assert.equal(dead.action, 'dead-letter');
  assert.equal(dead.run.state, 'dead-lettered');
  assert.equal(dead.run.attempt, 2);
  assert.equal(dead.run.next_attempt_at, null);
  assert.equal(dead.run.error, 'upstream unavailable');
  assert.equal(dead.run.finished_at, '2026-08-12T00:00:02.400Z');
  assertSchemaShape(dead.run, schema);
  const deadRow = assertCockpitRow(dead.run);
  assert.equal(deadRow.status, 'dead-lettered');
  assert.equal(deadRow.duration_ms, 400);
  assert.equal(deadRow.error, 'upstream unavailable');

  const staleClock = manualClock('2026-08-12T01:00:00.000Z');
  const open = openRun(sampleConfig({ timeout_ms: 1_000 }), staleClock);
  staleClock.set('2026-08-12T01:00:01.000Z');
  assert.equal(isStale(open, staleClock), false);
  staleClock.set('2026-08-12T01:00:01.001Z');
  assert.equal(isStale(open, staleClock), true);
  const stale = markStaleFailed(open, staleClock);
  assert.equal(stale.state, 'failed');
  assert.equal(stale.finished_at, '2026-08-12T01:00:01.001Z');
  assert.equal(stale.error, 'stale: exceeded timeout');
  assert.equal(stale.next_attempt_at, null);
  assert.equal(open.state, 'running');
  assertSchemaShape(stale, schema);
  const staleRow = assertCockpitRow(stale);
  assert.equal(staleRow.status, 'failed');
  assert.equal(staleRow.duration_ms, 1_001);
  assert.equal(staleRow.error, 'stale: exceeded timeout');
});

test('schema names the job, attempt, timeout, retry policy, terminal states, and UTC timestamps', async () => {
  const schema = JSON.parse(await readFile(SCHEMA_URL, 'utf8'));
  assert.equal(schema.$schema, 'https://json-schema.org/draft/2020-12/schema');
  assert.equal(schema.$id, 'urn:job-run:v1');
  for (const key of ['job_id', 'attempt', 'timeout_ms', 'retry', 'state', 'started_at', 'finished_at', 'next_attempt_at']) {
    assert.ok(schema.required.includes(key), key);
    assert.ok(schema.properties[key], key);
  }
  assert.deepEqual(schema.properties.state.enum, ['running', 'ok', 'failed', 'dead-lettered']);
  assert.deepEqual(TERMINAL_STATES, ['ok', 'failed', 'dead-lettered']);
  assert.deepEqual(schema.$defs.retryPolicy.required, ['max_attempts', 'backoff']);
  assert.match(schema.$defs.timestamp.pattern, /\\d\{4\}/);
  assert.equal(schema.properties.schema.const, SCHEMA_ID);
});

test('exponential backoff grows and then stops at max_ms', () => {
  const backoff = { strategy: 'exponential', initial_ms: 1_000, multiplier: 2, max_ms: 1_500 };
  assert.equal(backoffDelayMs(backoff, 1), 1_000);
  assert.equal(backoffDelayMs(backoff, 2), 1_500);
  assert.equal(backoffDelayMs(backoff, 3), 1_500);
});

test('capped exponential backoff stays at max_ms for a high attempt', () => {
  const backoff = { strategy: 'exponential', initial_ms: 1_000, multiplier: 2, max_ms: 60_000 };
  assert.equal(backoffDelayMs(backoff, 6), 32_000);
  assert.equal(backoffDelayMs(backoff, 7), 60_000);
  assert.equal(backoffDelayMs(backoff, 45), 60_000);
  assert.throws(
    () => backoffDelayMs({ strategy: 'exponential', initial_ms: 1_000, multiplier: 2 }, 45),
    RangeError,
  );
});

test('an ok attempt is terminal and does not schedule a retry', () => {
  const clock = manualClock('2026-08-12T00:00:00.000Z');
  const running = openRun(sampleConfig(), clock);
  clock.set('2026-08-12T00:00:00.250Z');
  const ok = recordSuccess(running, clock);
  assert.equal(ok.state, 'ok');
  assert.equal(ok.finished_at, '2026-08-12T00:00:00.250Z');
  assert.equal(ok.error, null);
  assert.equal(assertCockpitRow(ok).status, 'ok');
  assert.equal(assertCockpitRow(ok).duration_ms, 250);
  assert.throws(() => resolveFailure(ok, clock), /only a failed attempt/);
  assert.throws(() => toCockpitRunRecord(running, { proof_path: PROOF }), /terminal attempt/);
});

test('refuses to retry a model call unless the config has an explicit cost cap', () => {
  const clock = manualClock('2026-08-12T00:00:00.000Z');
  const config = sampleConfig({ makes_model_call: true, retry: { max_attempts: 3, backoff: { strategy: 'fixed', delay_ms: 500 } } });
  const running = openRun(config, clock);
  clock.set('2026-08-12T00:00:00.100Z');
  const failed = recordFailure(running, clock, { error: 'model transport failed' });
  const before = structuredClone(failed);

  assert.throws(() => resolveFailure(failed, clock), RetryRefused);
  assert.deepEqual(failed, before);
  assert.equal(failed.next_attempt_at, null);
  try {
    resolveFailure(failed, clock);
    assert.fail('expected RetryRefused');
  } catch (error) {
    assert.equal(error.code, 'cost-cap-required');
    assert.equal(error.name, 'RetryRefused');
  }

  const capped = openRun({ ...config, cost_cap: 0 }, clock);
  clock.set('2026-08-12T00:00:00.200Z');
  const cappedFailure = recordFailure(capped, clock, { error: 'model transport failed' });
  const decision = resolveFailure(cappedFailure, clock);
  assert.equal(decision.action, 'retry');
  assert.equal(decision.next_attempt_at, '2026-08-12T00:00:00.700Z');
  assert.equal(decision.run.cost_cap, 0);

  const once = openRun({
    ...config,
    retry: { max_attempts: 1, backoff: { strategy: 'fixed', delay_ms: 500 } },
  }, clock);
  clock.set('2026-08-12T00:00:01.000Z');
  const onceFailure = recordFailure(once, clock, { error: 'model transport failed' });
  const dead = resolveFailure(onceFailure, clock);
  assert.equal(dead.action, 'dead-letter');
  assert.equal(dead.run.cost_cap, null);
});

test('openRun refuses a later model-call attempt without an explicit cost cap', () => {
  const clock = manualClock('2026-08-12T00:00:00.000Z');
  const config = sampleConfig({
    makes_model_call: true,
    attempt: 2,
    retry: { max_attempts: 3, backoff: { strategy: 'fixed', delay_ms: 500 } },
  });
  assert.throws(() => openRun(config, clock), RetryRefused);
  assert.throws(() => openRun({ ...config, cost_cap: null }, clock), RetryRefused);
  try {
    openRun({ ...config, cost_cap: null }, clock);
    assert.fail('expected RetryRefused');
  } catch (error) {
    assert.equal(error.name, 'RetryRefused');
    assert.equal(error.code, 'cost-cap-required');
  }

  const opened = openRun({ ...config, cost_cap: 0 }, clock);
  assert.equal(opened.attempt, 2);
  assert.equal(opened.state, 'running');
  assert.equal(opened.cost_cap, 0);

  const first = openRun(sampleConfig({ makes_model_call: true }), clock);
  assert.equal(first.attempt, 1);
  assert.equal(first.cost_cap, null);
});

test('assertJobRun refuses a persisted model-call retry without an explicit cost cap', () => {
  const clock = manualClock('2026-08-12T00:00:00.000Z');
  const running = openRun(sampleConfig({
    makes_model_call: true,
    retry: { max_attempts: 3, backoff: { strategy: 'fixed', delay_ms: 500 } },
  }), clock);
  const persisted = { ...running, attempt: 2 };
  assert.throws(() => assertJobRun(persisted), RetryRefused);
  try {
    assertJobRun(persisted);
    assert.fail('expected RetryRefused');
  } catch (error) {
    assert.equal(error.name, 'RetryRefused');
    assert.equal(error.code, 'cost-cap-required');
  }

  const failed = {
    ...persisted,
    state: 'failed',
    finished_at: '2026-08-12T00:00:00.010Z',
    error: 'model transport failed',
  };
  assert.throws(() => assertJobRun(failed), RetryRefused);
  assertJobRun({ ...persisted, cost_cap: 0 });
  assertJobRun(running);

  const plainRetry = openRun(sampleConfig({
    attempt: 2,
    retry: { max_attempts: 3, backoff: { strategy: 'fixed', delay_ms: 500 } },
  }), clock);
  assertJobRun(plainRetry);
  assert.equal(plainRetry.makes_model_call, false);
  assert.equal(plainRetry.cost_cap, null);
});

test('assertJobRun accepts backoff properties in any key order', () => {
  const clock = manualClock('2026-08-12T00:00:00.000Z');
  const run = openRun(sampleConfig(), clock);
  const fixed = {
    ...run,
    retry: {
      backoff: { delay_ms: 1_000, strategy: 'fixed' },
      max_attempts: run.retry.max_attempts,
    },
  };
  assertJobRun(fixed);
  assert.equal(fixed.retry.backoff.delay_ms, 1_000);

  const exponential = {
    ...run,
    retry: {
      max_attempts: 2,
      backoff: { multiplier: 2, max_ms: 1_500, initial_ms: 1_000, strategy: 'exponential' },
    },
  };
  assertJobRun(exponential);

  const extra = {
    ...run,
    retry: {
      max_attempts: 2,
      backoff: { strategy: 'fixed', delay_ms: 1_000, extra: true },
    },
  };
  assert.throws(() => assertJobRun(extra), /extra fields/);
});

test('timestamps from the clock are canonical UTC and impossible dates are rejected', () => {
  assert.equal(formatTimestamp('2026-08-12T00:00:00Z'), '2026-08-12T00:00:00.000Z');
  assert.equal(formatTimestamp(new Date('2026-08-12T00:00:00.000Z')), '2026-08-12T00:00:00.000Z');
  assert.throws(() => formatTimestamp('2026-02-31T00:00:00.000Z'), /real UTC instant/);
  assert.throws(() => formatTimestamp('2026-08-12T00:00:00.000+00:00'), /ISO-8601 UTC/);
  const clock = manualClock('2026-99-99T00:00:00.000Z');
  assert.throws(() => openRun(sampleConfig(), clock), /real UTC instant/);
});

test('the library takes time only from the injected clock and does no I/O of its own', async () => {
  const source = await readFile(LIBRARY_URL, 'utf8');
  assert.equal(source.includes('Date.now'), false);
  assert.equal(source.includes('Math.random'), false);
  assert.equal(source.includes('node:fs'), false);
  assert.equal(source.includes('node:http'), false);
  assert.equal(source.includes('node:net'), false);
  assert.equal(source.includes('require('), false);
  assert.equal(source.includes('process.'), false);
  assert.equal(source.includes("from '"), false);

  const clock = manualClock('2026-08-12T00:00:00.000Z');
  const running = openRun(sampleConfig(), clock);
  assert.deepEqual(clock.calls, ['2026-08-12T00:00:00.000Z']);
  assert.throws(() => openRun(sampleConfig(), '2026-08-12T00:00:00.000Z'), /clock function is required/);
  assert.equal(running.started_at, '2026-08-12T00:00:00.000Z');
});

test('rejects absolute host paths and home shortcuts in error text and suggested action', () => {
  const patterns = [
    '/Users/fakeuser/notes',
    '/users/fakeuser/notes',
    '\\Users\\fakeuser\\notes',
    '/Users\\fakeuser\\notes',
    '/home/fakeuser/project',
    '/HOME/fakeuser/project',
    '\\home\\fakeuser\\project',
    '/root',
    '/root/private',
    '/ROOT/private',
    '\\root\\private',
    '~/fakeuser/notes',
    '~\\fakeuser\\notes',
    'C:\\Users\\fakeuser\\file',
    'c:/users/fakeuser/file',
    'D:\\data\\file',
    'E:/drop/file',
    '\\\\fileshare\\drop\\file',
    '//fileshare/drop/file',
    '\\\\fileshare/drop/file',
    '//fileshare\\drop\\file',
    '/Volumes/fakeuser/file',
    '\\Volumes\\fakeuser\\file',
    '/VOLUMES/fakeuser/file',
    '/mnt/fakeuser/file',
    '\\mnt\\fakeuser\\file',
    '/media/fakeuser/file',
    '\\media\\fakeuser\\file',
    '/private/var/folders/ab',
    '/PRIVATE/VAR/folders/ab',
    '\\private\\var\\log',
    '/var/folders/ab',
    '/VAR/FOLDERS/ab',
    '\\var\\folders\\ab',
  ];

  const clock = manualClock('2026-08-12T00:00:00.000Z');
  const running = openRun(sampleConfig(), clock);
  clock.set('2026-08-12T00:00:00.010Z');
  for (const pattern of patterns) {
    assert.throws(
      () => recordFailure(running, clock, { error: `failed at ${pattern}` }),
      /private path/,
      pattern,
    );
  }
  assert.equal(running.state, 'running');

  const failed = recordFailure(running, clock, { error: 'failed reading proofs/sample-job.txt' });
  assert.equal(failed.error, 'failed reading proofs/sample-job.txt');
  for (const pattern of patterns) {
    assert.throws(
      () => toCockpitRunRecord(failed, {
        proof_path: PROOF,
        suggested_action: `inspect ${pattern}`,
      }),
      /private path/,
      pattern,
    );
  }
  const row = toCockpitRunRecord(failed, {
    proof_path: PROOF,
    suggested_action: 'inspect proofs/sample-job.txt',
  });
  assert.equal(row.suggested_action, 'inspect proofs/sample-job.txt');
  assert.equal(row.error, 'failed reading proofs/sample-job.txt');
});

test('rejects an absolute path after punctuation', () => {
  const clock = manualClock('2026-08-12T00:00:00.000Z');
  const running = openRun(sampleConfig(), clock);
  clock.set('2026-08-12T00:00:00.010Z');
  const hostPath = '/home/fakeuser/private';
  for (const mark of ['=', '[', '(', '"', "'", ':', ',']) {
    assert.throws(
      () => recordFailure(running, clock, { error: `paths${mark}${hostPath}` }),
      /private path/,
      mark,
    );
  }
  assert.throws(
    () => recordFailure(running, clock, { error: 'paths=[\\Users\\fakeuser\\notes]' }),
    /private path/,
  );
  assert.throws(
    () => recordFailure(running, clock, { error: 'path=C:\\Users\\fakeuser\\file' }),
    /private path/,
  );
  assert.equal(running.state, 'running');

  const failed = recordFailure(running, clock, { error: 'see https://example.com/docs' });
  assert.equal(failed.error, 'see https://example.com/docs');
  const row = toCockpitRunRecord(failed, {
    proof_path: PROOF,
    suggested_action: 'read https://example.com/docs',
  });
  assert.equal(row.suggested_action, 'read https://example.com/docs');
});

test('cockpit projection keeps a relative proof and an optional suggested action', () => {
  const clock = manualClock('2026-08-12T00:00:00.000Z');
  const running = openRun(sampleConfig(), clock);
  clock.set('2026-08-12T00:00:00.010Z');
  const failed = recordFailure(running, clock, { error: 'upstream unavailable' });
  const row = toCockpitRunRecord(failed, {
    proof_path: 'proofs/sample-job.txt',
    suggested_action: 'inspect the failed attempt',
  });
  const normalized = normalizeRecord(row);
  assert.equal(normalized.suggested_action, 'inspect the failed attempt');
  assert.equal(normalized.error, 'upstream unavailable');
  assert.throws(() => toCockpitRunRecord(failed, { proof_path: '/tmp/proof.txt' }), /relative path/);
  assert.throws(() => toCockpitRunRecord(failed, { proof_path: 'proofs/../../secret' }), /relative path/);
});
