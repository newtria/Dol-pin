import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const statuses = new Set(['created', 'running', 'paused', 'restarting', 'removing', 'exited', 'dead']);
const healthStates = new Set(['none', 'starting', 'healthy', 'unhealthy']);
const knownSqlCodes = ['08000', '08001', '08003', '08006', '22023', '22P02', '23502', '23503', '23505', '23514', '42501', '40001', '40P01', '53300', '53400', '57014', '57P01', '57P02', '57P03', 'P0001', 'P0002', 'P4290'];
const logPatterns = {
  connectionRefused: /connection refused/gi,
  connectionReset: /connection reset/gi,
  upstreamFailure: /invalid response from upstream|invalid response upstream|upstream prematurely closed|upstream connect error/gi,
  requestTimeout: /timed out|timeout exceeded|context deadline exceeded/gi,
  databaseCapacity: /too many connections|remaining connection slots/gi,
  permissionDenied: /permission denied|insufficient privilege/gi,
  outOfMemory: /out of memory|oom[- ]kill/gi,
  unavailableDatabase: /database system is starting up|database system is shutting down/gi,
};

export function summarizeService(state, logs) {
  const count = pattern => [...String(logs ?? '').matchAll(pattern)].length;
  const counters = Object.fromEntries(Object.entries(logPatterns).map(([key, pattern]) => [key, count(pattern)]));
  const sqlCodes = Object.fromEntries(knownSqlCodes.map(code => [code, count(new RegExp(`\\b${code}\\b`, 'g'))]).filter(([, value]) => value > 0));
  const integer = value => Number.isSafeInteger(value) && value >= 0 ? value : null;
  return {
    status: statuses.has(state?.status) ? state.status : 'unknown',
    health: healthStates.has(state?.health) ? state.health : 'unknown',
    running: state?.running === true,
    oomKilled: state?.oomKilled === true,
    exitCode: integer(state?.exitCode),
    restartCount: integer(state?.restartCount),
    counters, sqlCodes,
  };
}

function docker(args) {
  return spawnSync('docker', args, { cwd: root, encoding: 'utf8', timeout: 10_000,
    maxBuffer: 4 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'] });
}

function collect() {
  const project = /^project_id\s*=\s*"([a-zA-Z0-9_-]+)"/m.exec(readFileSync(join(root, 'supabase/config.toml'), 'utf8'))?.[1];
  if (!project) throw new Error('Local Supabase project identifier is missing.');
  const services = {};
  const format = '{"status":{{json .State.Status}},"running":{{json .State.Running}},"oomKilled":{{json .State.OOMKilled}},"exitCode":{{json .State.ExitCode}},"restartCount":{{json .RestartCount}},"health":{{if .State.Health}}{{json .State.Health.Status}}{{else}}"none"{{end}}}';
  for (const name of ['storage', 'kong', 'db']) {
    const container = `supabase_${name}_${project}`;
    const inspected = docker(['inspect', '--format', format, container]);
    let state;
    if (inspected.status === 0) { try { state = JSON.parse(inspected.stdout); } catch { /* Report unavailable state. */ } }
    const logs = docker(['logs', '--since', '15m', '--tail', '1000', container]);
    // Raw logs exist only in process memory. Never print them or save them to
    // artifacts: provider errors can contain tokens, account data and URLs.
    services[name] = {
      inspectAvailable: inspected.status === 0 && !!state,
      logSampleAvailable: logs.status === 0,
      ...summarizeService(state, logs.status === 0 ? `${logs.stdout}\n${logs.stderr}` : ''),
    };
  }
  const summary = JSON.stringify({ event: 'local_ci_services', sampledMinutes: 15, maxLinesPerService: 1000, services }, null, 2);
  writeFileSync('/tmp/dolpin-ci-service-diagnostics.json', summary + '\n', { mode: 0o600 });
  console.log(summary);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) collect();
