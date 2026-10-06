#!/usr/bin/env node
/**
 * Read-only fixture generator for antahkarana dashboard tests.
 *
 * Reads <tenant-root>/.planning/run-records.jsonl and, when present, PARA
 * directories (01-Projects .. 04-Archives). Writes labelled fixture envelopes.
 * Never writes inside the tenant root, a twc-vault path, or /Volumes/.
 * Makes no network calls. Timestamps come from the ledger or --clock.
 */

import {
  closeSync,
  constants,
  existsSync,
  lstatSync,
  mkdirSync,
  openSync,
  readFileSync,
  realpathSync,
  readdirSync,
  statSync,
  unlinkSync,
  writeSync,
} from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_TENANT_ROOT = path.resolve(SCRIPT_DIR, '..');
export const DEFAULT_CLOCK = '2026-08-12T00:00:00Z';

export const LEDGER_REL = '.planning/run-records.jsonl';
export const RECORD_SOURCE = 'paperclip-tn';
export const RECORD_MODE = 'fixture';
export const RECORD_SCHEMA = 'paperclip-run-record.v1';
export const VAULT_READ_MODEL = 'VaultParaStatsOk';
export const INDEX_DESCRIPTION = 'Labelled dashboard command fixtures. Not live vault, Selemene, sidecar, or cron data.';

const PARA_BUCKETS = ['01-Projects', '02-Areas', '03-Resources', '04-Archives'];
const PARA_SKIP_DIRS = new Set(['node_modules', '.git']);

const VALUE_MARKERS = [
  'nk_',
  'sk-',
  'ghp_',
  'github_pat_',
  'xox',
  'AKIA',
  'BEGIN PRIVATE',
  'Bearer ',
  'api_key',
  'password',
  '/Volumes/',
  '/Users/',
];

const FORBIDDEN_KEYS = new Set(['token', 'password', 'secret', 'api_key', 'authorization']);

const CLOCK_RE = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?Z$/;
const STALE_OUTPUTS = [
  'paperclip_run_records.json',
  'paperclip_run_records.ledger.jsonl',
  'vault_para_stats.json',
];
const WRITE_FLAGS = constants.O_WRONLY | constants.O_CREAT | constants.O_TRUNC | (constants.O_NOFOLLOW ?? 0);

class Refuse extends Error {
  constructor(message, exitCode = 1) {
    super(message);
    this.exitCode = exitCode;
  }
}

function usage() {
  return `Usage: node scripts/generate-antahkarana-fixtures.mjs [--tenant-root <dir>] [--out <dir>] [--clock <iso>]

Reads a paperclip-tn tenant read-only and emits antahkarana dashboard fixtures.
--out defaults to stdout. --clock defaults to ${DEFAULT_CLOCK}.
`;
}

export function parseArgs(argv, defaults = {}) {
  const opts = {
    tenantRoot: defaults.tenantRoot ?? DEFAULT_TENANT_ROOT,
    out: null,
    clock: DEFAULT_CLOCK,
    help: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') {
      opts.help = true;
      continue;
    }
    if (arg === '--tenant-root' || arg === '--out' || arg === '--clock') {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--')) {
        throw new Refuse(`missing value for ${arg}`, 2);
      }
      i += 1;
      if (arg === '--tenant-root') opts.tenantRoot = path.resolve(value);
      else if (arg === '--out') opts.out = value;
      else opts.clock = value;
      continue;
    }
    throw new Refuse(`unknown argument: ${arg}`, 2);
  }

  assertRealClock(opts.clock);
  return opts;
}

/**
 * Accept only a real UTC timestamp. Shape is not enough: 2026-02-31 and
 * 2026-99-99 parse as rollovers or Invalid Date, so the parsed instant must
 * round-trip to the same calendar fields.
 */
export function assertRealClock(value) {
  const match = CLOCK_RE.exec(value);
  if (!match) {
    throw new Refuse('invalid --clock (expected an ISO-8601 UTC timestamp)', 2);
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const hour = Number(match[4]);
  const minute = Number(match[5]);
  const second = Number(match[6]);
  const fraction = match[7] ?? '';
  if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59) {
    throw new Refuse('invalid --clock (not a real UTC timestamp)', 2);
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new Refuse('invalid --clock (not a real UTC timestamp)', 2);
  }
  const millis = fraction.length === 0 ? '000' : `${fraction}000`.slice(0, 3);
  const roundTrip = `${match[1]}-${match[2]}-${match[3]}T${match[4]}:${match[5]}:${match[6]}.${millis}Z`;
  if (
    parsed.toISOString() !== roundTrip
    || parsed.getUTCFullYear() !== year
    || parsed.getUTCMonth() + 1 !== month
    || parsed.getUTCDate() !== day
    || parsed.getUTCHours() !== hour
    || parsed.getUTCMinutes() !== minute
    || parsed.getUTCSeconds() !== second
  ) {
    throw new Refuse('invalid --clock (not a real UTC timestamp)', 2);
  }
}

function isInside(child, parent) {
  const rel = path.relative(parent, child);
  return rel === '' || (!rel.startsWith(`..${path.sep}`) && rel !== '..' && !path.isAbsolute(rel));
}

function hasSegment(absPath, segment) {
  return absPath.split(path.sep).some((part) => part.toLowerCase() === segment);
}

function assertAllowedZone(absPath, tenantRoot) {
  const tenant = path.resolve(tenantRoot);
  if (absPath === '/Volumes' || absPath.startsWith(`${path.sep}Volumes${path.sep}`)) {
    throw new Refuse('refusing to write under /Volumes/');
  }
  if (hasSegment(absPath, 'twc-vault')) {
    throw new Refuse('refusing to write inside twc-vault');
  }
  if (isInside(absPath, tenant)) {
    throw new Refuse('refusing to write inside tenant root');
  }
}

function nearestExisting(absPath) {
  let current = absPath;
  for (;;) {
    try {
      lstatSync(current);
      return current;
    } catch (error) {
      if (error.code !== 'ENOENT') throw new Refuse('refusing to stat output path');
      const parent = path.dirname(current);
      if (parent === current) throw new Refuse('refusing to resolve output path');
      current = parent;
    }
  }
}

function assertNoSymlinkComponents(absPath) {
  const parts = absPath.split(path.sep).filter(Boolean);
  let current = path.parse(absPath).root;
  for (const part of parts) {
    current = path.join(current, part);
    let st;
    try {
      st = lstatSync(current);
    } catch (error) {
      if (error.code === 'ENOENT') return;
      throw new Refuse('refusing to stat output path');
    }
    if (st.isSymbolicLink()) {
      throw new Refuse('refusing to write through a symlink');
    }
  }
}

export function assertWritableOut(outDir, tenantRoot) {
  const abs = path.resolve(outDir);
  assertAllowedZone(abs, tenantRoot);
  assertNoSymlinkComponents(abs);
  const existing = nearestExisting(abs);
  let real;
  try {
    real = realpathSync(existing);
  } catch {
    throw new Refuse('refusing to resolve output path');
  }
  assertAllowedZone(real, tenantRoot);
  return abs;
}

function assertReadableLedger(realPath, tenantRoot) {
  if (realPath === '/Volumes' || realPath.startsWith(`${path.sep}Volumes${path.sep}`)) {
    throw new Refuse('refusing to read a ledger under /Volumes/');
  }
  if (hasSegment(realPath, 'twc-vault')) {
    throw new Refuse('refusing to read a ledger inside twc-vault');
  }
  if (!isInside(realPath, path.resolve(tenantRoot))) {
    throw new Refuse('refusing to read a ledger outside the tenant root');
  }
}

function isRelativeProof(proofPath) {
  if (typeof proofPath !== 'string' || proofPath.length === 0 || proofPath.trim().length === 0) {
    return false;
  }
  if (proofPath.startsWith('/') || proofPath.startsWith('\\') || proofPath.startsWith('~')) return false;
  if (/^[A-Za-z]:[\\/]/.test(proofPath)) return false;
  const normalized = path.posix.normalize(proofPath.replaceAll('\\', '/'));
  if (normalized === '..' || normalized.startsWith('../') || normalized.startsWith('/')) return false;
  return true;
}

function nonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function optionalText(value) {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

/**
 * Keep an allowlisted record. Malformed lines are counted, not repaired.
 * source, mode, and schema are always the fixture constants.
 * error and suggested_action are kept only when they are non-empty strings.
 */
export function normalizeRecord(value) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return null;
  if (!nonEmptyString(value.ts)) return null;
  if (!nonEmptyString(value.task)) return null;
  if (!nonEmptyString(value.status)) return null;
  if (typeof value.duration_ms !== 'number' || !Number.isFinite(value.duration_ms)) return null;
  if (!isRelativeProof(value.proof_path)) return null;

  const record = {
    ts: value.ts,
    task: value.task,
    status: value.status,
    duration_ms: value.duration_ms,
    proof_path: value.proof_path,
    source: RECORD_SOURCE,
    mode: RECORD_MODE,
    schema: RECORD_SCHEMA,
  };
  const error = optionalText(value.error);
  const suggestedAction = optionalText(value.suggested_action);
  if (error !== null) record.error = error;
  if (suggestedAction !== null) record.suggested_action = suggestedAction;
  return record;
}

export function parseLedger(text) {
  const records = [];
  let skipped = 0;
  const body = text.replace(/^\uFEFF/, '');
  const lines = body.split('\n');
  if (lines.length > 0 && lines[lines.length - 1] === '') lines.pop();

  for (const rawLine of lines) {
    const line = rawLine.endsWith('\r') ? rawLine.slice(0, -1) : rawLine;
    if (line.trim() === '') continue;
    let parsed;
    try {
      parsed = JSON.parse(line);
    } catch {
      skipped += 1;
      continue;
    }
    const record = normalizeRecord(parsed);
    if (!record) {
      skipped += 1;
      continue;
    }
    records.push(record);
  }

  return { records, skipped };
}

export function readLedger(tenantRoot) {
  const abs = path.join(path.resolve(tenantRoot), '.planning', 'run-records.jsonl');
  if (!existsSync(abs)) {
    return { missing: true, records: [], skipped: 0 };
  }
  const stat = statSync(abs);
  if (!stat.isFile()) {
    throw new Refuse('ledger path is not a file');
  }
  const real = realpathSync(abs);
  assertReadableLedger(real, tenantRoot);
  const text = readFileSync(real, 'utf8');
  const parsed = parseLedger(text);
  return { missing: false, ...parsed };
}

function envelope(command, readModel, variant, payload) {
  return {
    fixture: true,
    label: 'FIXTURE',
    not_live: true,
    command,
    read_model: readModel,
    variant,
    payload,
  };
}

function paperclipPayload(state, reason, records, skipped) {
  return {
    state,
    reason,
    records,
    source: RECORD_SOURCE,
    ledger: LEDGER_REL,
    skipped,
  };
}

export function emptyPaperclipEnvelope(skipped = 0) {
  return envelope(
    'paperclip_run_records',
    'PaperclipReadModel',
    'empty',
    paperclipPayload('empty', 'cron has not run yet', [], skipped),
  );
}

export function samplePaperclipEnvelope(records, skipped) {
  return envelope(
    'paperclip_run_records',
    'PaperclipReadModel',
    'sample',
    paperclipPayload('ok', null, records, skipped),
  );
}

function findParaDirs(tenantRoot) {
  const found = new Map();
  const root = path.resolve(tenantRoot);

  function walk(dir) {
    let entries;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      if (entry.isSymbolicLink() || !entry.isDirectory()) continue;
      if (PARA_SKIP_DIRS.has(entry.name)) continue;
      const full = path.join(dir, entry.name);
      if (PARA_BUCKETS.includes(entry.name)) {
        if (!found.has(entry.name)) found.set(entry.name, full);
        continue;
      }
      walk(full);
    }
  }

  walk(root);
  return found;
}

function countTree(dir) {
  let fileCount = 0;
  let dirCount = 0;

  function walk(current) {
    let entries;
    try {
      entries = readdirSync(current, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      if (entry.isSymbolicLink()) {
        fileCount += 1;
        continue;
      }
      if (entry.isDirectory()) {
        dirCount += 1;
        walk(path.join(current, entry.name));
        continue;
      }
      fileCount += 1;
    }
  }

  walk(dir);
  return { file_count: fileCount, dir_count: dirCount };
}

export function paraBuckets(tenantRoot) {
  const found = findParaDirs(tenantRoot);
  const present = PARA_BUCKETS.some((name) => found.has(name));
  const buckets = PARA_BUCKETS.map((name) => {
    if (!found.has(name)) return { name, file_count: 0, dir_count: 0 };
    const counts = countTree(found.get(name));
    return { name, file_count: counts.file_count, dir_count: counts.dir_count };
  });
  return { present, buckets };
}

function paraPayload(buckets, scannedAt) {
  return {
    buckets,
    scanned_at: scannedAt,
  };
}

export function emptyParaEnvelope(scannedAt) {
  const buckets = PARA_BUCKETS.map((name) => ({ name, file_count: 0, dir_count: 0 }));
  return envelope('vault_para_stats', VAULT_READ_MODEL, 'empty', paraPayload(buckets, scannedAt));
}

export function sampleParaEnvelope(buckets, scannedAt) {
  return envelope('vault_para_stats', VAULT_READ_MODEL, 'sample', paraPayload(buckets, scannedAt));
}

function containsSecret(value) {
  if (Array.isArray(value)) return value.some((item) => containsSecret(item));
  if (value && typeof value === 'object') {
    for (const [key, child] of Object.entries(value)) {
      if (FORBIDDEN_KEYS.has(String(key).toLowerCase())) return true;
      if (containsSecret(child)) return true;
    }
    return false;
  }
  if (typeof value === 'string') {
    return VALUE_MARKERS.some((marker) => value.includes(marker));
  }
  return false;
}

export function assertNoSecrets(value) {
  if (containsSecret(value)) {
    throw new Refuse('secrets guard refused output');
  }
}

function commandEntry(command, readModel, sample, empty, extra) {
  return {
    command,
    read_model: readModel,
    sample,
    empty,
    ...extra,
  };
}

/**
 * Build the fixture set for a tenant.
 * Empty variants are always written. Sample files are omitted, and index
 * sample is null, when the ledger has no valid rows or no PARA directory exists.
 * The empty paperclip variant carries the malformed-line count only when it is
 * the sole paperclip variant; alongside a sample it stays the canonical empty
 * document (skipped: 0).
 */
export function buildFixtures({ tenantRoot, clock = DEFAULT_CLOCK }) {
  const ledger = readLedger(tenantRoot);
  const files = {};
  const ledgers = {};

  const hasSample = ledger.records.length > 0;
  const emptySkipped = hasSample ? 0 : ledger.skipped;
  files['paperclip_run_records.empty.json'] = emptyPaperclipEnvelope(emptySkipped);
  if (hasSample) {
    files['paperclip_run_records.json'] = samplePaperclipEnvelope(ledger.records, ledger.skipped);
    ledgers['paperclip_run_records.ledger.jsonl'] = `${ledger.records.map((record) => JSON.stringify(record)).join('\n')}\n`;
  }

  const para = paraBuckets(tenantRoot);
  files['vault_para_stats.empty.json'] = emptyParaEnvelope(clock);
  if (para.present) {
    files['vault_para_stats.json'] = sampleParaEnvelope(para.buckets, clock);
  }

  const paperclipExtra = hasSample ? { ledger: 'paperclip_run_records.ledger.jsonl' } : {};
  const index = {
    fixture: true,
    label: 'FIXTURE',
    not_live: true,
    description: INDEX_DESCRIPTION,
    commands: [
      commandEntry(
        'vault_para_stats',
        VAULT_READ_MODEL,
        para.present ? 'vault_para_stats.json' : null,
        'vault_para_stats.empty.json',
      ),
      commandEntry(
        'paperclip_run_records',
        'PaperclipReadModel',
        hasSample ? 'paperclip_run_records.json' : null,
        'paperclip_run_records.empty.json',
        paperclipExtra,
      ),
    ],
  };
  assertNoSecrets({ index, files, ledgers, clock });
  return { index, files, ledgers };
}

function assertRegularOrAbsent(target) {
  let st;
  try {
    st = lstatSync(target);
  } catch (error) {
    if (error.code === 'ENOENT') return;
    throw new Refuse('refusing to stat output file');
  }
  if (st.isSymbolicLink() || !st.isFile()) {
    throw new Refuse('refusing to write through a non-regular output file');
  }
}

function writeFileNoFollow(target, contents) {
  if (!constants.O_NOFOLLOW || (WRITE_FLAGS & constants.O_NOFOLLOW) === 0) {
    throw new Refuse('refusing to write without O_NOFOLLOW');
  }
  assertRegularOrAbsent(target);
  let fd;
  try {
    fd = openSync(target, WRITE_FLAGS, 0o644);
  } catch (error) {
    if (error.code === 'ELOOP' || error.code === 'EEXIST') {
      throw new Refuse('refusing to write through a symlink');
    }
    throw error;
  }
  try {
    const buf = Buffer.from(contents);
    let offset = 0;
    while (offset < buf.length) {
      const written = writeSync(fd, buf, offset, buf.length - offset);
      if (written <= 0) throw new Refuse('failed to write output file');
      offset += written;
    }
  } finally {
    closeSync(fd);
  }
}

function removeStaleOutputs(outDir, produced) {
  for (const name of STALE_OUTPUTS) {
    if (produced.has(name)) continue;
    const target = path.join(outDir, name);
    let st;
    try {
      st = lstatSync(target);
    } catch (error) {
      if (error.code === 'ENOENT') continue;
      throw new Refuse('refusing to stat output file');
    }
    if (st.isSymbolicLink() || !st.isFile()) continue;
    unlinkSync(target);
  }
}

function writeOut(outDir, bundle) {
  const planned = new Map();
  for (const [name, value] of Object.entries(bundle.files)) {
    planned.set(name, `${JSON.stringify(value, null, 2)}\n`);
  }
  for (const [name, text] of Object.entries(bundle.ledgers)) {
    planned.set(name, text);
  }
  planned.set('index.json', `${JSON.stringify(bundle.index, null, 2)}\n`);

  for (const name of planned.keys()) {
    assertRegularOrAbsent(path.join(outDir, name));
  }

  mkdirSync(outDir, { recursive: true });
  removeStaleOutputs(outDir, new Set(planned.keys()));
  for (const [name, contents] of planned) {
    writeFileNoFollow(path.join(outDir, name), contents);
  }
  return [...planned.keys()];
}

export function run(argv, io = {}) {
  const stdout = io.stdout ?? ((chunk) => process.stdout.write(chunk));
  const stderr = io.stderr ?? ((chunk) => process.stderr.write(chunk));
  let opts;
  try {
    opts = parseArgs(argv);
  } catch (error) {
    stderr(`${error.message}\n`);
    if (error.exitCode === 2) stderr(usage());
    return error.exitCode ?? 1;
  }

  if (opts.help) {
    stdout(usage());
    return 0;
  }

  try {
    const bundle = buildFixtures({ tenantRoot: opts.tenantRoot, clock: opts.clock });
    if (opts.out === null) {
      stdout(`${JSON.stringify({ index: bundle.index, files: bundle.files, ledgers: bundle.ledgers }, null, 2)}\n`);
      return 0;
    }
    const outDir = assertWritableOut(opts.out, opts.tenantRoot);
    if (existsSync(outDir)) {
      const st = lstatSync(outDir);
      if (st.isSymbolicLink()) throw new Refuse('refusing to write through a symlink');
      if (!st.isDirectory()) throw new Refuse('out path is not a directory');
    }
    writeOut(outDir, bundle);
    return 0;
  } catch (error) {
    stderr(`${error.message}\n`);
    return error.exitCode ?? 1;
  }
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : '';
if (import.meta.url === invokedPath) {
  process.exit(run(process.argv.slice(2)));
}
