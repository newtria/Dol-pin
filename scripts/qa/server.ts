// Test-only, loopback-bound gateway. It runs the production handlers against
// real local Auth/DB/Storage, replacing only the payment provider boundary.
import {fixture,localAdmin,fakeProvider,checked,localSql} from './fixture.ts';
import {createHandler as checkoutHandler} from '../../supabase/functions/toss-payment/index.ts';
import {createHandler as moneyHandler} from '../../supabase/functions/rental-payment/index.ts';
import {createHandler as recoveryHandler} from '../../supabase/functions/rental-recovery/index.ts';
import {createHandler as financeHandler} from '../../supabase/functions/finance-ops/index.ts';
localAdmin();
const pg=fakeProvider();const checkout=checkoutHandler(pg.factory),money=moneyHandler(pg.factory),recovery=recoveryHandler(pg.factory,async()=>{
 const items=[...fixtures.values()].map(f=>f.item.id);
 if(!items.length)return [];
 return checked(await localAdmin().from('reservations').select('id').in('item_id',items)).map(r=>r.id);
});
const fixtures=new Map<string,Awaited<ReturnType<typeof fixture>>>();
const finance=financeHandler(pg.factory);
async function commercialCall(handler:(req:Request)=>Promise<Response>,token:string,body:Record<string,unknown>){
 const response=await handler(new Request('http://127.0.0.1/qa-commercial',{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify(body)}));
 if(!response.ok)throw new Error(`Commercial fixture request failed (${response.status})`);
 return response.json();
}
Deno.serve({hostname:'127.0.0.1',port:55325},async req=>{
 const url=new URL(req.url);
 try {
  if(url.pathname.startsWith('/__qa/')) {
   // Browser pages cannot reach the control surface cross-origin.
   if(req.headers.has('Origin'))return new Response('Forbidden',{status:403});
   if(url.pathname==='/__qa/health')return Response.json({ok:true});
   if(url.pathname==='/__qa/seed'&&req.method==='POST') {
    const f=await fixture();fixtures.set(f.tag,f);
    return Response.json({tag:f.tag,item:f.item,lender:f.lender.session,borrower:f.borrower.session,outsider:f.outsider.session});
   }
   if(url.pathname==='/__qa/profile-preferences'&&req.method==='POST'){
    const {tag,initialize}=await req.json();const f=fixtures.get(tag);if(!f)return new Response('Missing fixture',{status:404});
    if(initialize===true)checked(await f.borrower.client.rpc('update_my_profile',{p_nickname:'QA borrower',p_region:'서울',p_update_region:true,p_locale:'ja'}));
    return Response.json(checked(await f.borrower.client.from('users').select('nickname,region,locale').eq('id',f.borrower.id).single()));
   }
   if(url.pathname==='/__qa/answer-support'&&req.method==='POST'){
    const {tag}=await req.json();const f=fixtures.get(tag);if(!f)return new Response('Missing fixture',{status:404});
    const report=checked(await f.admin.from('reports').select('id').eq('reporter_id',f.borrower.id).eq('status','pending').is('reservation_id',null).single());
    checked(await f.admin.auth.admin.updateUserById(f.outsider.id,{app_metadata:{dolpin_operator:true}}));
    const answer='기기 설정에서 거래 알림 권한을 확인해 주세요. 계정의 알림 메뉴에서 다시 등록할 수 있습니다.';
    checked(await f.admin.rpc('moderate_service',{p_actor:f.outsider.id,p_action:'resolved',p_target:report.id,p_reason:answer}));
    return Response.json({answer});
   }
   if(url.pathname==='/__qa/resolved-rental'&&req.method==='POST'){
    const {tag}=await req.json();const f=fixtures.get(tag);if(!f)return new Response('Missing fixture',{status:404});
    const rental=await f.rental();
    const prepared=await commercialCall(checkout,f.borrower.session.access_token,{action:'prepare',reservationId:rental.id});
    const params=new URLSearchParams(new URL(prepared.checkoutUrl).hash.slice(1));
    const paid=await commercialCall(checkout,f.borrower.session.access_token,{action:'confirm',orderId:params.get('orderId'),token:params.get('token'),paymentKey:`qa-${rental.id}`,amount:rental.total_paid});
    if(paid.status!=='paid')throw new Error('Commercial fixture payment incomplete');
    checked(await f.borrower.client.rpc('open_rental_dispute',{p_reservation_id:rental.id,p_reason:'물품 전달이 늦어 일부 이용 기간에 대한 환불을 요청합니다.',p_evidence_paths:[]}));
    checked(await f.admin.auth.admin.updateUserById(f.outsider.id,{app_metadata:{dolpin_operator:true}}));
    const refundAmount=32000,reason='양측 메시지와 인수 지연 시간을 대조하여 부분 환불을 결정했습니다.';
    await commercialCall(finance,f.outsider.session.access_token,{action:'resolveDispute',reservationId:rental.id,refundAmount,reason});
    const resolved=checked(await f.borrower.client.from('reservations').select('status').eq('id',rental.id).single());
    if(resolved.status!=='resolved')throw new Error('Commercial fixture dispute incomplete');
    return Response.json({reservationId:rental.id,refundAmount,reason});
   }
   if(url.pathname==='/__qa/lose-approval'&&req.method==='POST'){pg.loseNextApproval();return Response.json({ok:true});}
   if(url.pathname==='/__qa/lose-cancel'&&req.method==='POST'){pg.loseNextCancel();return Response.json({ok:true});}
   if(url.pathname==='/__qa/recover'&&req.method==='POST')return recovery(new Request('http://127.0.0.1/recovery',{method:'POST',headers:{Authorization:`Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`}}));
   if(url.pathname==='/__qa/recovery-due'&&req.method==='POST') {
    const {tag}=await req.json();const f=fixtures.get(tag);if(!f)return new Response('Missing fixture',{status:404});
    // Only this isolated QA fixture's clock is advanced. The browser itself
    // must never bypass production retry due times or invoke a payment lookup.
    await localSql(`UPDATE public.toss_checkouts SET next_attempt_at=now()-interval '1 second' WHERE reservation_id IN (SELECT id FROM public.reservations WHERE item_id='${f.item.id}');`);
    return recovery(new Request('http://127.0.0.1/recovery',{method:'POST',headers:{Authorization:`Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`}}));
   }
   if(url.pathname==='/__qa/review-checkout'&&req.method==='POST') {
    const {tag}=await req.json();const f=fixtures.get(tag);if(!f)return new Response('Missing fixture',{status:404});
    await localSql(`UPDATE public.toss_checkouts SET review_required_at=now() WHERE reservation_id IN (SELECT id FROM public.reservations WHERE item_id='${f.item.id}');`);
    return Response.json({ok:true});
   }
   if(url.pathname==='/__qa/cleanup'&&req.method==='POST') {
    const {tag}=await req.json();const f=fixtures.get(tag);if(f){await f.cleanup();fixtures.delete(tag);}return Response.json({ok:true});
   }
   if(url.pathname==='/__qa/expire-checkout'&&req.method==='POST') {
    const {tag}=await req.json();const f=fixtures.get(tag);if(!f)return new Response('Missing fixture',{status:404});
    await localSql(`UPDATE public.toss_checkouts SET expires_at=now()-interval '1 minute' WHERE reservation_id IN (SELECT id FROM public.reservations WHERE item_id='${f.item.id}');`);
    return Response.json({ok:true});
   }
   if(url.pathname==='/__qa/catalog'&&req.method==='POST') {
    const {tag}=await req.json();const f=fixtures.get(tag);if(!f)return new Response('Missing fixture',{status:404});
    checked(await f.lender.client.from('rental_items').insert(Array.from({length:52},(_,i)=>({lender_id:f.lender.id,title:`${tag} page ${String(i).padStart(2,'0')}`,category:'lightstick',photos:f.item.photos,daily_price:5000,deposit:30000,currency:'KRW',pickup_method:'direct'}))));
    const concerts=Array.from({length:54},(_,i)=>({id:crypto.randomUUID(),title:`${tag} concert ${i}`,offset:i===0?-1:i}));
    f.concertIds.push(...concerts.map(c=>c.id));
    await localSql(`INSERT INTO public.concerts(id,title,artist,venue,city,country,concert_date) VALUES ${concerts.map(c=>`('${c.id}','${c.title}','QA artist','QA venue','Seoul','KR',CURRENT_DATE+${c.offset})`).join(',')};`);
    return Response.json({ok:true});
   }
   return new Response('Not found' ,{status:404});
  }
  if(url.pathname==='/functions/v1/toss-payment')return checkout(req);
  if(url.pathname==='/functions/v1/rental-payment')return money(req);
  if(url.pathname==='/functions/v1/rental-recovery')return recovery(req);
  const target=new URL(url.pathname+url.search,Deno.env.get('SUPABASE_URL'));
  return fetch(new Request(target,req));
 } catch(e) {console.error(e instanceof Error?e.message:typeof e==='object'&&e&&'message' in e?String(e.message):'QA request failed');return Response.json({error:'QA request failed'},{status:500});}
});
