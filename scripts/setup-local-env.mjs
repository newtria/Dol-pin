import {execFileSync} from 'node:child_process';
import {mkdirSync, writeFileSync} from 'node:fs';
const status = JSON.parse(execFileSync('supabase', ['status', '-o', 'json'], {encoding: 'utf8'}));
if (!status.API_URL?.startsWith('http://127.0.0.1:')) throw new Error('Expected isolated local Supabase');
mkdirSync('apps/mobile', {recursive: true});
writeFileSync('apps/mobile/.env.local',
  `EXPO_PUBLIC_SUPABASE_URL=${status.API_URL}\nEXPO_PUBLIC_SUPABASE_ANON_KEY=${status.ANON_KEY}\n`, {mode: 0o600});
console.log('Wrote local public client configuration; no service role key included.');
