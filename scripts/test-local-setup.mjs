import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {validateLocalStatus, writeLocalClientEnv} from './setup-local-env.mjs';
import {setupLocal} from './setup-local.mjs';
import {GET} from '../apps/web/app/local-preview/[document]/route.ts';

const jwt = role => ['header', Buffer.from(JSON.stringify({role})).toString('base64url'), 'signature'].join('.');
const status = {API_URL: 'http://127.0.0.1:55321', ANON_KEY: jwt('anon'), SERVICE_ROLE_KEY: 'server-only-fixture'};
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'dolpin-setup-'));
  t.after(() => rmSync(root, {recursive: true, force: true}));
  return root;
}

test('a fresh checkout gets local client URLs, an anon key and usable development notice URLs', t => {
  const root = fixture(t);
  writeLocalClientEnv(root, status);
  for (const [app, prefix] of [['mobile', 'EXPO_PUBLIC'], ['web', 'NEXT_PUBLIC']]) {
    const path = join(root, 'apps', app, '.env.local');
    const content = readFileSync(path, 'utf8');
    assert.ok(content.includes(`${prefix}_SUPABASE_URL=${status.API_URL}\n`));
    assert.ok(content.includes(`${prefix}_SUPABASE_ANON_KEY=${status.ANON_KEY}\n`));
    assert.ok(content.includes(`${prefix}_TERMS_URL=http://127.0.0.1:3000/local-preview/terms\n`));
    assert.ok(content.includes(`${prefix}_PRIVACY_URL=http://127.0.0.1:3000/local-preview/privacy\n`));
    assert.ok(!content.includes(status.SERVICE_ROLE_KEY));
    if (process.platform !== 'win32') assert.equal(statSync(path).mode & 0o777, 0o600);
  }
});

test('repeat setup preserves other settings, fills blank defaults and removes duplicate managed keys', t => {
  const root = fixture(t), path = join(root, 'apps/web/.env.local');
  mkdirSync(join(root, 'apps/web'), {recursive: true});
  writeFileSync(path, '# Custom settings\r\nNEXT_PUBLIC_TOSS_CLIENT_KEY=test_ck_fixture\r\nNEXT_PUBLIC_TERMS_URL=https://policies.example.test/terms\r\nNEXT_PUBLIC_PRIVACY_URL=""\r\nNEXT_PUBLIC_SUPABASE_URL=old\r\nexport NEXT_PUBLIC_SUPABASE_URL=duplicate\r\n');
  writeLocalClientEnv(root, status);
  const first = readFileSync(path, 'utf8');
  assert.match(first, /# Custom settings\nNEXT_PUBLIC_TOSS_CLIENT_KEY=test_ck_fixture\n/);
  assert.match(first, /NEXT_PUBLIC_TERMS_URL=https:\/\/policies\.example\.test\/terms\n/);
  assert.match(first, /NEXT_PUBLIC_PRIVACY_URL=http:\/\/127\.0\.0\.1:3000\/local-preview\/privacy\n/);
  assert.equal(first.match(/NEXT_PUBLIC_SUPABASE_URL=/g).length, 1);
  writeLocalClientEnv(root, status);
  assert.equal(readFileSync(path, 'utf8'), first);
});

test('remote URLs, invalid ports and privileged or multiline keys cannot write client configuration', t => {
  const root = fixture(t);
  for (const invalid of [
    {...status, API_URL: 'https://project.supabase.co'},
    {...status, API_URL: 'http://127.0.0.1:55321@remote.example.test'},
    {...status, API_URL: 'http://127.0.0.1:99999'},
    {...status, ANON_KEY: jwt('service_role')},
    {...status, ANON_KEY: `${jwt('anon')}\nOTHER=value`},
  ]) assert.throws(() => writeLocalClientEnv(root, invalid));
  assert.equal(existsSync(join(root, 'apps')), false);
  assert.equal(validateLocalStatus(status), status);
});

test('setup applies only local pending migrations, preserves data and configures recovery after validation', () => {
  const calls = [];
  setupLocal({
    root: '/fixture/checkout',
    run: (tool, args, options) => {
      calls.push({tool, args, options});
      return args[0] === 'status' ? JSON.stringify(status) : '2.107.0';
    },
    writeEnv: (root, result) => calls.push({tool: 'writeEnv', root, result}),
  });
  assert.deepEqual(calls.slice(0, 5).map(({tool, args}) => [tool, ...args]), [
    ['supabase', '--version'], ['docker', 'info', '--format', '{{.ServerVersion}}'],
    ['supabase', 'start', '-x', 'vector,logflare'], ['supabase', 'status', '-o', 'json'],
    ['supabase', 'migration', 'up', '--local'],
  ]);
  assert.equal(calls[5].tool, 'writeEnv');
  assert.equal(calls[5].root, '/fixture/checkout');
  assert.deepEqual(calls[6].args, ['/fixture/checkout/scripts/configure-local-recovery.mjs']);
  assert.equal(calls[6].options.env.DOLPIN_QA_SUPABASE_WORKDIR, '/fixture/checkout');
  assert.equal(calls.some(call => call.args?.includes('reset') || call.args?.includes('--linked')), false);
});

test('missing prerequisites and unsafe status stop setup before migration or client file changes', () => {
  for (const failingTool of ['supabase', 'docker', 'status']) {
    const calls = [];
    assert.throws(() => setupLocal({
      run: (tool, args) => {
        calls.push(args);
        if (tool === failingTool) throw new Error('Unavailable prerequisite');
        return args[0] === 'status' ? JSON.stringify({...status, API_URL: 'https://remote.example.test'}) : '';
      },
      writeEnv: () => assert.fail('Must not write client files'),
    }));
    assert.equal(calls.some(args => args.includes('migration')), false);
  }
});

test('development notices are available only in development with a local backend', async t => {
  const previous = {NODE_ENV: process.env.NODE_ENV, NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL};
  t.after(() => {for (const [key, value] of Object.entries(previous)) value === undefined ? delete process.env[key] : process.env[key] = value;});
  const request = new Request('http://127.0.0.1:3000/local-preview/terms');
  const context = document => ({params: Promise.resolve({document})});
  process.env.NODE_ENV = 'development';process.env.NEXT_PUBLIC_SUPABASE_URL = status.API_URL;
  for (const document of ['terms', 'privacy']) {
    const response = await GET(request, context(document));
    assert.equal(response.status, 200);assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.match(await response.text(), /로컬 개발용/);
  }
  assert.equal((await GET(request, context('unknown'))).status, 404);
  process.env.NODE_ENV = 'production';
  assert.equal((await GET(request, context('terms'))).status, 404);
  process.env.NODE_ENV = 'development';process.env.NEXT_PUBLIC_SUPABASE_URL = 'https://hosted.supabase.co';
  assert.equal((await GET(request, context('terms'))).status, 404);
});
