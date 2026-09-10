import {execFileSync,spawnSync} from 'node:child_process';
const status=JSON.parse(execFileSync('supabase',['status','-o','json',...(process.env.DOLPIN_QA_SUPABASE_WORKDIR?['--workdir',process.env.DOLPIN_QA_SUPABASE_WORKDIR]:[])],{encoding:'utf8',stdio:['ignore','pipe','pipe']}));
if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(status.API_URL))throw new Error('Expected local Supabase');
const result=spawnSync('deno',['test','--allow-env','--allow-net','--allow-run=docker','scripts/qa/finance_test.ts'],{stdio:'inherit',env:{...process.env,SUPABASE_URL:status.API_URL,SUPABASE_ANON_KEY:status.ANON_KEY,SUPABASE_SERVICE_ROLE_KEY:status.SERVICE_ROLE_KEY,DOLPIN_WEB_URL:'http://127.0.0.1:3010'}});
process.exit(result.status??1);
