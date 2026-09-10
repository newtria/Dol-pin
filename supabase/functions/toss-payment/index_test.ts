import {createHandler} from './index.ts';
import {fakeProvider} from '../../../scripts/qa/fixture.ts';
Deno.test('checkout capability and authoritative amount are checked before provider calls',async()=>{
 Deno.env.set('SUPABASE_URL','https://supabase.invalid');Deno.env.set('SUPABASE_SERVICE_ROLE_KEY','fixture');
 const original=globalThis.fetch;let valid=true;const pg=fakeProvider();const handler=createHandler(pg.factory);
 globalThis.fetch=async(input)=>{
  const url=input instanceof Request?input.url:String(input);
  if(url.includes('toss_checkout_sessions'))return Response.json(valid?{mobile:false,expires_at:'2099-01-01'}:null);
  if(url.includes('toss_checkouts'))return Response.json({order_id:'order',amount:35000});
  throw new Error('Unexpected request: '+url);
 };
 const req=(amount:number)=>new Request('https://function.invalid',{method:'POST',body:JSON.stringify({action:'confirm',orderId:'order',token:'fixture',paymentKey:'key',amount})});
 try {
  if((await handler(req(1))).status!==400)throw new Error('tampered amount allowed');
  valid=false;if((await handler(req(35000))).status!==403)throw new Error('invalid capability allowed');
  if(pg.payments.size)throw new Error('provider called before authorization');
 } finally {globalThis.fetch=original;}
});
