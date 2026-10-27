import {execFileSync} from 'node:child_process';
import {existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

export const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');

export function validateLocalStatus(status) {
  if (!/^http:\/\/127\.0\.0\.1:\d+$/.test(status.API_URL ?? '') || !new URL(status.API_URL).port) {
    throw new Error('Expected isolated local Supabase');
  }
  try {
    if (!/^[\w-]+\.[\w-]+\.[\w-]+$/.test(status.ANON_KEY)) throw new Error();
    const claims = JSON.parse(Buffer.from(status.ANON_KEY.split('.')[1], 'base64url').toString('utf8'));
    if (claims.role !== 'anon') throw new Error();
  } catch {
    throw new Error('Expected a local public anon key; client files cannot contain a service role key');
  }
  return status;
}

function mergeEnv(existing, managed, defaults) {
  const lines = existing.split(/\r?\n/);
  const present = new Set(lines.flatMap(line => {
    const match = /^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/.exec(line);
    return match && match[2] !== '' && match[2] !== '""' && match[2] !== "''" ? [match[1]] : [];
  }));
  const values = {...Object.fromEntries(Object.entries(defaults).filter(([key]) => !present.has(key))), ...managed};
  const kept = lines.filter(line => {
    const key = /^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=/.exec(line)?.[1];
    return !key || !(key in values);
  });
  while (kept.at(-1) === '') kept.pop();
  return [...kept, ...Object.entries(values).map(([key, value]) => `${key}=${value}`), ''].join('\n');
}

export function writeLocalClientEnv(root, status) {
  validateLocalStatus(status);
  for (const [app, prefix] of [['mobile', 'EXPO_PUBLIC'], ['web', 'NEXT_PUBLIC']]) {
    const path = join(root, 'apps', app, '.env.local');
    const existing = existsSync(path) ? readFileSync(path, 'utf8') : '';
    const content = mergeEnv(existing, {
      [`${prefix}_SUPABASE_URL`]: status.API_URL,
      [`${prefix}_SUPABASE_ANON_KEY`]: status.ANON_KEY,
    }, {
      [`${prefix}_TERMS_URL`]: 'http://127.0.0.1:3000/local-preview/terms',
      [`${prefix}_PRIVACY_URL`]: 'http://127.0.0.1:3000/local-preview/privacy',
    });
    mkdirSync(dirname(path), {recursive: true});
    const temporary = `${path}.tmp-${process.pid}`;
    try {
      writeFileSync(temporary, content, {mode: 0o600, flag: 'wx'});
      renameSync(temporary, path);
    } finally {
      rmSync(temporary, {force: true});
    }
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const status = JSON.parse(execFileSync('supabase', ['status', '-o', 'json'], {
    cwd: projectRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
  }));
  writeLocalClientEnv(projectRoot, status);
  console.log('Updated local public client configuration; preserved other settings. No service role key included.');
}
