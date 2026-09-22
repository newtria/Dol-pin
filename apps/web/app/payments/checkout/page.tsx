'use client';
import {useEffect,useState} from 'react';
import {Button} from '@/components/ui/button';
import {Failure} from '@/lib/feedback';
import {formatKoreaTime} from '@dolpin/contracts';
type Checkout={orderId:string;amount:number;customerKey:string;reservationId:string;mobile:boolean;canPay:boolean;recovering:boolean;status:string};
type Phase='loading'|'ready'|'processing'|'needs_review'|'paid'|'expired'|'unavailable';
async function call(body:Record<string,unknown>) {
 const response=await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/toss-payment`,{method:'POST',headers:{'Content-Type':'application/json',apikey:process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
 const data=await response.json();if(!response.ok||data.error)throw new Error('결제 정보를 확인하지 못했습니다.');return data;
}
export default function CheckoutPage(){
 const [checkout,setCheckout]=useState<Checkout>();const [phase,setPhase]=useState<Phase>('loading');
 const [error,setError]=useState<unknown>();const [busy,setBusy]=useState(false);const [connectionLost,setConnectionLost]=useState(false);
 const [nextRetryAt,setNextRetryAt]=useState<string|null>(null);
 useEffect(()=>{
  let active=true,timer:ReturnType<typeof setTimeout>|undefined;
  const fragment=new URLSearchParams(location.hash.slice(1)),query=new URLSearchParams(location.search);
  const orderId=fragment.get('orderId')??query.get('orderId')??sessionStorage.getItem('toss-order');
  const token=fragment.get('token')??sessionStorage.getItem(`toss-${orderId}`);
  if(fragment.has('token')&&orderId&&token){sessionStorage.setItem(`toss-${orderId}`,token);sessionStorage.setItem('toss-order',orderId);history.replaceState(null,'',location.pathname);}
  async function poll(){
   if(!active)return;
   if(document.visibilityState==='hidden'){timer=setTimeout(poll,5000);return;}
   try{const result=await call({action:'status',orderId,token});if(!active)return;setConnectionLost(false);if(apply(result.status,result.recoveryState,result.nextRetryAt))return;}
   catch{if(active)setConnectionLost(true);}
   if(active)timer=setTimeout(poll,5000);
  }
  function apply(status:string,recoveryState?:string,nextRetry?:string|null){
   if(!active)return true;
   if(status==='paid'){setPhase('paid');history.replaceState(null,'',location.pathname);return true;}
   if(['expired','cancelled','rejected'].includes(status)){setPhase('expired');return true;}
   if(!['accepted','processing'].includes(status)){setPhase('unavailable');return true;}
   if(recoveryState==='needs_review'){setPhase('needs_review');setNextRetryAt(null);return true;}
   setNextRetryAt(recoveryState==='retry_scheduled'&&nextRetry?nextRetry:null);
   setPhase('processing');return false;
  }
  async function start(){
   if(!orderId||!token){setPhase('unavailable');setError(new Error('결제 링크를 확인할 수 없습니다. 거래 상세에서 결제 결과를 확인하거나 결제를 시작해 주세요.'));return;}
   try{
    const c:Checkout=await call({action:'checkout',orderId,token});if(!active)return;setCheckout(c);
    if(c.status==='paid'){apply('paid');return;}
    if(query.has('paymentKey')){
     setPhase('processing');
     try{const result=await call({action:'confirm',orderId,token,paymentKey:query.get('paymentKey'),amount:Number(query.get('amount'))});if(apply(result.status))return;}
     catch{if(active)setConnectionLost(true);}
     if(active)timer=setTimeout(poll,5000);return;
    }
    if(c.recovering){setPhase('processing');timer=setTimeout(poll,5000);return;}
    if(c.status!=='accepted'){setPhase('unavailable');return;}
    if(!c.canPay){setPhase('expired');return;}
    setPhase('ready');if(query.has('code'))setError(new Error('결제가 완료되지 않았습니다. 다시 결제하거나 거래로 돌아갈 수 있습니다.'));
   }catch{if(active){setPhase('unavailable');setError(new Error('결제 정보를 불러오지 못했습니다. 거래 상세에서 결과를 확인해 주세요.'));}}
  }
  void start();return ()=>{active=false;clearTimeout(timer);};
 },[]);
 async function pay(){
  setBusy(true);setError(undefined);
  try{
   const key=process.env.NEXT_PUBLIC_TOSS_CLIENT_KEY;if(!key)throw new Error('지금은 결제를 시작할 수 없습니다. 잠시 후 거래 상세에서 다시 시도해 주세요.');
   const {loadTossPayments}=await import('@tosspayments/tosspayments-sdk');const toss=await loadTossPayments(key);const base=`${location.origin}/payments/checkout`;
   await toss.payment({customerKey:checkout!.customerKey}).requestPayment({method:'CARD',amount:{currency:'KRW',value:checkout!.amount},orderId:checkout!.orderId,orderName:'돌핀 대여료 및 보증금',successUrl:base,failUrl:base});
  }catch{setError(new Error('결제가 완료되지 않았습니다. 다시 시도하거나 거래로 돌아가 주세요.'));}finally{setBusy(false);}
 }
 const back=checkout?(checkout.mobile?`dolpin://payments/return?id=${checkout.reservationId}`:`/rentals/${checkout.reservationId}`):'/rentals';
 return <section className="mx-auto flex max-w-md flex-col gap-6"><h1 className="text-3xl font-bold">{phase==='paid'?'결제 완료':phase==='needs_review'?'결제 처리에 운영 확인이 필요해요':phase==='processing'?'결제 결과 확인 중':phase==='expired'?'결제 기한이 끝났어요':'예약 결제'}</h1>
 <Failure error={error}/>
 {phase==='loading'?<p role="status">결제 정보를 불러오고 있습니다.</p>:null}
 {phase==='ready'&&checkout?<><p>대여료 및 보증금 {checkout.amount.toLocaleString('ko-KR')}원</p><p className="text-sm text-muted-foreground">보증금은 반납 확인 후 반환됩니다.</p><Button onClick={pay} disabled={busy}>{busy?'결제창 여는 중…':'토스페이먼츠로 결제'}</Button></>:null}
 {phase==='processing'?<div role="status" className="flex flex-col gap-3"><p>중복 결제하지 마세요. 결제 결과를 확인하고 있습니다.</p>{nextRetryAt?<p>다음 확인 예정: {formatKoreaTime(nextRetryAt)} 이후</p>:null}<p>{connectionLost?'연결이 원활하지 않아 다시 확인 중입니다. 결제 실패로 확정된 상태는 아닙니다.':'확인이 끝나면 이 화면이 자동으로 바뀝니다.'}</p><p className="text-sm text-muted-foreground">거래 상세에서 처리 상태를 이어서 확인할 수 있습니다.</p></div>:null}
 {phase==='needs_review'?<div role="status"><p>자동 처리가 멈췄습니다. 중복 결제하지 말고 거래 상세에서 처리 상태를 확인해 주세요.</p><p className="break-all">문의용 거래 번호: {checkout?.reservationId}</p></div>:null}
 {phase==='paid'?<p>예약이 확정됐습니다. 거래 상세에서 인수 장소와 시간을 확인해 주세요.</p>:null}
 {phase==='expired'?<p>이 결제창에서는 더 이상 결제할 수 없습니다. 거래 상세에서 예약 상태를 확인해 주세요.</p>:null}
 {phase==='unavailable'&&!error?<p>현재 거래 상태에서는 결제할 수 없습니다. 거래 상세를 확인해 주세요.</p>:null}
 {phase!=='loading'?<Button asChild variant={phase==='paid'?'default':'outline'}><a href={back}>{checkout?'거래로 돌아가기':'거래 목록으로 돌아가기'}</a></Button>:null}
 </section>;
}
