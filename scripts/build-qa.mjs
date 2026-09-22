import {execFileSync,spawnSync} from 'node:child_process';
const s=JSON.parse(execFileSync('supabase',['status','-o','json',...(process.env.DOLPIN_QA_SUPABASE_WORKDIR?['--workdir',process.env.DOLPIN_QA_SUPABASE_WORKDIR]:[])],{encoding:'utf8',stdio:['ignore','pipe','pipe']}));
if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(s.API_URL))throw new Error('Expected local Supabase');
const result=spawnSync('npm',['run','build','-w','@dolpin/web'],{stdio:'inherit',env:{...process.env,DOLPIN_NEXT_DIST_DIR:'.next-qa',NEXT_PUBLIC_SUPABASE_URL:'http://127.0.0.1:55325',NEXT_PUBLIC_SUPABASE_ANON_KEY:s.ANON_KEY,NEXT_TELEMETRY_DISABLED:'1'}});
process.exit(result.status??1);
