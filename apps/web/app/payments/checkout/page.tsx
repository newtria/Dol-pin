'use client';
import {useEffect,useState,useRef} from 'react';
import {Button} from '@/components/ui/button';
import {Failure} from '@/lib/feedback';
type Checkout = {orderId:string;amount:number;customerKey:string;reservationId:string;mobile:boolean};
async function call(body: Record<string,unknown>) {
 const result = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/toss-payment`,{method:'POST',headers:{'Content-Type':'application/json',apikey:process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!},body:JSON.stringify(body)});
 const data = await result.json(); if(!result.ok || data.error) throw new Error(data.error ?? '결제 요청에 실패했습니다.'); return data;
}
export default function CheckoutPage() {
 const started=useRef(false);
 const [checkout,setCheckout]=useState<Checkout>(); const [error,setError]=useState<unknown>();
 const [busy,setBusy]=useState(false); const [paid,setPaid]=useState(false); const [returning,setReturning]=useState(false);
 useEffect(()=>{
  if(started.current) return; started.current=true;
  const fragment=new URLSearchParams(location.hash.slice(1)); const query=new URLSearchParams(location.search);
  const orderId=fragment.get('orderId')??query.get('orderId')??sessionStorage.getItem('toss-order');
  const token=fragment.get('token');
  if(token && orderId) {sessionStorage.setItem(`toss-${orderId}`,token);sessionStorage.setItem('toss-order',orderId);history.replaceState(null,'',location.pathname);}
  if(query.has('paymentKey')) {setReturning(true);void confirm();return;}
  if(query.has('code')) setError(new Error(query.get('message')??'결제가 취소되었습니다.'));
  if(!orderId) {setError(new Error('거래 상세에서 결제를 시작해 주세요.'));return;}
  void call({action:'checkout',orderId,token:sessionStorage.getItem(`toss-${orderId}`)}).then(setCheckout).catch(setError);
 },[]);
 async function pay() {
  setBusy(true);setError(undefined);
  try {
   const key=process.env.NEXT_PUBLIC_TOSS_CLIENT_KEY; if(!key) throw new Error('토스 클라이언트 키를 설정해 주세요.');
   const {loadTossPayments}=await import('@tosspayments/tosspayments-sdk');
   const toss=await loadTossPayments(key);
   const base=`${location.origin}/payments/checkout`;
   await toss.payment({customerKey:checkout!.customerKey}).requestPayment({method:'CARD',amount:{currency:'KRW',value:checkout!.amount},orderId:checkout!.orderId,orderName:'돌핀 대여료 및 보증금',successUrl:base,failUrl:base});
  } catch(e) {setError(e);} finally {setBusy(false);}
 }
 async function confirm() {
  setBusy(true);setError(undefined);
  try {
   const query=new URLSearchParams(location.search); const orderId=query.get('orderId');
   const result=await call({action:'confirm',orderId,token:sessionStorage.getItem(`toss-${orderId}`),paymentKey:query.get('paymentKey'),amount:Number(query.get('amount'))});
   setCheckout(result);setPaid(true);history.replaceState(null,'',location.pathname);
   sessionStorage.removeItem(`toss-${orderId}`);sessionStorage.removeItem('toss-order');
  } catch(e) {setError(e);} finally {setBusy(false);}
 }
 return <section className="mx-auto flex max-w-md flex-col gap-6"><h1 className="text-3xl font-bold">{paid?'결제 완료':'예약 결제'}</h1><Failure error={error}/>
 {paid ? <><p>예약에 결제가 반영되었습니다.</p><a href={checkout?.mobile?`dolpin://payments/return?id=${checkout.reservationId}`:`/rentals/${checkout?.reservationId}`}>거래로 돌아가기</a></> : returning ? <><p>결제 결과를 확인하고 있습니다. 오류가 발생하면 다시 확인해 주세요.</p><Button onClick={confirm} disabled={busy}>{busy?'확인 중…':'결제 결과 다시 확인'}</Button></> : checkout ? <><p>대여료 및 보증금 {checkout.amount.toLocaleString('ko-KR')}원</p><Button onClick={pay} disabled={busy}>토스페이먼츠로 결제</Button></> : !error ? <p>결제 정보를 불러오고 있습니다.</p> : null}</section>;
}
