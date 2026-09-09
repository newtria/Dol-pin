'use client';
import {use} from 'react';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {formatKoreaTime,formatWon,rentalStatusLabels,rentalTitle} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
export default function Rental({params}:{params:Promise<{id:string}>}){
 const {id}=use(params);const {api,session}=useApi();const queries=useQueryClient();
 const rental=useQuery({queryKey:['rental',id],queryFn:()=>api.rental(id),enabled:!!session,refetchInterval:5000});
 const action=useMutation({mutationFn:(kind:'accept'|'reject'|'cancel')=>api.respondToRental(id,kind),onSettled:()=>{void queries.invalidateQueries({queryKey:['rental',id]});void queries.invalidateQueries({queryKey:['rentals']});}});
 const payment=useMutation({mutationFn:async()=>{const {checkoutUrl}=await api.preparePayment(id);window.location.assign(checkoutUrl);}});
 const r=session?rental.data:undefined;
 return <section className="mx-auto flex max-w-2xl flex-col gap-8"><h1 className="text-3xl font-bold">거래 상세</h1><Failure error={rental.error??action.error??payment.error}/>
 {!session?<p>거래를 확인하려면 로그인해 주세요.</p>:rental.isPending?<p>거래를 불러오고 있습니다.</p>:null}
 {r?<><h2 className="text-2xl font-semibold">{rentalTitle(r)}</h2><p>{rentalStatusLabels[r.status??'']??'상태 확인 필요'}</p><p>{r.starts_at?formatKoreaTime(r.starts_at):r.rental_date} → {r.ends_at?formatKoreaTime(r.ends_at):r.return_date}</p>
 <dl className="grid grid-cols-2 gap-4 rounded-lg border p-6"><dt>대여료</dt><dd className="text-right">{formatWon(r.rental_fee)}</dd><dt>보증금</dt><dd className="text-right">{formatWon(r.deposit)}</dd><dt className="font-semibold">합계</dt><dd className="text-right font-semibold text-primary">{formatWon(r.total_paid)}</dd></dl>
 {r.status==='requested'&&r.lender_id===session?.user.id?<div className="flex gap-4"><Button onClick={()=>action.mutate('accept')} disabled={action.isPending}>예약 수락</Button><Button variant="outline" onClick={()=>action.mutate('reject')} disabled={action.isPending}>예약 거절</Button></div>:null}
 {r.status==='requested'&&r.borrower_id===session?.user.id?<Button variant="outline" onClick={()=>action.mutate('cancel')} disabled={action.isPending}>요청 취소</Button>:null}
 {r.status==='accepted'&&r.borrower_id===session?.user.id?<Button onClick={()=>payment.mutate()} disabled={payment.isPending}>결제하기</Button>:null}
 {r.status==='accepted'&&r.payment_due_at?<p className="text-muted-foreground">결제 기한 {formatKoreaTime(r.payment_due_at)}</p>:null}</>:null}</section>;
}
