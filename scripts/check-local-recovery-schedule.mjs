import {execFileSync} from 'node:child_process';
import {createClient} from '@supabase/supabase-js';
const status=JSON.parse(execFileSync('supabase',['status','-o','json'],{encoding:'utf8',stdio:['ignore','pipe','pipe']}));
if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(status.API_URL))throw new Error('Schedule QA is local only');
const admin=createClient(status.API_URL,status.SERVICE_ROLE_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
// Fail before enabling cron if the actual Edge runtime is not reachable.
const response=await fetch(`${status.API_URL}/functions/v1/rental-recovery`,{method:'POST',signal:AbortSignal.timeout(10000)});
await response.body?.cancel();
if(response.status!==401)throw new Error('Start supabase functions serve before schedule QA');
const started=Date.now();
execFileSync(process.execPath,['scripts/configure-local-recovery.mjs'],{stdio:'inherit'});
while(Date.now()-started<90000) {
 const {data,error}=await admin.rpc('rental_recovery_health');
 if(error)throw new Error('Recovery health query failed');
 if(data.configured&&data.scheduled&&data.lastDispatch&&Date.parse(data.lastDispatch.at)>=started&&data.lastDispatch.status===200) {
  console.log('Scheduled DB → pg_net → Edge recovery returned HTTP 200.');
  process.exit(0);
 }
 if(data.lastDispatch&&Date.parse(data.lastDispatch.at)>=started&&(data.lastDispatch.timedOut||data.lastDispatch.status>=400))throw new Error(`Scheduled recovery failed (HTTP ${data.lastDispatch.status??'timeout'})`);
 await new Promise(resolve=>setTimeout(resolve,1000));
}
throw new Error('No successful scheduled recovery delivery within 90 seconds');
