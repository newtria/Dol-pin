// Provider boundary tests; no live charge or real credential is used.
Deno.env.set('SUPABASE_URL','https://supabase.invalid');
Deno.env.set('SUPABASE_SERVICE_ROLE_KEY','fixture');
Deno.env.set('TOSS_SECRET_KEY','test_sk_fixture');
Deno.env.set('DOLPIN_WEB_URL','https://web.invalid');
const {handleRequest} = await import('./index.ts');
const checkout={order_id:'dolpin_fixture',token_hash:'hash',reservation_id:'rental',amount:35000,mobile:false};
function assert(value:unknown,message:string) {if(!value) throw new Error(message);}
Deno.test('Toss rejects tampered amount before approval, reconciles retries, and checks provider identity',async()=>{
 const original=globalThis.fetch; let scenario='amount'; const calls:string[]=[];
 globalThis.fetch=async(input,init)=>{
  const url=String(input); calls.push(url);
  if(url.includes('/rest/v1/toss_checkouts')) return Response.json(scenario==='unauthorized'?null:checkout);
  if(url.includes('/rpc/')) return Response.json(null);
  if(url.includes('/v1/payments/orders/')) {
   if(scenario==='new') return Response.json({code:'NOT_FOUND_PAYMENT'},{status:404});
   return Response.json({status:'DONE',orderId:checkout.order_id,paymentKey:scenario==='wrong'?'other':'key',totalAmount:35000,currency:'KRW'});
  }
  if(url.endsWith('/v1/payments/confirm')) {
   const sent=JSON.parse(String(init?.body));
   assert(sent.amount===35000 && new Headers(init?.headers).get('Idempotency-Key')===checkout.order_id,'unsafe confirmation request');
   return Response.json({status:'DONE',...sent,totalAmount:sent.amount,currency:'KRW'});
  }
  throw new Error(`Unexpected URL: ${url}`);
 };
 const request=(amount:number)=>new Request('https://function.invalid',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'confirm',orderId:checkout.order_id,token:'fixture',paymentKey:'key',amount})});
 try {
  assert((await handleRequest(request(1))).status===400,'tampered amount accepted');
  assert(!calls.some(url=>url.includes('tosspayments.com')),'provider called for tampered amount');
  scenario='unauthorized';calls.length=0;
  assert((await handleRequest(request(35000))).status===403,'invalid capability accepted');
  assert(!calls.some(url=>url.includes('tosspayments.com')),'provider called for invalid capability');
  scenario='new';calls.length=0;
  assert((await handleRequest(request(35000))).status===200,'approval failed');
  assert(calls.some(url=>url.endsWith('/v1/payments/confirm')),'approval missing');
  scenario='retry';calls.length=0;
  assert((await handleRequest(request(35000))).status===200,'retry failed');
  assert(!calls.some(url=>url.endsWith('/v1/payments/confirm')),'already paid order approved again');
  scenario='wrong';calls.length=0;
  assert((await handleRequest(request(35000))).status===409,'mismatched provider payment accepted');
  assert(!calls.some(url=>url.includes('finish_toss_confirmation')),'mismatched payment reached DB');
 } finally {globalThis.fetch=original;}
});
