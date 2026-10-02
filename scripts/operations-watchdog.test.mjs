import test from 'node:test';
import assert from 'node:assert/strict';
import { assessOperations } from './operations-watchdog.mjs';

const now = Date.parse('2026-01-01T00:10:00Z');
const recent = new Date(now - 60_000).toISOString();
function snapshot() {
  const worker = () => ({ lastSuccessAt: recent, lastCompleted: { at: recent, status: 200, timedOut: false } });
  return {
    observedAt: new Date(now).toISOString(),
    services: {
      configured: true, scheduled: true, lastDispatch: { at: recent },
      pushNeedsReview: 0, photoCleanupNeedsReview: 0, payoutNeedsReview: 0, paymentRecoveryStalled: 0,
      stalledClosures: 0, stalledNotifications: 0, alertDeliveryFailures: 0,
      payments: { configured: true, scheduled: true, lastDispatch: { at: recent }, needsReview: 0 },
    },
    workers: { delivery: worker(), payments: worker() },
  };
}
test('recent dispatch cannot hide repeated worker failures', () => {
  const value = snapshot();
  value.workers.delivery.lastSuccessAt = new Date(now - 600_000).toISOString();
  value.workers.delivery.lastCompleted.status = 500;
  const result = assessOperations(value, now);
  assert.equal(result.healthy, false);
  assert.equal(result.livenessHealthy, false);
  assert.ok(result.issues.includes('DELIVERY_SUCCESS_STALE'));
  assert.ok(result.issues.includes('DELIVERY_LAST_RUN_FAILED'));
});
test('business backlogs alert without vetoing deployment of healthy workers', () => {
  const value = snapshot();
  value.services.payoutNeedsReview = 2;
  value.services.paymentRecoveryStalled = 1;
  value.services.payments.needsReview = 3;
  value.services.alertDeliveryFailures = 1;
  const result = assessOperations(value, now);
  assert.equal(result.livenessHealthy, true);
  assert.equal(result.healthy, false);
  assert.ok(result.issues.includes('payoutNeedsReview'));
  assert.ok(result.issues.includes('paymentNeedsReview'));
  assert.ok(result.issues.includes('alertDeliveryFailures'));
  value.services.scheduled = false;
  assert.equal(assessOperations(value, now).livenessHealthy, false);
});
test('invalid or stale snapshots cannot pass the deployment liveness gate', () => {
  assert.equal(assessOperations(snapshot(), now).livenessHealthy, true);
  assert.equal(assessOperations(null, now).livenessHealthy, false);
  const value = snapshot();
  value.observedAt = new Date(now - 120_000).toISOString();
  assert.equal(assessOperations(value, now).livenessHealthy, false);
});
test('missing configuration, invalid counters and stale snapshots fail closed', () => {
  assert.equal(assessOperations(snapshot(), now).healthy, true);
  for (const change of [
    value => { value.services.scheduled = false; },
    value => { value.services.payments.configured = false; },
    value => { value.services.payoutNeedsReview = -1; },
    value => { value.observedAt = 'invalid'; },
    value => { value.services.paymentRecoveryStalled = 1; },
  ]) {
    const value = snapshot(); change(value);
    assert.equal(assessOperations(value, now).healthy, false);
  }
});
test('health output excludes arbitrary upstream fields and identifiers', () => {
  const value = snapshot();
  value.services.token = 'private-secret';
  value.services.user = 'private@example.com';
  assert.doesNotMatch(JSON.stringify(assessOperations(value, now)), /private|token|user/);
});
