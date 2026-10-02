import { pathToFileURL } from 'node:url';

const alertCounters = [
  'pushNeedsReview', 'photoCleanupNeedsReview', 'payoutNeedsReview',
  'paymentRecoveryStalled', 'stalledClosures', 'stalledNotifications', 'alertDeliveryFailures',
];

export function assessOperations(health, now = Date.now(), maxAgeMs = 300_000) {
  const issues = [];
  const services = health?.services;
  const age = value => typeof value === 'string' && Number.isFinite(Date.parse(value))
    ? now - Date.parse(value) : Infinity;
  if (!services || typeof services !== 'object' || age(health?.observedAt) > 60_000 || age(health?.observedAt) < -60_000) {
    return { healthy: false, livenessHealthy: false, issues: ['INVALID_HEALTH_SNAPSHOT'], counts: {} };
  }
  for (const name of ['delivery', 'payments']) {
    const config = name === 'delivery' ? services : services.payments;
    const worker = health?.workers?.[name];
    if (config?.configured !== true) issues.push(`${name.toUpperCase()}_NOT_CONFIGURED`);
    if (config?.scheduled !== true) issues.push(`${name.toUpperCase()}_NOT_SCHEDULED`);
    if (age(config?.lastDispatch?.at) > maxAgeMs) issues.push(`${name.toUpperCase()}_DISPATCH_STALE`);
    if (age(worker?.lastSuccessAt) > maxAgeMs) issues.push(`${name.toUpperCase()}_SUCCESS_STALE`);
    if (worker?.lastCompleted?.timedOut === true || worker?.lastCompleted?.status !== 200) {
      issues.push(`${name.toUpperCase()}_LAST_RUN_FAILED`);
    }
  }
  // Deployment checks that workers are configured and executing successfully.
  // Existing business review queues still alert, but must not block a repair.
  const livenessHealthy = issues.length === 0;
  const counts = {};
  for (const key of alertCounters) {
    const value = services[key];
    if (!Number.isSafeInteger(value) || value < 0) issues.push(`INVALID_${key}`);
    else { counts[key] = value; if (value > 0) issues.push(key); }
  }
  const needsReview = services.payments?.needsReview;
  if (!Number.isSafeInteger(needsReview) || needsReview < 0) issues.push('INVALID_PAYMENT_REVIEW_COUNT');
  else { counts.paymentNeedsReview = needsReview; if (needsReview > 0) issues.push('paymentNeedsReview'); }
  return { healthy: issues.length === 0, livenessHealthy, issues, counts };
}

function httpsEndpoint(value, name) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:' || url.username || url.password || /localhost|127\.0\.0\.1|example\./i.test(url.hostname)) throw new Error();
    return url;
  } catch { throw new Error(`Configure ${name} as an HTTPS endpoint`); }
}

export async function runWatchdog(env = process.env) {
  let summary;
  let alertUrl;
  try {
    alertUrl = httpsEndpoint(env.DOLPIN_WATCHDOG_WEBHOOK_URL, 'DOLPIN_WATCHDOG_WEBHOOK_URL');
    const base = httpsEndpoint(env.DOLPIN_OPS_URL, 'DOLPIN_OPS_URL');
    const key = env.DOLPIN_OPS_SERVICE_KEY;
    if (!key || key.length < 32 || /placeholder|replace_me|your-/i.test(key)) throw new Error('Configure DOLPIN_OPS_SERVICE_KEY');
    const response = await fetch(new URL('/rest/v1/rpc/operations_health', base), {
      method: 'POST', headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: '{}', signal: AbortSignal.timeout(15_000), redirect: 'error',
    });
    if (!response.ok) summary = { healthy: false, livenessHealthy: false, issues: [`HEALTH_HTTP_${response.status}`], counts: {} };
    else summary = assessOperations(await response.json());
  } catch {
    summary = { healthy: false, livenessHealthy: false, issues: ['WATCHDOG_CONFIGURATION_OR_TRANSPORT_FAILURE'], counts: {} };
  }
  // Only fixed event names and aggregate counters are logged or sent externally.
  console.log(JSON.stringify({ event: 'dolpin_watchdog', ...summary }));
  if (!summary.healthy) {
    if (!alertUrl) console.error('Watchdog alert endpoint is missing or invalid.');
    else {
      try {
        const response = await fetch(alertUrl, {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ event: 'dolpin_operations_unhealthy', ...summary }),
          signal: AbortSignal.timeout(10_000), redirect: 'error',
        });
        if (!response.ok) console.error(`Watchdog alert failed with HTTP ${response.status}.`);
      } catch { console.error('Watchdog alert could not be delivered.'); }
    }
    return false;
  }
  return true;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (!await runWatchdog()) process.exitCode = 1;
}
