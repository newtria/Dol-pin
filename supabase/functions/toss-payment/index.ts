import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {requireAuthenticatedUser} from '../_shared/auth.ts';
import {jsonResponse, optionsResponse, parseJsonBody} from '../_shared/http.ts';
const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const hash = async (text: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text))),b=>b.toString(16).padStart(2,'0')).join('');
export async function handleRequest(req: Request): Promise<Response> {
 if(req.method==='OPTIONS') return optionsResponse();
 if(req.method!=='POST') return jsonResponse(405,{error:'Method not allowed'});
 const body = await parseJsonBody<Record<string,unknown>>(req); if(body instanceof Response) return body;
 const admin = createClient(url,serviceKey);
 try {
  const secret = Deno.env.get('TOSS_SECRET_KEY');
  const origin = Deno.env.get('DOLPIN_WEB_URL');
  if(!secret || !origin) return jsonResponse(503,{error:'토스 결제 서버 설정이 필요합니다.'});
  if(body.action==='prepare') {
   const caller = await requireAuthenticatedUser(req,url,serviceKey); if(caller instanceof Response) return caller;
   if(typeof body.reservationId!=='string') return jsonResponse(400,{error:'예약 번호가 필요합니다.'});
   const token = crypto.randomUUID()+crypto.randomUUID();
   const {data,error} = await admin.rpc('prepare_toss_checkout',{p_reservation_id:body.reservationId,p_actor:caller.id,p_token_hash:await hash(token),p_mobile:body.mobile===true});
   if(error) return jsonResponse(409,{error:error.message});
   return jsonResponse(200,{checkoutUrl:`${new URL('/payments/checkout',origin)}#token=${token}&orderId=${data.order_id}`});
  }
  if(!['checkout','confirm'].includes(String(body.action)) || typeof body.token!=='string' || typeof body.orderId!=='string') return jsonResponse(400,{error:'잘못된 결제 요청입니다.'});
  const {data:c,error} = await admin.from('toss_checkouts').select('*').eq('order_id',body.orderId).eq('token_hash',await hash(body.token)).maybeSingle();
  if(error || !c) return jsonResponse(403,{error:'결제 링크가 유효하지 않습니다. 앱에서 다시 열어 주세요.'});
  if(body.action==='checkout') {
   if(new Date(c.expires_at).getTime()<=Date.now()) return jsonResponse(410,{error:'결제 기한이 지났습니다.'});
   return jsonResponse(200,{orderId:c.order_id,amount:c.amount,customerKey:c.customer_key,mobile:c.mobile,reservationId:c.reservation_id});
  }
  if(typeof body.paymentKey!=='string' || !body.paymentKey || body.amount!==c.amount) return jsonResponse(400,{error:'결제 금액 또는 승인 정보가 일치하지 않습니다.'});
  const {error:beginError} = await admin.rpc('begin_toss_confirmation',{p_order_id:c.order_id});
  if(beginError) return jsonResponse(409,{error:beginError.message});
  const headers = {Authorization:`Basic ${btoa(secret+':')}`,'Content-Type':'application/json'};
  // Query first to recover an earlier approval even after idempotency retention.
  const lookup = await fetch(`https://api.tosspayments.com/v1/payments/orders/${encodeURIComponent(c.order_id)}`,{headers});
  let payment = await lookup.json();
  if(!lookup.ok && lookup.status!==404) return jsonResponse(502,{error:'결제 상태 조회에 실패했습니다. 다시 확인해 주세요.'});
  if(!lookup.ok || payment.status==='READY' || payment.status==='IN_PROGRESS') {
   const result = await fetch('https://api.tosspayments.com/v1/payments/confirm',{method:'POST',headers:{...headers,'Idempotency-Key':c.order_id},body:JSON.stringify({paymentKey:body.paymentKey,orderId:c.order_id,amount:c.amount})});
   payment = await result.json();
   if(!result.ok) return jsonResponse(502,{error:payment.message??'결제 승인 상태를 다시 확인해 주세요.'});
  }
  if(payment.status!=='DONE' || payment.orderId!==c.order_id || payment.paymentKey!==body.paymentKey || payment.totalAmount!==c.amount || payment.currency!=='KRW') return jsonResponse(409,{error:'토스 결제 결과가 예약과 일치하지 않습니다.'});
  const {error:finishError} = await admin.rpc('finish_toss_confirmation',{p_order_id:c.order_id,p_payment_key:body.paymentKey});
  if(finishError) return jsonResponse(503,{error:'승인은 확인했지만 예약 반영을 재시도해야 합니다. 다시 확인해 주세요.'});
  return jsonResponse(200,{reservationId:c.reservation_id,mobile:c.mobile,status:'paid'});
 } catch {return jsonResponse(502,{error:'결제 상태를 확인하지 못했습니다. 같은 화면에서 다시 확인해 주세요.'});}
}
if (import.meta.main) Deno.serve(handleRequest);
