import { spawnSync } from 'node:child_process';
import { readdirSync, existsSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { assessOperations } from './operations-watchdog.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const env = process.env;
const required = key => {
  const value = env[key]?.trim();
  if (!value || /replace_me|placeholder|change-me|your-/i.test(value) || /[\r\n\0]/.test(value)) throw new Error(`Configure ${key}`);
  return value;
};
const target = required('DOLPIN_DEPLOY_ENVIRONMENT');
if (!['staging', 'production'].includes(target)) throw new Error('Invalid deployment environment.');
const ref = required('SUPABASE_PROJECT_REF');
const staging = required('DOLPIN_STAGING_PROJECT_REF');
const production = required('DOLPIN_PRODUCTION_PROJECT_REF');
if (![ref, staging, production].every(value => /^[a-z0-9]{20}$/.test(value)) || staging === production || ref !== (target === 'production' ? production : staging)) {
  throw new Error('Configure distinct staging and production project references and the matching environment project.');
}
const token = required('SUPABASE_ACCESS_TOKEN');
required('SUPABASE_DB_PASSWORD');
const serviceKey = required('SUPABASE_SERVICE_ROLE_KEY');
try {
  const claims = JSON.parse(Buffer.from(serviceKey.split('.')[1], 'base64url').toString('utf8'));
  if (claims.role !== 'service_role' || claims.ref !== ref) throw new Error();
} catch { throw new Error('Configure this project\'s service_role JWT; worker authorization requires the matching server key.'); }
const deliveryToken = required('SERVICE_DELIVERY_TOKEN');
if (deliveryToken.length < 32) throw new Error('SERVICE_DELIVERY_TOKEN must contain at least 32 characters.');
const secretNames = ['TOSS_SECRET_KEY', 'DOLPIN_WEB_URL', 'SERVICE_DELIVERY_TOKEN', 'OPS_ALERT_WEBHOOK_URL'];
const secretValues = Object.fromEntries(secretNames.map(key => [key, required(key)]));
for (const key of ['DOLPIN_WEB_URL', 'OPS_ALERT_WEBHOOK_URL']) {
  try {
    const url = new URL(secretValues[key]);
    if (url.protocol !== 'https:' || url.username || url.password || /localhost|127\.|example\./i.test(url.hostname)) throw new Error();
  } catch { throw new Error(`HTTPS endpoint required: ${key}`); }
}
if (target === 'production' && !secretValues.TOSS_SECRET_KEY.startsWith('live_sk_')) throw new Error('Production requires a live Toss API secret.');
if (target === 'staging' && !secretValues.TOSS_SECRET_KEY.startsWith('test_sk_')) throw new Error('Staging requires a test Toss API secret.');
for (const key of ['EXPO_ACCESS_TOKEN', 'GEMINI_API_KEY', 'GEMINI_MODEL']) if (env[key]?.trim()) secretValues[key] = required(key);

async function management(path, query) {
  const response = await fetch(`https://api.supabase.com/v1/projects/${ref}/${path}`, {
    method: query === undefined ? 'GET' : 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    ...(query === undefined ? {} : { body: JSON.stringify({ query }) }),
    signal: AbortSignal.timeout(30_000), redirect: 'error',
  });
  if (!response.ok) throw new Error(`Hosted project operation failed (${response.status}); response details are withheld.`);
  return response.json();
}

// Read-only provider check before mutations. Backup presence is not proof of a
// successful restoration and does not cover the underlying Storage object bytes.
const backups = await management('database/backups');
const logical = Array.isArray(backups.backups) ? backups.backups
  .filter(backup => backup.status === 'COMPLETED')
  .map(backup => Date.parse(backup.inserted_at)).filter(Number.isFinite) : [];
const physical = Number(backups.physical_backup_data?.latest_physical_backup_date_unix) * 1000;
const latestBackup = Math.max(0, ...logical, Number.isFinite(physical) ? physical : 0);
if (target === 'production' && (latestBackup > Date.now() + 60_000 || Date.now() - latestBackup > 36 * 3600_000)) {
  throw new Error('Production deployment requires a provider-reported completed database backup within 36 hours.');
}
console.log(JSON.stringify({ event: 'backup_preflight', recentDatabaseBackup: Date.now() - latestBackup <= 36 * 3600_000,
  pitrEnabled: backups.pitr_enabled === true, restoreVerified: false, storageBackupVerified: false }));

function cli(args, label) {
  // CLI errors can echo connection strings or secret payloads. Surface only the
  // failed operation and exit status; GitHub environment secrets remain masked.
  const result = spawnSync('supabase', args, { cwd: root, env, stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8', maxBuffer: 4 * 1024 * 1024 });
  if (result.error || result.status !== 0) throw new Error(`${label} failed (exit ${result.status ?? 'unavailable'}).`);
  console.log(`${label} succeeded.`);
}
cli(['link', '--project-ref', ref], 'Project link');
cli(['db', 'push', '--linked', '--dry-run'], 'Migration preflight');
cli(['db', 'push', '--linked', '--yes'], 'Database migration');
const temp = mkdtempSync(join(tmpdir(), 'dolpin-release-'));
try {
  const path = join(temp, '.env');
  writeFileSync(path, Object.entries(secretValues).map(([key, value]) => `${key}=${JSON.stringify(value)}`).join('\n') + '\n', { mode: 0o600 });
  cli(['secrets', 'set', '--project-ref', ref, '--env-file', path], 'Function secrets');
} finally { rmSync(temp, { recursive: true, force: true }); }

const functions = readdirSync(join(root, 'supabase/functions'), { withFileTypes: true })
  .filter(entry => entry.isDirectory() && !entry.name.startsWith('_') && existsSync(join(root, 'supabase/functions', entry.name, 'index.ts')))
  .map(entry => entry.name).sort();
if (!functions.length) throw new Error('No Edge Functions found.');
for (const name of functions) cli(['functions', 'deploy', name, '--project-ref', ref, '--use-api'], `Deploy ${name}`);

const literal = value => `'${value.replaceAll("'", "''")}'`;
const settings = {
  dolpin_recovery_url: `https://${ref}.supabase.co/functions/v1/rental-recovery`,
  dolpin_recovery_token: serviceKey,
  dolpin_service_delivery_url: `https://${ref}.supabase.co/functions/v1/service-delivery`,
  dolpin_service_delivery_token: deliveryToken,
};
await management('database/query', `DO $configure$
DECLARE existing uuid;
BEGIN
${Object.entries(settings).map(([name, value]) => `SELECT id INTO existing FROM vault.secrets WHERE name=${literal(name)};
IF existing IS NULL THEN PERFORM vault.create_secret(${literal(value)},${literal(name)});
ELSE PERFORM vault.update_secret(existing,${literal(value)}); END IF;`).join('\n')}
PERFORM cron.alter_job(jobid,active:=true) FROM cron.job WHERE jobname IN ('dolpin-reconcile-rentals','dolpin-service-delivery');
END $configure$;`);
const configuredAt = Date.now();
let healthy = false;
// Read observations from the real scheduler. Do not manually trigger financial
// actions or claim a successful release merely because uploads succeeded.
for (let attempt = 0; attempt < 12; attempt++) {
  await new Promise(resolve => setTimeout(resolve, 15_000));
  try {
    const response = await fetch(`https://${ref}.supabase.co/rest/v1/rpc/operations_health`, {
      method: 'POST', headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' },
      body: '{}', signal: AbortSignal.timeout(10_000), redirect: 'error',
    });
    if (!response.ok) continue;
    const health = await response.json();
    if (assessOperations(health).livenessHealthy && ['delivery', 'payments'].every(name =>
      Date.parse(health.workers?.[name]?.lastSuccessAt) >= configuredAt)) { healthy = true; break; }
  } catch { /* The bounded read-only health gate retries transport failures. */ }
}
if (!healthy) throw new Error('Backend was applied, but scheduled worker health did not pass. Investigate the deployment; no automatic database rollback was attempted.');
console.log(`Backend deployment and scheduled delivery checks passed for ${target}; ${functions.length} Edge Functions included.`);
