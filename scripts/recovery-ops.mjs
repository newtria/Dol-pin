import {execFileSync} from 'node:child_process';
import {createClient} from '@supabase/supabase-js';

let url=process.env.DOLPIN_OPS_URL,key=process.env.DOLPIN_OPS_SERVICE_KEY;
if(!url&&!key) {
 const local=JSON.parse(execFileSync('supabase',['status','-o','json'],{encoding:'utf8',stdio:['ignore','pipe','pipe']}));
 if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(local.API_URL))throw new Error('Expected local Supabase');
 url=local.API_URL;key=local.SERVICE_ROLE_KEY;
}
if(!url||!key)throw new Error('Set both DOLPIN_OPS_URL and DOLPIN_OPS_SERVICE_KEY');
const args=process.argv.slice(2);
if(args.some((arg,i)=>!['--check','--retry'].includes(arg)&&args[i-1]!=='--retry'))throw new Error('Usage: recovery-ops.mjs [--check] [--retry money:UUID|checkout:ORDER_ID]');
const admin=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
function checked(result){if(result.error)throw new Error(`Recovery operation failed (${result.error.code??'transport'}).`);return result.data;}
if(args.includes('--retry')) {
 const target=args[args.indexOf('--retry')+1]??'';
 const match=/^(money|checkout):([a-zA-Z0-9_-]{1,100})$/.exec(target);
 if(!match)throw new Error('A specific money:UUID or checkout:ORDER_ID is required');
 const accepted=checked(await admin.rpc('retry_rental_recovery',{p_kind:match[1],p_key:match[2]}));
 if(!accepted)throw new Error('Recovery was not resumed: missing, finished or currently claimed');
 console.log('Reconciliation resumed. Financial holds and dispatch identifiers were preserved.');
}
const health=checked(await admin.rpc('rental_recovery_health'));
const queue=checked(await admin.from('rental_recovery_queue').select('kind,key,attempt_count,failure_count,last_error_code,review_required_at,next_attempt_at').order('review_required_at',{nullsFirst:false}).order('next_attempt_at').limit(50));
console.log(JSON.stringify({health,queue},null,2));
if(args.includes('--check')) {
 const last=health.lastDispatch;const age=last?Date.now()-Date.parse(last.at):Infinity;
 const inFlight=last&&last.status===null&&age<30000;
 if(!health.configured||!health.scheduled||health.needsReview>0||age>180000||last?.timedOut||(!inFlight&&last?.status!==200))process.exitCode=1;
}
