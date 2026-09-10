import {tossProvider} from './payment-provider.ts';
function assert(v:unknown,message:string){if(!v)throw new Error(message);}
Deno.test('Toss adapter uses authoritative cancel amount, balance guard, operation key and terminal status mapping',async()=>{
 Deno.env.set('TOSS_SECRET_KEY','test_sk_fixture');const original=globalThis.fetch;let status='PARTIAL_CANCELED';
 globalThis.fetch=async(_input,init)=>{
  if(init?.method==='POST') {
   const body=JSON.parse(String(init.body));assert(body.cancelAmount===30000&&body.refundableAmount===35000,'unsafe cancellation amounts');
   assert(new Headers(init.headers).get('Idempotency-Key')==='operation-1','missing stable key');
  }
  return Response.json({paymentKey:'payment',orderId:'order',totalAmount:35000,balanceAmount:status==='PARTIAL_CANCELED'?5000:35000,currency:'KRW',status});
 };
 try {
  const provider=tossProvider();const p=await provider.cancel('payment',30000,35000,'operation-1');assert(p.refunded===30000,'incorrect refunded amount');
  status='ABORTED';assert((await provider.lookup('payment')).status==='failed','failed approval not terminal');
  status='EXPIRED';assert((await provider.lookup('payment')).status==='failed','expired approval not terminal');
  globalThis.fetch=async()=>Response.json({}, {status:404});assert(await provider.lookupOrder('missing')===null,'not-found lookup ambiguous');
  globalThis.fetch=async()=>Response.json({}, {status:503});let rejected=false;try{await provider.lookupOrder('unknown');}catch{rejected=true;}assert(rejected,'provider outage treated as unpaid');
 } finally {globalThis.fetch=original;}
});

Deno.test('PortOne adapter keeps its provider identity and partial cancellation contract',async()=>{
 const {paymentProvider}=await import('./payment-provider.ts');
 const original=globalThis.fetch;let called=false;
 globalThis.fetch=async(input,init)=>{
  const url=String(input);assert(url.startsWith('https://api.iamport.kr/'),'wrong provider called');
  if(url.endsWith('/users/getToken'))return Response.json({code:0,response:{access_token:'fixture-token',expired_at:Date.now()/1000+3600}});
  if(url.endsWith('/payments/cancel')){const body=JSON.parse(String(init?.body));assert(body.imp_uid==='imp_fixture'&&body.amount===30000,'wrong PortOne refund');called=true;}
  return Response.json({code:0,response:{imp_uid:'imp_fixture',merchant_uid:'dolpin_reservation_attempt',amount:35000,cancel_amount:called?30000:0,currency:'KRW',status:'paid'}});
 };
 try {
  const provider=paymentProvider('portone');assert((await provider.lookup('imp_fixture')).orderId==='reservation','order binding lost');
  assert((await provider.cancel('imp_fixture',30000,35000,'op')).refunded===30000,'partial amount lost');
 } finally {globalThis.fetch=original;}
});
