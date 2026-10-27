import {spawnSync} from 'node:child_process';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {projectRoot, validateLocalStatus, writeLocalClientEnv} from './setup-local-env.mjs';

function command(tool, args, {capture = false, hint, env = process.env} = {}) {
  const result = spawnSync(tool, args, {
    cwd: projectRoot, env, encoding: 'utf8', stdio: capture ? ['ignore', 'pipe', 'pipe'] : 'inherit',
  });
  if (result.error || result.status !== 0) throw new Error(hint ?? `${tool} ${args.join(' ')} failed`);
  return result.stdout ?? '';
}

export function setupLocal({run = command, writeEnv = writeLocalClientEnv, root = projectRoot} = {}) {
  run('supabase', ['--version'], {capture: true, hint: 'Install Supabase CLI 2.107.0 or later and make it available on PATH.'});
  run('docker', ['info', '--format', '{{.ServerVersion}}'], {capture: true, hint: 'Start a Docker-compatible container runtime first.'});
  run('supabase', ['start', '-x', 'vector,logflare']);
  // Validate the local target before applying pending migrations. Never reset an
  // existing database or require a linked hosted project for local development.
  const status = validateLocalStatus(JSON.parse(run('supabase', ['status', '-o', 'json'], {capture: true})));
  run('supabase', ['migration', 'up', '--local']);
  writeEnv(root, status);
  run(process.execPath, [join(root, 'scripts/configure-local-recovery.mjs')], {
    env: {...process.env, DOLPIN_QA_SUPABASE_WORKDIR: root, DOLPIN_RECOVERY_ENDPOINT: 'http://supabase_kong_dol-pin:8000/functions/v1/rental-recovery'},
  });
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    setupLocal();
    console.log('Local database, migrations, recovery schedule and client environment are ready.');
    console.log('Run npm run web and npm run backend in separate terminals. Confirmation emails: http://127.0.0.1:55324');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
