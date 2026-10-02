'use client';
import {useInfiniteQuery,useMutation} from '@tanstack/react-query';
import {formatWon,formatKoreaTime,rentalStatusLabels,rentalTerms} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';

type MessageCursor={createdAt:string;id:string};
const moneyLabels:Record<string,string>={refund:'환불',settle:'보증금 반환',dispute:'분쟁 환불',prepared:'처리 준비',processing:'처리 중',succeeded:'처리됨',failed:'확인 필요',complete:'처리됨',pending:'대기',paid:'지급됨'};
const verificationLabels:Record<string,string>={amount_currency_mismatch:'금액·통화 불일치',different_payment:'다른 결제 참조',different_attempt:'다른 결제 시도',external_refund:'외부 환불 내역',verification_rejected:'결제 검증 거절'};
export function OperationRental({id}:{id:string}){
 const {api,session}=useApi();
 const query=useInfiniteQuery({
  queryKey:['ops-rental',session?.user.id,id],initialPageParam:undefined as MessageCursor|undefined,
  queryFn:({pageParam})=>api.operationRental(id,pageParam),
  getNextPageParam:last=>{const message=last.messages.at(-1);return last.messagesHasMore&&message?{createdAt:message.created_at,id:message.id}:undefined;},
  gcTime:0,retry:false,
 });
 const photo=useMutation({mutationFn:(path:string|null)=>path?api.operatorEvidenceUrl(path):api.operatorReturnPhotoUrl(id)});
 const data=query.isError?undefined:query.data?.pages[0],r=data?.reservation;
 const terms=r?rentalTerms(r.terms_snapshot):null;
 const messages=query.data?.pages.flatMap(page=>page.messages)??[];
 const name=(userId:string|null)=>userId?(data?.participants.find(user=>user.id===userId)?.nickname??'이전 사용자'):'운영팀';
 return <section className="flex flex-col gap-4 rounded border p-5" aria-label="운영 거래 조사">
  <h2 className="text-xl font-semibold">거래 조사</h2><p className="break-all">{id}</p><Failure error={query.error??photo.error}/>
  {query.isPending?<p>거래 기록을 확인하고 있습니다.</p>:null}
  {data&&r?<>
   <h3>{typeof r.terms_snapshot?.title==='string'?r.terms_snapshot.title:data.item?.title??'이전 물품'}</h3>
   <p>{rentalStatusLabels[r.status]??'확인 필요'} · 빌리는 분 {name(r.borrower_id)} · 빌려주는 분 {name(r.lender_id)}</p>
   <p>대여료 {formatWon(r.rental_fee)} · 보증금 {formatWon(r.deposit)} · 총 결제 {formatWon(r.total_paid)}</p>
   <p>{r.starts_at?formatKoreaTime(r.starts_at):r.rental_date} ~ {r.ends_at?formatKoreaTime(r.ends_at):r.return_date}</p>
   {terms?.description?<p className="whitespace-pre-wrap">당시 설명: {terms.description}</p>:null}
   {terms?.pickupNote?<p className="whitespace-pre-wrap">수락 당시 인수·반납 장소: {terms.pickupNote}</p>:null}
   <p>인수 확인: 차용자 {data.pickup.borrowerConfirmed?'확인':'미확인'} / 대여자 {data.pickup.lenderConfirmed?'확인':'미확인'}</p>
   {r.return_photo?<Button variant="outline" disabled={photo.isPending} onClick={()=>photo.mutate(null)}>제출된 반납 사진 보기</Button>:null}
   <h3 className="font-semibold">분쟁·판정</h3>
   {data.disputes.map(dispute=><article key={dispute.id} className="rounded border p-3"><p>{name(dispute.reporter_id)} · {dispute.resolved_at?'종결':'검토 중'}</p><p className="whitespace-pre-wrap">{dispute.reason}</p>{dispute.evidence_paths.map((path,index)=><Button key={path} variant="outline" disabled={photo.isPending} onClick={()=>photo.mutate(path)}>증빙 {index+1} 보기</Button>)}</article>)}
   {data.resolutions.map((result,index)=><p key={index} className="whitespace-pre-wrap">판정 반환액 {formatWon(result.refund_amount)} · {result.reason}{result.created_at?` · ${formatKoreaTime(result.created_at)}`:''}</p>)}
   {photo.data&&!photo.isPending&&!photo.isError?<img src={photo.data} alt="거래 조사 증빙" className="max-h-96 max-w-full object-contain" referrerPolicy="no-referrer"/>:null}
   <h3 className="font-semibold">환불·지급 기록</h3>
   {data.legacyPayments.map(payment=><article key={payment.payment_reference} className="rounded border p-3"><p>과거 결제 대조 · {payment.resolved_at?'검토 기록 있음':'운영 확인 필요'}</p><p>{verificationLabels[payment.reason_code]??'결제 내역 확인 필요'} · {formatKoreaTime(payment.created_at)}</p><p className="break-all">결제 참조 {payment.payment_reference}</p><p>결제 {payment.amount} {payment.currency} · 반환 {payment.refunded} {payment.currency}</p></article>)}
   {data.operations.map(operation=><p key={operation.id}>{moneyLabels[operation.kind]??operation.kind} {formatWon(operation.amount)} · {moneyLabels[operation.status]??operation.status}{operation.review_required_at?' · 운영 확인 필요':''}</p>)}
   {data.payouts.map(payout=><p key={payout.id}>대여료 지급 {formatWon(payout.net_amount)} · {moneyLabels[payout.status]??payout.status}</p>)}
   <details><summary>거래 상태 이력</summary>{data.events.map(event=><p key={event.id}>{formatKoreaTime(event.created_at)} · {rentalStatusLabels[event.from_status??'']??'시작'} → {rentalStatusLabels[event.to_status]??event.to_status}</p>)}</details>
   <h3 className="font-semibold">당사자 메시지 (최신순)</h3>
   {messages.map(message=><article key={message.id} className="rounded border p-3"><p>{name(message.sender_id)} · {formatKoreaTime(message.created_at)}</p><p className="whitespace-pre-wrap">{message.message}</p></article>)}
   {query.hasNextPage?<Button variant="outline" disabled={query.isFetchingNextPage} onClick={()=>void query.fetchNextPage()}>이전 메시지</Button>:null}
  </>:null}
  <Button variant="outline" disabled={query.isFetching} onClick={()=>void query.refetch()}>거래 다시 조회</Button>
 </section>;
}
