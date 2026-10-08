/**
 * Host-agnostic job-run policy. No dependencies and no I/O.
 * Time comes only from the clock function the caller passes in.
 * The clock returns a Date or an ISO-8601 UTC string.
 */

export const SCHEMA_ID = 'job-run.v1';
export const TERMINAL_STATES = Object.freeze(['ok', 'failed', 'dead-lettered']);
const TERMINAL = new Set(TERMINAL_STATES);
const JOB_ID_MAX = 200;
// Same rule as job_id.pattern in job-run.schema.json: no slash, no `..`,
// no ASCII control characters, no U+2028 or U+2029, and no leading or trailing whitespace.
// [\s\S] lets the lookaheads see a forbidden token after every character, including
// a Unicode line terminator. `.` would stop at U+2028 and U+2029.
const JOB_ID_RE = /^(?![\s\S]*\.\.)(?![\s\S]*[/\\])(?!\s)(?![\s\S]*\s$)[^\u0000-\u001F\u007F\u2028\u2029]+$/;
const TIMESTAMP_RE = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?Z$/;
const STORED_TIMESTAMP_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

export class RetryRefused extends Error {
  constructor(message) {
    super(message);
    this.name = 'RetryRefused';
    this.code = 'cost-cap-required';
  }
}

/**
 * Canonical ISO-8601 UTC timestamp with millisecond precision.
 * Impossible calendar dates are rejected. Offsets other than Z are rejected.
 */
export function formatTimestamp(value) {
  let candidate;
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) {
      throw new TypeError('timestamp is not a real UTC instant');
    }
    candidate = value.toISOString();
  } else if (typeof value === 'string') {
    candidate = value;
  } else {
    throw new TypeError('timestamp must be a Date or an ISO-8601 UTC string');
  }

  const match = TIMESTAMP_RE.exec(candidate);
  if (!match) throw new TypeError('timestamp must be an ISO-8601 UTC value');

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const hour = Number(match[4]);
  const minute = Number(match[5]);
  const second = Number(match[6]);
  if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59) {
    throw new TypeError('timestamp is not a real UTC instant');
  }

  const parsed = new Date(candidate);
  if (Number.isNaN(parsed.getTime())) throw new TypeError('timestamp is not a real UTC instant');
  if (
    parsed.getUTCFullYear() !== year
    || parsed.getUTCMonth() + 1 !== month
    || parsed.getUTCDate() !== day
    || parsed.getUTCHours() !== hour
    || parsed.getUTCMinutes() !== minute
    || parsed.getUTCSeconds() !== second
  ) {
    throw new TypeError('timestamp is not a real UTC instant');
  }
  return parsed.toISOString();
}

function readClock(clock) {
  if (typeof clock !== 'function') throw new TypeError('clock function is required');
  return formatTimestamp(clock());
}

function assertStoredTimestamp(value, label) {
  if (typeof value !== 'string' || !STORED_TIMESTAMP_RE.test(value)) {
    throw new TypeError(`${label} must be a canonical ISO-8601 UTC timestamp`);
  }
  const canonical = formatTimestamp(value);
  if (canonical !== value) {
    throw new TypeError(`${label} must be a canonical ISO-8601 UTC timestamp`);
  }
}

function assertJobId(value) {
  if (typeof value !== 'string' || value.length < 1 || value.length > JOB_ID_MAX) {
    throw new TypeError('job_id must be a non-empty string');
  }
  if (!JOB_ID_RE.test(value)) {
    throw new TypeError('job_id must not be a path');
  }
}

/**
 * Reject home shortcuts and absolute host paths in text the public repo may store.
 * Repo-relative text is allowed. Matching is case-insensitive and accepts both slash styles.
 * A home shortcut is `~/`, `~\`, `~user/`, or `~user\` at a token boundary.
 * A bare `~`, as in `retry took ~5 seconds`, is prose.
 * Covers that shortcut, /Users, /home, /root, /Volumes, /mnt, /media, /private/var, /var/folders,
 * a drive-letter path such as C:\..., and a UNC share.
 * An https:// or http:// URL is not a drive letter.
 */
function assertPublicText(value, label) {
  if (containsHostPath(value)) {
    throw new TypeError(`${label} must not carry a private path`);
  }
}

function containsHostPath(value) {
  // A path character continues a repo-relative segment. Any other prefix, including
  // punctuation, starts an absolute host path. A scheme such as https:// is not a drive:
  // the letter before :// stays inside the scheme token.
  // A home shortcut is ~/, ~\, ~user/, or ~user\ at a token boundary.
  const patterns = [
    /(?:^|[^a-z0-9._-])~(?:[a-z][a-z0-9._-]*)?[/\\]/i,
    /(^|[^a-z0-9])[a-z]:[/\\]/i,
    /(^|[^a-z0-9._-])\\\\[^\\/\s]+[\\/]/i,
    /(?:^|[^a-z0-9._:-])\/\/[^/\s]+[\\/]/i,
    /:\/\/\/[a-z0-9._-]/i,
    /(?:^|(?<=[^a-z0-9._/\\-]))[/\\][a-z0-9._-]/i,
  ];
  return patterns.some((pattern) => pattern.test(value));
}

function isExplicitCostCap(value) {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0;
}

function assertCostCap(value) {
  if (value === null) return;
  if (!isExplicitCostCap(value)) {
    throw new TypeError('cost_cap must be null or a finite number greater than or equal to zero');
  }
}

function copyBackoff(backoff) {
  if (backoff === null || typeof backoff !== 'object' || Array.isArray(backoff)) {
    throw new TypeError('backoff is required');
  }
  if (backoff.strategy === 'fixed') {
    if (!Number.isSafeInteger(backoff.delay_ms) || backoff.delay_ms < 0) {
      throw new TypeError('fixed backoff delay_ms must be an integer greater than or equal to zero');
    }
    return { strategy: 'fixed', delay_ms: backoff.delay_ms };
  }
  if (backoff.strategy === 'exponential') {
    if (!Number.isSafeInteger(backoff.initial_ms) || backoff.initial_ms < 0) {
      throw new TypeError('exponential backoff initial_ms must be an integer greater than or equal to zero');
    }
    if (typeof backoff.multiplier !== 'number' || !Number.isFinite(backoff.multiplier) || backoff.multiplier <= 0) {
      throw new TypeError('exponential backoff multiplier must be a finite number greater than zero');
    }
    const copy = {
      strategy: 'exponential',
      initial_ms: backoff.initial_ms,
      multiplier: backoff.multiplier,
    };
    if (backoff.max_ms !== undefined) {
      if (!Number.isSafeInteger(backoff.max_ms) || backoff.max_ms < 0) {
        throw new TypeError('exponential backoff max_ms must be an integer greater than or equal to zero');
      }
      copy.max_ms = backoff.max_ms;
    }
    return copy;
  }
  throw new TypeError('backoff.strategy must be fixed or exponential');
}

function copyRetry(retry) {
  if (retry === null || typeof retry !== 'object' || Array.isArray(retry)) {
    throw new TypeError('retry policy is required');
  }
  if (!Number.isSafeInteger(retry.max_attempts) || retry.max_attempts < 1) {
    throw new TypeError('retry.max_attempts must be an integer greater than or equal to one');
  }
  return {
    max_attempts: retry.max_attempts,
    backoff: copyBackoff(retry.backoff),
  };
}

function instantMs(iso) {
  return Date.parse(iso);
}

/**
 * Delay in milliseconds before the attempt that follows `attempt`.
 * Fixed backoff returns delay_ms. Exponential backoff returns
 * floor(initial_ms * multiplier^(attempt-1)). When max_ms is set, the
 * delay does not exceed that ceiling. A multiplier below 1 decays under
 * the ceiling when initial_ms is already at least max_ms, instead of
 * sticking at the cap for every later attempt.
 */
export function backoffDelayMs(backoff, attempt) {
  const policy = copyBackoff(backoff);
  if (!Number.isSafeInteger(attempt) || attempt < 1) {
    throw new TypeError('attempt must be a positive integer');
  }
  if (policy.strategy === 'fixed') return policy.delay_ms;
  return exponentialDelayMs(policy, attempt);
}

function exponentialDelayMs(policy, attempt) {
  const exponent = attempt - 1;
  const cap = policy.max_ms;
  if (policy.initial_ms === 0 || cap === 0) return 0;
  if (exponent === 0) return cap === undefined ? policy.initial_ms : Math.min(policy.initial_ms, cap);
  // A multiplier below 1 can fall back under the cap. Only a non-decaying
  // policy that already starts at the ceiling stays there.
  if (cap !== undefined && policy.multiplier >= 1 && policy.initial_ms >= cap) return cap;

  if (policy.multiplier > 1 && cap !== undefined) {
    const stepsToCap = Math.log(cap / policy.initial_ms) / Math.log(policy.multiplier);
    if (Number.isFinite(stepsToCap) && exponent > stepsToCap + 1) return cap;
  }

  if (policy.multiplier > 1 && cap === undefined) {
    const stepsToOverflow = Math.log(Number.MAX_SAFE_INTEGER / policy.initial_ms) / Math.log(policy.multiplier);
    if (Number.isFinite(stepsToOverflow) && exponent > stepsToOverflow + 1) {
      throw new RangeError('backoff delay overflow');
    }
  }

  if (policy.multiplier < 1) {
    const raw = policy.initial_ms * (policy.multiplier ** exponent);
    if (!Number.isFinite(raw)) return 0;
    const delay = Math.floor(raw);
    if (cap !== undefined) return Math.min(delay, cap);
    return delay;
  }

  const raw = policy.initial_ms * (policy.multiplier ** exponent);
  if (cap !== undefined && (!Number.isFinite(raw) || raw >= cap)) return cap;
  if (!Number.isFinite(raw) || raw > Number.MAX_SAFE_INTEGER) {
    throw new RangeError('backoff delay overflow');
  }
  const delay = Math.floor(raw);
  if (cap !== undefined) return Math.min(delay, cap);
  return delay;
}

function sameMembers(actual, normalized) {
  if (actual === null || typeof actual !== 'object' || Array.isArray(actual)) return false;
  const actualKeys = Object.keys(actual);
  const normalizedKeys = Object.keys(normalized);
  if (actualKeys.length !== normalizedKeys.length) return false;
  return normalizedKeys.every((key) => Object.hasOwn(actual, key) && actual[key] === normalized[key]);
}

function refuseUncappedModelRetry(attempt, makesModelCall, costCap, nextAttemptAt = null) {
  if (makesModelCall !== true) return;
  if (isExplicitCostCap(costCap)) return;
  const laterAttempt = Number.isSafeInteger(attempt) && attempt > 1;
  const schedulesRetry = nextAttemptAt !== null && nextAttemptAt !== undefined;
  if (!laterAttempt && !schedulesRetry) return;
  throw new RetryRefused('retry refused: a job that makes a model call needs an explicit cost cap');
}

function addMillis(iso, ms) {
  const sum = instantMs(iso) + ms;
  if (!Number.isSafeInteger(sum)) throw new RangeError('timestamp overflow');
  return new Date(sum).toISOString();
}

function seal(run) {
  const copy = {
    schema: SCHEMA_ID,
    job_id: run.job_id,
    attempt: run.attempt,
    timeout_ms: run.timeout_ms,
    retry: {
      max_attempts: run.retry.max_attempts,
      backoff: { ...run.retry.backoff },
    },
    state: run.state,
    started_at: run.started_at,
    finished_at: run.finished_at,
    next_attempt_at: run.next_attempt_at,
    makes_model_call: run.makes_model_call,
    cost_cap: run.cost_cap,
    error: run.error,
  };
  assertJobRun(copy);
  return copy;
}

/**
 * Reject a record that breaks the job-run.v1 schema invariants,
 * including impossible timestamps and an attempt past max_attempts.
 */
export function assertJobRun(run) {
  if (run === null || typeof run !== 'object' || Array.isArray(run)) {
    throw new TypeError('job run must be an object');
  }
  const allowed = [
    'schema',
    'job_id',
    'attempt',
    'timeout_ms',
    'retry',
    'state',
    'started_at',
    'finished_at',
    'next_attempt_at',
    'makes_model_call',
    'cost_cap',
    'error',
  ];
  const keys = Object.keys(run);
  if (keys.length !== allowed.length || allowed.some((key) => !Object.hasOwn(run, key))) {
    throw new TypeError('job run keys do not match job-run.v1');
  }
  if (run.schema !== SCHEMA_ID) throw new TypeError('schema must be job-run.v1');
  assertJobId(run.job_id);
  if (!Number.isSafeInteger(run.attempt) || run.attempt < 1) {
    throw new TypeError('attempt must be a positive integer');
  }
  if (!Number.isSafeInteger(run.timeout_ms) || run.timeout_ms < 1) {
    throw new TypeError('timeout_ms must be an integer greater than or equal to one');
  }
  const retry = copyRetry(run.retry);
  if (retry.max_attempts !== run.retry.max_attempts || !sameMembers(run.retry.backoff, retry.backoff)) {
    throw new TypeError('retry policy has extra fields');
  }
  if (Object.keys(run.retry).length !== 2) throw new TypeError('retry policy has extra fields');
  if (run.attempt > retry.max_attempts) {
    throw new TypeError('attempt exceeds retry.max_attempts');
  }
  if (run.state !== 'running' && !TERMINAL.has(run.state)) {
    throw new TypeError('state must be running, ok, failed, or dead-lettered');
  }
  assertStoredTimestamp(run.started_at, 'started_at');
  if (typeof run.makes_model_call !== 'boolean') {
    throw new TypeError('makes_model_call must be a boolean');
  }
  assertCostCap(run.cost_cap);
  refuseUncappedModelRetry(run.attempt, run.makes_model_call, run.cost_cap, run.next_attempt_at);
  if (run.error !== null && (typeof run.error !== 'string' || run.error.length < 1)) {
    throw new TypeError('error must be null or a non-empty string');
  }
  if (typeof run.error === 'string') assertPublicText(run.error, 'error');

  if (run.state === 'running') {
    if (run.finished_at !== null || run.next_attempt_at !== null || run.error !== null) {
      throw new TypeError('a running attempt has no finish, next attempt, or error');
    }
    return;
  }

  assertStoredTimestamp(run.finished_at, 'finished_at');
  if (instantMs(run.finished_at) < instantMs(run.started_at)) {
    throw new TypeError('finished_at is earlier than started_at');
  }

  if (run.state === 'ok') {
    if (run.next_attempt_at !== null || run.error !== null) {
      throw new TypeError('an ok attempt has no next attempt and no error');
    }
    return;
  }

  if (typeof run.error !== 'string') throw new TypeError('a failed attempt records an error');
  if (run.state === 'dead-lettered') {
    if (run.next_attempt_at !== null) throw new TypeError('a dead-lettered attempt has no next attempt');
    if (run.attempt !== retry.max_attempts) {
      throw new TypeError('dead-letter requires attempt to equal retry.max_attempts');
    }
    return;
  }

  if (run.attempt === retry.max_attempts && run.next_attempt_at !== null) {
    throw new TypeError('next_attempt_at must be null when no attempt remains');
  }

  if (run.next_attempt_at !== null) {
    assertStoredTimestamp(run.next_attempt_at, 'next_attempt_at');
    const expected = addMillis(run.finished_at, backoffDelayMs(retry.backoff, run.attempt));
    if (run.next_attempt_at !== expected) {
      throw new TypeError('next_attempt_at must equal finished_at plus the backoff delay');
    }
  }
}

function assertRunning(run) {
  assertJobRun(run);
  if (run.state !== 'running') throw new TypeError('attempt is not running');
}

/**
 * Open an attempt. The first attempt may run without a cost cap.
 * Opening attempt > 1 for a model call throws RetryRefused unless cost_cap is explicit.
 */
export function openRun(config, clock) {
  if (config === null || typeof config !== 'object' || Array.isArray(config)) {
    throw new TypeError('job config is required');
  }
  const startedAt = readClock(clock);
  const attempt = config.attempt === undefined ? 1 : config.attempt;
  const costCap = config.cost_cap === undefined ? null : config.cost_cap;
  refuseUncappedModelRetry(attempt, config.makes_model_call, costCap);
  return seal({
    schema: SCHEMA_ID,
    job_id: config.job_id,
    attempt,
    timeout_ms: config.timeout_ms,
    retry: copyRetry(config.retry),
    state: 'running',
    started_at: startedAt,
    finished_at: null,
    next_attempt_at: null,
    makes_model_call: config.makes_model_call,
    cost_cap: costCap,
    error: null,
  });
}

export function recordSuccess(run, clock) {
  assertRunning(run);
  const finishedAt = readClock(clock);
  if (instantMs(finishedAt) < instantMs(run.started_at)) {
    throw new TypeError('clock is earlier than started_at');
  }
  return seal({
    ...run,
    state: 'ok',
    finished_at: finishedAt,
    next_attempt_at: null,
    error: null,
  });
}

export function recordFailure(run, clock, info = {}) {
  assertRunning(run);
  if (info === null || typeof info !== 'object' || Array.isArray(info)) {
    throw new TypeError('failure info must be an object');
  }
  if (typeof info.error !== 'string' || info.error.length < 1) {
    throw new TypeError('failure error must be a non-empty string');
  }
  const finishedAt = readClock(clock);
  if (instantMs(finishedAt) < instantMs(run.started_at)) {
    throw new TypeError('clock is earlier than started_at');
  }
  return seal({
    ...run,
    state: 'failed',
    finished_at: finishedAt,
    next_attempt_at: null,
    error: info.error,
  });
}

/**
 * True when a running attempt's elapsed time is past timeout_ms.
 * The deadline itself is still inside the budget.
 */
export function isStale(run, clock) {
  assertJobRun(run);
  if (run.state !== 'running') return false;
  const now = readClock(clock);
  return instantMs(now) - instantMs(run.started_at) > run.timeout_ms;
}

/**
 * Mark a running attempt failed because the injected clock is past its timeout.
 * Does not schedule a retry and does not dead-letter.
 */
export function markStaleFailed(run, clock) {
  assertRunning(run);
  const now = readClock(clock);
  const elapsed = instantMs(now) - instantMs(run.started_at);
  if (elapsed <= run.timeout_ms) throw new TypeError('run is not past its timeout');
  return seal({
    ...run,
    state: 'failed',
    finished_at: now,
    next_attempt_at: null,
    error: 'stale: exceeded timeout',
  });
}

/**
 * After a failed attempt, schedule the next attempt or dead-letter.
 * A model call with no explicit cost cap throws RetryRefused and schedules nothing.
 */
export function resolveFailure(run, clock) {
  assertJobRun(run);
  if (run.state !== 'failed') throw new TypeError('only a failed attempt can be resolved');
  const now = readClock(clock);
  if (instantMs(now) < instantMs(run.finished_at)) {
    throw new TypeError('clock is earlier than finished_at');
  }
  if (run.attempt >= run.retry.max_attempts) {
    return {
      action: 'dead-letter',
      run: seal({
        ...run,
        state: 'dead-lettered',
        next_attempt_at: null,
      }),
    };
  }
  refuseUncappedModelRetry(run.attempt + 1, run.makes_model_call, run.cost_cap);
  const delay = backoffDelayMs(run.retry.backoff, run.attempt);
  const nextAttemptAt = addMillis(run.finished_at, delay);
  return {
    action: 'retry',
    next_attempt_at: nextAttemptAt,
    run: seal({
      ...run,
      next_attempt_at: nextAttemptAt,
    }),
  };
}

function isRelativeProof(proofPath) {
  if (typeof proofPath !== 'string' || proofPath.length === 0 || proofPath.trim().length === 0) return false;
  if (proofPath.startsWith('/') || proofPath.startsWith('\\') || proofPath.startsWith('~')) return false;
  if (/^[A-Za-z]:[\\/]/.test(proofPath)) return false;
  // A URI scheme is not a repository-relative proof, even when it has no leading slash.
  if (/^[a-z][a-z0-9+.-]*:/i.test(proofPath) || proofPath.includes('://')) return false;
  const normalized = proofPath.replaceAll('\\', '/');
  if (normalized === '..' || normalized.startsWith('../') || normalized.startsWith('/')) return false;
  if (normalized.split('/').includes('..')) return false;
  return true;
}

/**
 * Ledger row for the cockpit read shape documented in this module's README.
 * Emits the fields the repo's run-record reader keeps. Terminal attempts only.
 */
export function toCockpitRunRecord(run, options = {}) {
  assertJobRun(run);
  if (!TERMINAL.has(run.state)) throw new TypeError('only a terminal attempt projects to a cockpit run record');
  if (options === null || typeof options !== 'object' || Array.isArray(options)) {
    throw new TypeError('projection options must be an object');
  }
  const proofPath = options.proof_path;
  if (!isRelativeProof(proofPath)) throw new TypeError('proof_path must be a relative path');
  assertPublicText(proofPath, 'proof_path');
  const duration = instantMs(run.finished_at) - instantMs(run.started_at);
  if (!Number.isSafeInteger(duration) || duration < 0) throw new TypeError('duration_ms is not a finite duration');
  const record = {
    ts: run.finished_at,
    task: run.job_id,
    status: run.state,
    duration_ms: duration,
    proof_path: proofPath,
  };
  if (run.error !== null) record.error = run.error;
  if (options.suggested_action !== undefined) {
    if (typeof options.suggested_action !== 'string' || options.suggested_action.length < 1) {
      throw new TypeError('suggested_action must be a non-empty string');
    }
    assertPublicText(options.suggested_action, 'suggested_action');
    record.suggested_action = options.suggested_action;
  }
  return record;
}
