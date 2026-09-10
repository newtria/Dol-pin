import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {jsonResponse} from '../_shared/http.ts';
import {reconcileCheckout,reconcileMoney} from '../_shared/rental-finance.ts';
import {paymentProvider,type ProviderFactory} from '../_shared/payment-provider.ts';
export function createHandler(providers:ProviderFactory=paymentProvider, fixtureScope?:()=>Promise<string[]>) {
 return async(req:Request):Promise<Response>=>{
  if(req.method!=='POST')return jsonResponse(405,{error:'Method not allowed'});
  const key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if(!key || req.headers.get('Authorization')!==`Bearer ${key}`)return jsonResponse(401,{error:'Unauthorized recovery'});
  const admin=createClient(Deno.env.get('SUPABASE_URL')!,key);
  // Oldest checked first prevents permanent unknowns starving newer work.
  let checkoutQuery=admin.from('toss_checkouts').select('order_id,reservations!inner(status)').eq('reservations.status','accepted').order('last_checked_at',{nullsFirst:true}).limit(20);
  let operationQuery=admin.from('rental_money_operations').select('id').eq('status','pending').order('last_checked_at',{nullsFirst:true}).limit(20);
  if(fixtureScope){const ids=await fixtureScope();checkoutQuery=checkoutQuery.in('reservation_id',ids);operationQuery=operationQuery.in('reservation_id',ids);}
  const [checkouts,operations]=await Promise.all([checkoutQuery,operationQuery]);
  if(checkouts.error || operations.error)return jsonResponse(503,{error:'Recovery queue unavailable'});
  const work=[...(checkouts.data??[]).map(c=>()=>reconcileCheckout(admin,c.order_id,undefined,providers)),...(operations.data??[]).map(op=>()=>reconcileMoney(admin,op.id,providers))];
  // Bounded concurrency; each command has its own DB claim.
  let completed=0,failed=0;
  for(let i=0;i<work.length;i+=4) {
   const results=await Promise.allSettled(work.slice(i,i+4).map(run=>run()));
   for(const result of results) {if(result.status==='rejected')failed++;else if(result.value.status!=='processing')completed++;}
  }
  return jsonResponse(failed?503:200,{checked:work.length,completed,failed});
 };
}
if(import.meta.main)Deno.serve(createHandler());
