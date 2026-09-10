import type {SupabaseClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {paymentProvider, type ProviderFactory, type Payment} from './payment-provider.ts';

export async function rpc<T=unknown>(admin:SupabaseClient,name:string,args:Record<string,unknown>):Promise<T> {
 const {data,error}=await admin.rpc(name,args);if(error)throw new Error(error.message);return data as T;
}
function identity(p:Payment,id:string,total:number,orderId?:string) {
 if(p.id!==id || p.total!==total || p.currency!=='KRW' || (orderId && p.orderId!==orderId))
 throw new Error('결제사 결과와 거래 정보가 일치하지 않습니다.');
}
export async function reconcileCheckout(admin:SupabaseClient,orderId:string,paymentKey?:string,providers:ProviderFactory=paymentProvider) {
 const lease=crypto.randomUUID();
 const claimed=await rpc<boolean>(admin,'claim_toss_confirmation',{p_order_id:orderId,p_lease:lease,p_payment_key:paymentKey??null});
 if(!claimed) return {status:'processing'};
 try {
  const {data:c,error}=await admin.from('toss_checkouts').select('*').eq('order_id',orderId).single();
  if(error)throw error;
  const provider=providers('toss');
  let p=await provider.lookupOrder(orderId);
  // Only a current browser confirmation may initiate approval; workers only look up.
  if(paymentKey && (!p || p.status==='unpaid') && Date.now()<Date.parse(c.expires_at))
   p=await provider.confirm(paymentKey,orderId,c.amount);
  if(!p) {
   if(!c.payment_key && Date.now()>=Date.parse(c.expires_at)) {
    await rpc(admin,'fail_toss_confirmation',{p_order_id:orderId});
    return {status:'expired',reservationId:c.reservation_id};
   }
   return {status:'processing',reservationId:c.reservation_id};
  }
  identity(p,c.payment_key??p.id,c.amount,orderId);
  if(p.status==='paid' && p.refunded===0) {
   await rpc(admin,'begin_toss_confirmation',{p_order_id:orderId});
   await rpc(admin,'finish_toss_confirmation',{p_order_id:orderId,p_payment_key:p.id});
   return {status:'paid',reservationId:c.reservation_id};
  }
  if(p.status==='failed' || p.status==='cancelled') {
   await rpc(admin,'fail_toss_confirmation',{p_order_id:orderId});
   return {status:'expired',reservationId:c.reservation_id};
  }
  return {status:'processing',reservationId:c.reservation_id};
 } finally {await rpc(admin,'release_toss_confirmation',{p_order_id:orderId,p_lease:lease});}
}

type Operation={id:string;reservation_id:string;provider:string;payment_id:string;amount:number;total:number;kind:'refund'|'settle';dispatched_at:string|null};
export async function reconcileMoney(admin:SupabaseClient,id:string,providers:ProviderFactory=paymentProvider) {
 const lease=crypto.randomUUID();
 const op=await rpc<Operation|null>(admin,'claim_rental_money_operation',{p_id:id,p_lease:lease});
 if(!op?.id)return {status:'processing'};
 try {
  if(op.amount>0) {
   const provider=providers(op.provider);
   let p=await provider.lookup(op.payment_id);
   const orderId=op.provider==='toss'?`dolpin_${op.reservation_id.replaceAll('-','')}`:op.reservation_id;
   identity(p,op.payment_id,op.total,orderId);
   if(p.refunded!==op.amount) {
    if(p.refunded!==0 || p.status!=='paid')throw new Error('예상하지 못한 환불 금액입니다. 운영 확인이 필요합니다.');
    // PortOne V1 has no operation idempotency contract. Unknown requests are
    // reconciled by lookup only. Toss retries stay inside its retention window.
    if(op.dispatched_at && (op.provider!=='toss' || Date.now()-Date.parse(op.dispatched_at)>14*86400000))
     return {status:'processing',reservationId:op.reservation_id};
    const valid=await rpc<boolean>(admin,'dispatch_rental_money_operation',{p_id:id,p_lease:lease});
    if(!valid)return {status:'processing'};
    p=await provider.cancel(op.payment_id,op.amount,op.total,op.id);
    identity(p,op.payment_id,op.total,orderId);
    if(p.refunded!==op.amount)throw new Error('환불 결과를 다시 확인해야 합니다.');
   }
  }
  await rpc(admin,'finish_rental_money_operation',{p_id:id,p_lease:lease});
  return {status:op.kind==='refund'?'cancelled':'settled',reservationId:op.reservation_id};
 } finally {await rpc(admin,'release_rental_money_operation',{p_id:id,p_lease:lease});}
}
