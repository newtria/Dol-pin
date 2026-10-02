'use client';
import {useEffect,useState} from 'react';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import type {Payout,PayoutClaim,Dispute,FinanceReservation} from '@dolpin/api-client';
import {formatWon} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {OperationRental} from '@/components/operation-rental';
import {OperationItem} from '@/components/operation-item';

const reviewLabels={pickup_overdue:'인수 기한 경과',return_overdue:'미반납',settlement_overdue:'반납 확인 지연',dispute_unresolved:'미해결 분쟁',untracked_payment:'결제 내역 대조',legacy_finance:'과거 금융 내역 대조'};
const reportLabels:Record<string,string>={fraud:'사기 의심',abuse:'괴롭힘',unsafe:'안전 문제',prohibited:'금지 물품',other:'기타 문의'};
function askReason(message:string,min=2){
 const value=window.prompt(message)?.trim();
 if(!value)return;
 if(value.length<min||value.length>500){window.alert(`사유를 ${min}자 이상 500자 이내로 입력해 주세요.`);return;}
 return value;
}
function Pages({offset,hasMore,pending,setOffset}:{offset:number;hasMore:boolean;pending:boolean;setOffset:(offset:number)=>void}){
 return <nav aria-label="업무 목록 페이지" className="flex items-center gap-3"><Button variant="outline" disabled={offset===0||pending} onClick={()=>setOffset(Math.max(0,offset-100))}>이전 업무</Button><span>{offset/100+1}페이지</span><Button variant="outline" disabled={!hasMore||pending} onClick={()=>setOffset(offset+100)}>다음 업무</Button></nav>;
}
export default function Operations(){
 const {session}=useApi();
 return <OperationWorkspace key={`${session?.user.id??'signed-out'}:${session?.user.app_metadata?.dolpin_operator===true}`}/>;
}
function OperationWorkspace(){
 const {api,session,ready}=useApi();
 const queries=useQueryClient();
 const [offset,setOffset]=useState(0),[serviceOffset,setServiceOffset]=useState(0);
 const [reservationId,setReservationId]=useState(''),[lookup,setLookup]=useState(''),[itemId,setItemId]=useState('');
 const allowed=ready&&session?.user.app_metadata?.dolpin_operator===true;
 useEffect(()=>{
  const id=new URLSearchParams(window.location.search).get('reservationId');
  if(id&&/^[a-f\d]{8}-(?:[a-f\d]{4}-){3}[a-f\d]{12}$/i.test(id)){setReservationId(id);setLookup(id);}
 },[]);
 const finance=useQuery({queryKey:['ops-finance',session?.user.id,offset],queryFn:()=>api.operationQueue(offset),enabled:allowed,refetchInterval:30000,gcTime:0});
 const service=useQuery({queryKey:['ops-service',session?.user.id,serviceOffset],queryFn:()=>api.operations(serviceOffset),enabled:allowed,refetchInterval:30000,gcTime:0});
 const refresh=()=>{
  void queries.invalidateQueries({queryKey:['ops-finance']});
  void queries.invalidateQueries({queryKey:['ops-service']});
  void queries.invalidateQueries({queryKey:['ops-rental']});
  void queries.invalidateQueries({queryKey:['ops-item']});
 };
 const command=useMutation({mutationFn:(run:()=>Promise<unknown>)=>run(),onSettled:refresh});
 const inspect=(id:string)=>{if(!/^[a-f\d]{8}-(?:[a-f\d]{4}-){3}[a-f\d]{12}$/i.test(id))return;setItemId('');setReservationId(id);setLookup(id);};
 const inspectItem=(id:string)=>{setReservationId('');setItemId(id);};
 const financeData=finance.isError?undefined:finance.data,serviceData=service.isError?undefined:service.data;
 const moderateItem=(id:string,hidden:boolean)=>{
  const reason=askReason(hidden?'물품 비노출 사유를 입력하세요.':'비노출 제한을 해제하는 사유를 입력하세요. 공개 전환은 소유자가 결정합니다.');
  if(reason)command.mutate(()=>api.moderateItem(id,hidden,reason));
 };
 const moderateReport=(id:string,status:'resolved'|'dismissed')=>{
  const reason=askReason('신고자에게 전달할 처리 결과를 입력하세요. 다른 사용자의 개인정보는 포함하지 마세요.');
  if(reason)command.mutate(()=>api.moderateReport(id,status,reason));
 };
 if(!ready)return <p>권한을 확인하고 있습니다.</p>;
 if(!allowed)return <p>운영자 계정으로 로그인해 주세요.</p>;
 return <section className="flex flex-col gap-6">
  <h1 className="text-3xl font-bold">운영 관리</h1>
  <Button variant="outline" onClick={refresh}>새로고침</Button>
  <Failure error={finance.error??service.error??command.error}/>
  <form className="flex flex-wrap gap-3" onSubmit={event=>{event.preventDefault();inspect(lookup.trim());}}>
   <label className="grow">거래 번호<Input value={lookup} onChange={event=>setLookup(event.target.value)} placeholder="조회할 거래 번호"/></label>
   <Button className="self-end" disabled={!/^[a-f\d]{8}-(?:[a-f\d]{4}-){3}[a-f\d]{12}$/i.test(lookup.trim())}>거래 조사</Button>
  </form>
  {reservationId?<><Button variant="outline" onClick={()=>setReservationId('')}>거래 조사 닫기</Button><OperationRental key={session?.user.id+':'+reservationId} id={reservationId}/></>:null}
  {itemId?<><Button variant="outline" onClick={()=>setItemId('')}>물품 조사 닫기</Button><OperationItem key={session?.user.id+':'+itemId} id={itemId}/></>:null}
  <h2 className="text-2xl font-semibold">거래·정산 업무</h2>
  <Pages offset={offset} hasMore={financeData?.hasMore??false} pending={finance.isFetching} setOffset={setOffset}/>
  {finance.isPending?<p>업무를 불러오고 있습니다.</p>:null}
  <h3 className="text-xl font-semibold">대여료 지급</h3>
  <p>은행에서 송금하기 전에 담당 처리를 시작하세요. 결과가 불명확하면 보류하고 은행 내역부터 확인하세요.</p>
  {financeData?.payouts.map(p=><div key={session?.user.id+':'+p.id}><Button variant="link" onClick={()=>inspect(p.reservation_id)}>거래 조사</Button><PayoutWork payout={p} refresh={refresh}/></div>)}
  <h3 className="text-xl font-semibold">분쟁 처리</h3>
  {financeData?.disputes.map(d=><div key={session?.user.id+':'+d.id}><Button variant="link" onClick={()=>inspect(d.reservation_id)}>거래·양측 증빙 조사</Button><DisputeWork dispute={d} reservation={financeData?.reservations.find(r=>r.id===d.reservation_id)} refresh={refresh}/></div>)}
  <h3 className="text-xl font-semibold">지연 거래·결제 복구</h3>
  {financeData?.reviews.map(r=><article key={r.id} className="rounded border p-4">
   <p>{reviewLabels[r.kind]}</p><Button variant="link" onClick={()=>inspect(r.reservation_id)}>거래 {r.reservation_id} 조사</Button>
   {['pickup_overdue','return_overdue','settlement_overdue'].includes(r.kind)?<Button variant="outline" disabled={command.isPending} onClick={()=>{const note=askReason('당사자 확인 결과와 분쟁 전환 사유를 입력하세요.',5);if(note&&window.confirm('거래를 분쟁 처리로 전환할까요? 이후 판정을 통해 반환 금액을 확정해야 합니다.'))command.mutate(()=>api.escalateReview(r.id,note));}}>분쟁 검토로 전환</Button>:null}
   <Button disabled={command.isPending} onClick={()=>{
    const legacy=r.kind==='legacy_finance';
    const note=askReason(legacy?'PG 콘솔에서 각 결제·환불 금액을 대조하고 미처리 금액을 해결한 근거를 입력하세요.':'처리 결과를 기록하세요.',5);
    if(note&&(!legacy||window.confirm('관련 결제 참조를 모두 대조했고 추가 환불이나 지급이 남지 않았습니까? 이 기록으로 해당 결제 검토가 종결됩니다.')))command.mutate(()=>api.closeReview(r.id,note));
   }}>검토 결과 기록</Button>
  </article>)}
  {financeData?.recovery.map(work=><article key={`${work.kind}:${work.key}`} className="rounded border p-4">
   <Button variant="link" onClick={()=>inspect(work.reservation_id)}>거래 {work.reservation_id} 조사</Button><p>실패 {work.failure_count}회 · {work.review_required_at?'운영 확인 필요':'자동 재시도 대기'}</p>
   <Button variant="outline" disabled={command.isPending||!work.review_required_at} onClick={()=>{if(window.confirm('기존 결제와 환불을 대조한 뒤 복구를 재개할까요?'))command.mutate(()=>api.retryRecovery(work.kind,work.key));}}>대조 후 복구 재개</Button>
  </article>)}
  <h2 className="text-2xl font-semibold">신고·서비스 업무</h2>
  <Pages offset={serviceOffset} hasMore={serviceData?.hasMore??false} pending={service.isFetching} setOffset={setServiceOffset}/>
  {service.isPending?<p>서비스 업무를 불러오고 있습니다.</p>:null}
  <h3 className="text-xl font-semibold">신고</h3>
  {serviceData?.reports.map(r=><article key={r.id} className="flex flex-col gap-3 rounded border p-4">
   <p>{reportLabels[r.reason]??'신고'} · 접수됨</p><p className="whitespace-pre-wrap">{r.description}</p>
   {r.reservation_id?<Button variant="outline" onClick={()=>inspect(r.reservation_id!)}>관련 거래 조사</Button>:null}
   {r.reported_item_id?<><Button variant="outline" onClick={()=>inspectItem(r.reported_item_id!)}>신고된 물품 조사</Button><Button disabled={command.isPending} onClick={()=>moderateItem(r.reported_item_id!,true)}>물품 비노출</Button></>:null}
   {r.reported_user_id?<Button disabled={command.isPending} onClick={()=>{const reason=askReason('계정 제한 사유를 입력하세요.');if(reason)command.mutate(()=>api.setUserSuspended(r.reported_user_id!,true,reason));}}>계정 제한</Button>:null}
   <Button disabled={command.isPending} onClick={()=>moderateReport(r.id,'resolved')}>처리 결과 전달</Button>
   <Button variant="outline" disabled={command.isPending} onClick={()=>moderateReport(r.id,'dismissed')}>기각 사유 전달</Button>
  </article>)}
  <h3 className="text-xl font-semibold">계정 제한 관리</h3>
  {serviceData?.users.map(u=><article key={u.id} className="rounded border p-4"><p>{u.nickname}</p><Button disabled={command.isPending} onClick={()=>{const reason=askReason('제한 해제 사유를 입력하세요.');if(reason)command.mutate(()=>api.setUserSuspended(u.id,false,reason));}}>제한 해제</Button></article>)}
  <h3 className="text-xl font-semibold">비노출 물품 관리</h3>
  {serviceData?.items.map(item=><article key={item.id} className="rounded border p-4"><p>{item.title}</p><Button variant="outline" onClick={()=>inspectItem(item.id)}>물품 조사</Button><Button disabled={command.isPending} onClick={()=>moderateItem(item.id,false)}>비노출 제한 해제</Button><p className="text-sm">해제 후 소유자가 다시 공개할 수 있습니다.</p></article>)}
  <h3 className="text-xl font-semibold">알림·탈퇴 처리 상태</h3>
  {serviceData?.notifications.map(n=><article key={n.id} className="rounded border p-4"><p>알림 전달 확인 필요 · 시도 {n.attempt_count}회</p><Button disabled={command.isPending||!n.canRetry} onClick={()=>command.mutate(()=>api.retryNotification(n.id))}>전달 확인 재개</Button><Button variant="outline" disabled={command.isPending} onClick={()=>{if(window.confirm('기기 푸시 재발송을 중지할까요? 알림함의 기록은 유지됩니다.'))command.mutate(()=>api.dismissNotification(n.id));}}>재발송 중지</Button></article>)}
  {serviceData?.closures.map(c=><p key={c.user_id}>탈퇴 요청 {c.user_id} · 재처리 {c.attempts}회</p>)}
  {serviceData?<><p>알림 설정 {serviceData.health.configured?'등록됨':'미설정'} · 스케줄 {serviceData.health.scheduled?'등록됨':'미등록'}</p><p>알림 운영 확인 {serviceData.health.pushNeedsReview}건 · 탈퇴 대기 {serviceData.health.pendingClosures}건 · 결제 복구 지연 {serviceData.health.paymentRecoveryStalled}건</p></>:null}
 </section>;
}
function PayoutWork({payout:p,refresh}:{payout:Payout;refresh:()=>void}){
 const {api,session}=useApi();
 const [claim,setClaim]=useState<PayoutClaim>();
 const [reference,setReference]=useState(''),[bankReason,setBankReason]=useState('');
 const action=useMutation({mutationFn:(run:()=>Promise<unknown>)=>run(),onSettled:refresh});
 useEffect(()=>{
  setReference('');setBankReason('');
  setClaim(current=>p.status==='processing'&&current?.payout.claimed_at===p.claimed_at&&current?.payout.claimed_by===p.claimed_by?current:undefined);
 },[p.claimed_at,p.claimed_by,p.status]);
 const currentClaim=claim&&p.status==='processing'&&claim.payout.claimed_at===p.claimed_at&&p.claimed_by===session?.user.id?claim:undefined;
 const reconcile=(outcome:'paid'|'not_sent')=>{
  const message=outcome==='paid'?'은행에서 실제 송금을 확인했고 확인번호가 일치합니까?':'이전 담당자의 송금 작업이 중단됐고 은행에서 미송금을 확인했습니까?';
  if(window.confirm(message))action.mutate(async()=>{
   await api.reconcilePayout(p.id,p.claimed_at??null,outcome,bankReason,reference);
   setClaim(undefined);setReference('');setBankReason('');
  });
 };
 return <article className="flex flex-col gap-3 rounded border p-5">
  <p>거래 {p.reservation_id}</p><p>지급액 {formatWon(p.net_amount)} · {({pending:'지급 대기',processing:'담당 처리 중',paid:'지급됨',failed:'은행 대조 필요'})[p.status]}</p>
  {p.status==='pending'||(p.status==='processing'&&p.claimed_by===session?.user.id)?<Button disabled={action.isPending} onClick={()=>action.mutate(async()=>setClaim(await api.claimPayout(p.id)))}>담당 시작·지급 계좌 확인</Button>:null}
  {p.status==='processing'&&p.claimed_by!==session?.user.id?<p>다른 담당자가 송금 결과를 확인하고 있습니다.</p>:null}
  {currentClaim?<>
   <p>{currentClaim.account.bankName} · {currentClaim.account.accountNumber} · {currentClaim.account.holderName}</p>
   <label>은행 송금 확인번호<Input value={reference} onChange={e=>setReference(e.target.value)} autoComplete="off" maxLength={160}/></label>
   <Button disabled={action.isPending||reference.trim().length<4} onClick={()=>{
    if(window.confirm(`${formatWon(p.net_amount)}를 실제로 송금했고 은행 내역을 확인했습니까?`))action.mutate(async()=>{await api.completePayout(p.id,currentClaim.claimToken,reference);setClaim(undefined);setReference('');setBankReason('');});
   }}>실제 송금 완료 기록</Button>
   <Button variant="outline" disabled={action.isPending} onClick={()=>{
    const reason=askReason('보류 사유를 기록하세요. 결과가 불명확하면 다시 송금하지 마세요.',5);
    if(reason)action.mutate(async()=>{await api.failPayout(p.id,currentClaim.claimToken,reason);setClaim(undefined);setReference('');setBankReason('');});
   }}>송금 결과 보류</Button>
  </>:null}
  {p.status==='processing'||p.status==='failed'?<details className="rounded border p-3">
   <summary>은행 결과 대조·담당자 인계</summary><div className="mt-3 flex flex-col gap-3">
    <p>진행 중인 지급은 1시간 경과 또는 기존 담당자 권한 회수 후 인계할 수 있습니다. 이전 담당자의 송금 작업 중단과 은행 내역을 먼저 확인하세요.</p>
    <label>확인 근거 (5자 이상)<Input value={bankReason} onChange={e=>setBankReason(e.target.value)} maxLength={500}/></label>
    <label>이미 송금된 경우 은행 확인번호<Input value={reference} onChange={e=>setReference(e.target.value)} autoComplete="off" maxLength={160}/></label>
    <Button disabled={action.isPending||bankReason.trim().length<5||reference.trim().length<4} onClick={()=>reconcile('paid')}>기존 송금 확인·종결</Button>
    <Button variant="outline" disabled={action.isPending||bankReason.trim().length<5} onClick={()=>reconcile('not_sent')}>미송금 확인·지급 대기로 되돌리기</Button>
   </div>
  </details>:null}
  <Failure error={action.error}/>
 </article>;
}
function DisputeWork({dispute:d,reservation:r,refresh}:{dispute:Dispute;reservation?:FinanceReservation;refresh:()=>void}){
 const {api}=useApi();const [amount,setAmount]=useState(''),[reason,setReason]=useState('');
 const action=useMutation({mutationFn:()=>api.resolveDispute(d.reservation_id,Number(amount),reason),onSuccess:()=>{setAmount('');setReason('');},onSettled:refresh});
 const evidence=useMutation({mutationFn:(path:string)=>api.operatorEvidenceUrl(path)});
 const deciding=action.isPending||action.data?.status==='processing'||!!r?.payment_action;
 return <article className="flex flex-col gap-3 rounded border p-5"><p>거래 {d.reservation_id} · {d.resolved_at?'종결':'검토 중'}</p><p className="whitespace-pre-wrap">{d.reason}</p><p>총 결제 {r?formatWon(r.total_paid):'조회 불가'}</p>{d.evidence_paths.map(path=><Button key={path} variant="outline" disabled={evidence.isPending} onClick={()=>evidence.mutate(path)}>증빙 사진 보기</Button>)}{evidence.data&&!evidence.isPending&&!evidence.isError?<img src={evidence.data} alt="분쟁 증빙" className="max-h-96 object-contain"/>:null}{deciding?<p role="status">판정 처리 결과를 확인하고 있습니다. 새로운 환불 요청을 보내지 마세요.</p>:null}{!d.resolved_at?<><label>차용자에게 반환할 총액 (원)<Input type="number" min={0} max={r?.total_paid} disabled={deciding} value={amount} onChange={e=>setAmount(e.target.value)}/></label><label>판정 근거<Input value={reason} disabled={deciding} maxLength={2000} onChange={e=>setReason(e.target.value)}/></label><Button disabled={!r||r.status!=='disputed'||deciding||amount===''||!Number.isSafeInteger(Number(amount))||Number(amount)<0||Number(amount)>r.total_paid||reason.trim().length<10} onClick={()=>{if(window.confirm(`차용자에게 ${formatWon(Number(amount))}를 반환하고 분쟁을 종결할까요? 이 판단으로 대여료 지급액도 확정됩니다.`))action.mutate();}}>판정 확정·환불 요청</Button></>:null}<Failure error={action.error??evidence.error}/></article>;
}
