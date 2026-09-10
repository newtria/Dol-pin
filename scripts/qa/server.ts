// Test-only, loopback-bound gateway. It runs the production handlers against
// real local Auth/DB/Storage, replacing only the payment provider boundary.
import {fixture,localAdmin,fakeProvider,checked,localSql} from './fixture.ts';
import {createHandler as checkoutHandler} from '../../supabase/functions/toss-payment/index.ts';
import {createHandler as moneyHandler} from '../../supabase/functions/rental-payment/index.ts';
import {createHandler as recoveryHandler} from '../../supabase/functions/rental-recovery/index.ts';
localAdmin();
const pg=fakeProvider();const checkout=checkoutHandler(pg.factory),money=moneyHandler(pg.factory),recovery=recoveryHandler(pg.factory,async()=>{
 const items=[...fixtures.values()].map(f=>f.item.id);
 if(!items.length)return [];
 return checked(await localAdmin().from('reservations').select('id').in('item_id',items)).map(r=>r.id);
});
const fixtures=new Map<string,Awaited<ReturnType<typeof fixture>>>();
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
   if(url.pathname==='/__qa/lose-approval'&&req.method==='POST'){pg.loseNextApproval();return Response.json({ok:true});}
   if(url.pathname==='/__qa/lose-cancel'&&req.method==='POST'){pg.loseNextCancel();return Response.json({ok:true});}
   if(url.pathname==='/__qa/recover'&&req.method==='POST')return recovery(new Request('http://127.0.0.1/recovery',{method:'POST',headers:{Authorization:`Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`}}));
   if(url.pathname==='/__qa/cleanup'&&req.method==='POST') {
    const {tag}=await req.json();const f=fixtures.get(tag);if(f){await f.cleanup();fixtures.delete(tag);}return Response.json({ok:true});
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
