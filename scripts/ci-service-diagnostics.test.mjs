import test from 'node:test';
import assert from 'node:assert/strict';
import { summarizeService } from './ci-service-diagnostics.mjs';

test('diagnostic artifact exposes only fixed counters and container state', () => {
  const result = summarizeService({ status: 'running', health: 'healthy', running: true, exitCode: 0, restartCount: 2,
    Error: 'Bearer private-token', name: 'private@example.com' },
  'connection refused https://private.invalid?token=secret\npermission denied SQLSTATE 42501 private@example.com\nBearer secret');
  assert.equal(result.counters.connectionRefused, 1);
  assert.equal(result.counters.permissionDenied, 1);
  assert.equal(result.sqlCodes['42501'], 1);
  assert.equal(result.restartCount, 2);
  assert.doesNotMatch(JSON.stringify(result), /private|secret|Bearer|https/);
});
test('invalid inspect data cannot be copied into the artifact', () => {
  const result = summarizeService({ status: 'secret-token', health: 'private@example.com', exitCode: 'account-number', restartCount: -1 }, '');
  assert.equal(result.status, 'unknown');
  assert.equal(result.health, 'unknown');
  assert.equal(result.exitCode, null);
  assert.equal(result.restartCount, null);
});
