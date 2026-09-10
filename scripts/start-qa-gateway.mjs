import {execFileSync,spawn} from 'node:child_process';
const s=JSON.parse(execFileSync('supabase',['status','-o','json',...(process.env.DOLPIN_QA_SUPABASE_WORKDIR?['--workdir',process.env.DOLPIN_QA_SUPABASE_WORKDIR]:[])],{encoding:'utf8',stdio:['ignore','pipe','pipe']}));
if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(s.API_URL))throw new Error('Expected local Supabase');
const child=spawn('deno',['run','--allow-env','--allow-net','--allow-run=docker','scripts/qa/server.ts'],{stdio:'inherit',env:{...process.env,SUPABASE_URL:s.API_URL,SUPABASE_ANON_KEY:s.ANON_KEY,SUPABASE_SERVICE_ROLE_KEY:s.SERVICE_ROLE_KEY,DOLPIN_WEB_URL:'http://127.0.0.1:3010'}});
for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>child.kill(signal));
child.on('exit',code=>process.exit(code??1));
