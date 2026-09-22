import {fixture,checked,fakeProvider,png,localSql} from './fixture.ts';
import {createHandler as checkoutHandler} from '../../supabase/functions/toss-payment/index.ts';
import {createHandler as moneyHandler} from '../../supabase/functions/rental-payment/index.ts';
import {createHandler as recoveryHandler} from '../../supabase/functions/rental-recovery/index.ts';
function assert(v:unknown,message:string){if(!v)throw new Error(message);}
Deno.test('real DB: lost approvals, multiple windows, stale refund lock, private return and deposit reconciliation',async()=>{
 const f=await fixture();const ids:string[]=[];const pg=fakeProvider();const checkout=checkoutHandler(pg.factory),money=moneyHandler(pg.factory),recovery=recoveryHandler(pg.factory,async()=>ids);
 const call=async(handler:(req:Request)=>Promise<Response>,body:unknown,token?:string)=>{
  const response=await handler(new Request('http://127.0.0.1/test',{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(body)}));
  return {code:response.status,data:await response.json()};
 };
 const b=f.borrower.session.access_token,l=f.lender.session.access_token;
 try {
  const r=await f.rental();ids.push(r.id);
  const first=await call(checkout,{action:'prepare',reservationId:r.id},b);
  const second=await call(checkout,{action:'prepare',reservationId:r.id,mobile:true},b);
  assert(first.code===200&&second.code===200,'checkout failed');
  const params=new URLSearchParams(new URL(first.data.checkoutUrl).hash.slice(1));const orderId=params.get('orderId'),token=params.get('token');
  assert((await call(checkout,{action:'checkout',orderId,token})).code===200,'first window was revoked');
  pg.loseNextApproval();
  assert((await call(checkout,{action:'confirm',orderId,token,paymentKey:'qa-'+r.id,amount:r.total_paid})).code===502,'expected lost approval response');
  await localSql(`UPDATE public.reservations SET payment_due_at=now()-interval '1 minute' WHERE id='${r.id}';`);
  assert((await call(checkout,{action:'prepare',reservationId:r.id},b)).code===200,'expired recovery link rejected');
  assert((await call(recovery,{},Deno.env.get('SUPABASE_ANON_KEY'))).code===401,'anon recovery allowed');
  await localSql(`UPDATE public.toss_checkouts SET next_attempt_at=now() WHERE reservation_id IN (${ids.map(id=>`'${id}'`).join(',')}); UPDATE public.rental_money_operations SET next_attempt_at=now() WHERE reservation_id IN (${ids.map(id=>`'${id}'`).join(',')});`);
  await call(recovery,{},Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'));
  assert(checked(await f.admin.from('reservations').select('status').eq('id',r.id).single()).status==='paid','lost approval not reconciled');
  assert((await call(money,{action:'settle',reservationId:r.id},b)).code===403,'borrower settled');
  const lock=checked(await f.admin.rpc('begin_rental_money_operation',{p_reservation_id:r.id,p_actor:f.borrower.id,p_kind:'refund'}));
  await localSql(`UPDATE public.reservations SET payment_action_started_at=now()-interval '11 minutes' WHERE id='${r.id}';`);
  assert(checked(await f.lender.client.rpc('transition_reservation_status',{p_reservation_id:r.id,p_target:'picked_up'})).ok===false,'stale refund allowed pickup');
  pg.loseNextCancel();assert((await call(money,{action:'refund',reservationId:r.id},b)).code===502,'expected lost refund response');
  await localSql(`UPDATE public.toss_checkouts SET next_attempt_at=now() WHERE reservation_id IN (${ids.map(id=>`'${id}'`).join(',')}); UPDATE public.rental_money_operations SET next_attempt_at=now() WHERE reservation_id IN (${ids.map(id=>`'${id}'`).join(',')});`);
  await call(recovery,{},Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'));
  assert(checked(await f.admin.from('reservations').select('status').eq('id',r.id).single()).status==='cancelled','refund not reconciled');
  assert(pg.cancelIds.length===1&&pg.cancelIds[0]===lock.id,'refund repeated instead of queried');
  assert((await call(money,{action:'refund',reservationId:r.id},b)).code===200,'idempotent refund failed');
  const r2=await f.rental(1);ids.push(r2.id);const prepared=await call(checkout,{action:'prepare',reservationId:r2.id},b);
  const p2=new URLSearchParams(new URL(prepared.data.checkoutUrl).hash.slice(1));
  assert((await call(checkout,{action:'confirm',orderId:p2.get('orderId'),token:p2.get('token'),paymentKey:'qa-'+r2.id,amount:r2.total_paid})).data.status==='paid','second approval failed');
  assert(checked(await f.lender.client.rpc('transition_reservation_status',{p_reservation_id:r2.id,p_target:'picked_up'})).ok,'pickup failed');
  const photoPath=`${r2.id}/${f.borrower.id}/return.png`;
  checked(await f.borrower.client.storage.from('rental-evidence').upload(photoPath,png,{contentType:'image/png'}));
  assert((await f.outsider.client.storage.from('rental-evidence').createSignedUrl(photoPath,60)).error,'outsider accessed evidence');
  checked(await f.borrower.client.rpc('return_rental',{p_reservation_id:r2.id,p_photo_path:photoPath}));
  assert((await call(money,{action:'settle',reservationId:r2.id},l)).data.status==='settled','deposit not settled');
  assert(pg.payments.get(p2.get('orderId')!)?.refunded===30000,'rental fee was refunded');
  const events=checked(await f.admin.from('rental_events').select('command').eq('reservation_id',r2.id));
  assert(events.some(e=>e.command==='pickupRental')&&events.some(e=>e.command==='returnRental')&&events.some(e=>e.command==='settleRental'),'missing custody events');
 } finally {await f.cleanup();}
});

Deno.test('provider mismatch cannot mark paid; terminal failure releases hold; concurrent refund sends once',async()=>{
 const f=await fixture();const pg=fakeProvider();const ids:string[]=[];
 const checkout=checkoutHandler(pg.factory),money=moneyHandler(pg.factory),recovery=recoveryHandler(pg.factory,async()=>ids);
 const call=async(handler:(req:Request)=>Promise<Response>,body:unknown,token?:string)=>{
  const res=await handler(new Request('http://127.0.0.1/test',{method:'POST',headers:{Authorization:`Bearer ${token??f.borrower.session.access_token}`},body:JSON.stringify(body)}));return {code:res.status,data:await res.json()};
 };
 try {
  const r=await f.rental();ids.push(r.id);
  const prepared=await call(checkout,{action:'prepare',reservationId:r.id});
  const params=new URLSearchParams(new URL(prepared.data.checkoutUrl).hash.slice(1));const orderId=params.get('orderId')!;
  pg.payments.set(orderId,{id:'qa-'+r.id,orderId,total:1,refunded:0,currency:'KRW',status:'paid'});
  assert((await call(checkout,{action:'confirm',orderId,token:params.get('token'),paymentKey:'qa-'+r.id,amount:r.total_paid})).code===409,'wrong provider amount accepted');
  assert(checked(await f.admin.from('reservations').select('status').eq('id',r.id).single()).status==='accepted','mismatched payment reached DB');
  const review=checked(await f.admin.from('toss_checkouts').select('review_required_at,last_error_code').eq('order_id',orderId).single());
  assert(review.review_required_at&&review.last_error_code==='PAYMENT_REVIEW_REQUIRED','mismatch not escalated');
  pg.payments.set(orderId,{id:'qa-'+r.id,orderId,total:r.total_paid,refunded:0,currency:'KRW',status:'failed'});
  checked(await f.admin.rpc('retry_rental_recovery',{p_kind:'checkout',p_key:orderId}));
  await localSql(`UPDATE public.toss_checkouts SET next_attempt_at=now() WHERE reservation_id IN (${ids.map(id=>`'${id}'`).join(',')}); UPDATE public.rental_money_operations SET next_attempt_at=now() WHERE reservation_id IN (${ids.map(id=>`'${id}'`).join(',')});`);
  await call(recovery,{},Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'));
  assert(checked(await f.admin.from('reservations').select('status,payment_attempt_merchant_uid').eq('id',r.id).single()).status==='expired','terminal failure did not release inventory');
  const r2=await f.rental(1);ids.push(r2.id);
  const p=await call(checkout,{action:'prepare',reservationId:r2.id});const q=new URLSearchParams(new URL(p.data.checkoutUrl).hash.slice(1));
  assert((await call(checkout,{action:'confirm',orderId:q.get('orderId'),token:q.get('token'),paymentKey:'qa-'+r2.id,amount:r2.total_paid})).data.status==='paid','setup approval failed');
  await Promise.all([call(money,{action:'refund',reservationId:r2.id}),call(money,{action:'refund',reservationId:r2.id})]);
  assert(pg.cancelIds.length===1,'concurrent workers sent duplicate refunds');
  assert(checked(await f.admin.from('reservations').select('status').eq('id',r2.id).single()).status==='cancelled','concurrent refund not completed');
 } finally {await f.cleanup();}
});

Deno.test('checkout polling is read-only and repeated confirmation/recovery cannot bypass backoff',async()=>{
 const f=await fixture();const pg=fakeProvider();let lookups=0,approvals=0;
 const checkout=checkoutHandler(()=>({
  ...pg.factory('toss'),
  async lookupOrder(id){lookups++;return await pg.factory('toss').lookupOrder(id);},
  async confirm(id,orderId,total){approvals++;return await pg.factory('toss').confirm(id,orderId,total);},
 }));
 const call=async(body:unknown)=>{
  const res=await checkout(new Request('http://127.0.0.1/test',{method:'POST',headers:{Authorization:`Bearer ${f.borrower.session.access_token}`},body:JSON.stringify(body)}));
  return {code:res.status,data:await res.json()};
 };
 try {
  const r=await f.rental();
  const prepared=await call({action:'prepare',reservationId:r.id});
  const q=new URLSearchParams(new URL(prepared.data.checkoutUrl).hash.slice(1));
  const orderId=q.get('orderId'),token=q.get('token');
  const confirm={action:'confirm',orderId,token,paymentKey:'qa-'+r.id,amount:r.total_paid};
  pg.loseNextApproval();
  assert((await call(confirm)).code===502,'approval response should be unknown');
  assert(lookups===1&&approvals===1,'unexpected first provider calls');
  const polls=await Promise.all(Array.from({length:4},()=>call({action:'status',orderId,token})));
  assert(polls.every(p=>p.data.status==='processing'&&p.data.recoveryState==='retry_scheduled'),'retry state missing');
  const retries=await Promise.all([call(confirm),call({action:'recover',reservationId:r.id})]);
  assert(retries.every(p=>p.data.status==='processing'),'early retry did not remain pending');
  assert(lookups===1&&approvals===1,'status or repeated key bypassed backoff');
  await localSql(`UPDATE public.toss_checkouts SET next_attempt_at=now()-interval '1 second' WHERE reservation_id='${r.id}';`);
  // Polling stays read-only even when work is due; a worker/recover command owns reconciliation.
  await call({action:'status',orderId,token});
  assert(lookups===1,'due status poll contacted provider');
  assert((await call({action:'recover',reservationId:r.id})).data.status==='paid','due recovery did not reconcile approval');
  assert(Number(lookups)===2&&approvals===1,'recovery repeated approval');
  const payment=pg.payments.get(orderId!)!;
  payment.status='cancelled';payment.refunded=payment.total;
  // Paid-state external cancellation has a separate reconciliation policy.
  // Replaying confirmation must neither report an invented expiry nor call PG.
  assert((await call(confirm)).data.status==='paid','completed approval replay reported false expiry');
  assert(Number(lookups)===2&&approvals===1,'completed approval replay contacted provider');
 } finally {await f.cleanup();}
});
