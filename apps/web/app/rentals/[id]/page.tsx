'use client';
import {use,useState} from 'react';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {formatKoreaTime,formatWon,rentalStatusLabels,rentalTitle,rentalTerms} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Field,FieldLabel} from '@/components/ui/field';
export default function Rental({params}:{params:Promise<{id:string}>}){
 const {id}=use(params);const {api,client,session}=useApi();const queries=useQueryClient();
 const rental=useQuery({queryKey:['rental',id,session?.user.id],queryFn:()=>api.rental(id),enabled:!!session,refetchInterval:5000});
 const action=useMutation({mutationFn:(kind:'accept'|'reject'|'cancel')=>api.respondToRental(id,kind),onSettled:()=>{void queries.invalidateQueries({queryKey:['rental',id]});void queries.invalidateQueries({queryKey:['rentals']});}});
 const payment=useMutation({mutationFn:async()=>{const {checkoutUrl}=await api.preparePayment(id);window.location.assign(checkoutUrl);}});
 const [notice,setNotice]=useState('');
 const refresh=()=>{void queries.invalidateQueries({queryKey:['rental',id]});void queries.invalidateQueries({queryKey:['rentals']});};
 const command=useMutation({mutationFn:async(kind:'pickup'|'refund'|'settle'|'recover')=>{
  if(kind==='pickup'){await api.pickupRental(id);return;}
  const result=kind==='recover'?await api.recoverPayment(id):await api.moneyAction(id,kind);
  setNotice(result.status==='processing'?'결제사 결과를 확인 중입니다. 이 화면을 닫아도 서버에서 계속 확인합니다.':'처리 결과를 반영했습니다.');
 },onSettled:refresh});
 const returnPhoto=useMutation({mutationFn:async(file:File)=>{
  if(!session)throw new Error('로그인이 필요합니다.');
  if(file.size>5*1024*1024||!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('5MB 이하 JPG, PNG, WebP 사진을 선택해 주세요.');
  const path=`${id}/${session.user.id}/${crypto.randomUUID()}.${file.type.split('/')[1]}`;
  const {error}=await client.storage.from('rental-evidence').upload(path,file,{contentType:file.type});if(error)throw error;
  return api.returnRental(id,path);
 },onSettled:refresh});
 const r=session?rental.data:undefined;
 const terms=rentalTerms(r?.terms_snapshot);
 const evidence=useQuery({queryKey:['evidence',id,session?.user.id,r?.return_photo],queryFn:()=>api.evidenceUrl(r!.return_photo!),enabled:!!session&&!!r?.return_photo?.startsWith(`${id}/`),staleTime:240000});
 return <section className="mx-auto flex max-w-2xl flex-col gap-8"><h1 className="text-3xl font-bold">거래 상세</h1><Failure error={rental.error??action.error??payment.error??command.error??returnPhoto.error??evidence.error}/>
 {!session?<p>거래를 확인하려면 로그인해 주세요.</p>:rental.isPending?<p>거래를 불러오고 있습니다.</p>:null}
 {r?<><h2 className="text-2xl font-semibold">{rentalTitle(r)}</h2><p>{rentalStatusLabels[r.status??'']??'상태 확인 필요'}</p><p>{r.starts_at?formatKoreaTime(r.starts_at):r.rental_date} → {r.ends_at?formatKoreaTime(r.ends_at):r.return_date}</p>
 <dl className="grid grid-cols-2 gap-4 rounded-lg border p-6"><dt>대여료</dt><dd className="text-right">{formatWon(r.rental_fee)}</dd><dt>보증금</dt><dd className="text-right">{formatWon(r.deposit)}</dd><dt className="font-semibold">합계</dt><dd className="text-right font-semibold text-primary">{formatWon(r.total_paid)}</dd></dl>
 {r.status==='requested'&&r.lender_id===session?.user.id?<div className="flex gap-4"><Button onClick={()=>action.mutate('accept')} disabled={action.isPending}>예약 수락</Button><Button variant="outline" onClick={()=>action.mutate('reject')} disabled={action.isPending}>예약 거절</Button></div>:null}
 {r.status==='requested'&&r.borrower_id===session?.user.id?<Button variant="outline" onClick={()=>action.mutate('cancel')} disabled={action.isPending}>요청 취소</Button>:null}
 {r.status==='accepted'&&!r.payment_attempt_merchant_uid&&r.borrower_id===session?.user.id?<Button onClick={()=>payment.mutate()} disabled={payment.isPending}>결제하기</Button>:null}
 <section className="flex flex-col gap-3"><h2 className="text-xl font-semibold">수락한 거래 조건</h2><p className="whitespace-pre-wrap">{terms.description}</p><p>인수·반납 장소: {terms.pickupNote||'수락 당시 장소 정보가 없습니다.'}</p></section>
 {notice?<p role="status">{notice}</p>:null}
 {r.payment_action?<p role="status">환불 결과 확인 중에는 인수·반납을 진행할 수 없습니다.</p>:null}
 {r.status==='accepted'&&r.borrower_id===session?.user.id?<Button variant="outline" disabled={command.isPending} onClick={()=>command.mutate('recover')}>결제 결과 다시 확인</Button>:null}
 {r.status==='paid'&&!r.payment_action&&r.lender_id===session?.user.id?<Button disabled={command.isPending} onClick={()=>command.mutate('pickup')}>물품 인수 확인</Button>:null}
 {r.status==='paid'?<Button variant="outline" disabled={command.isPending} onClick={()=>command.mutate('refund')}>{r.payment_action?'환불 결과 다시 확인':'거래 취소 · 전액 환불'}</Button>:null}
 {r.status==='picked_up'&&!r.payment_action&&r.borrower_id===session?.user.id?<Field><FieldLabel htmlFor="return-photo">반납 사진 제출</FieldLabel><p className="text-sm text-muted-foreground">거래 당사자만 볼 수 있습니다. 사진을 제출하면 반납 신고가 접수됩니다.</p><Input id="return-photo" type="file" accept="image/jpeg,image/png,image/webp" disabled={returnPhoto.isPending} onChange={event=>{const file=event.target.files?.[0];if(file)returnPhoto.mutate(file);}}/></Field>:null}
 {evidence.data?<img src={evidence.data} alt="반납 증빙" className="max-h-80 rounded-lg object-contain"/>:null}
 {r.status==='returned'&&r.lender_id===session?.user.id?<Button disabled={command.isPending} onClick={()=>command.mutate('settle')}>{r.payment_action?'보증금 반환 결과 다시 확인':'반납 수령 확인 · 보증금 반환'}</Button>:null}
 {r.status==='returned'&&r.borrower_id===session?.user.id?<p>대여자의 수령 확인 후 보증금을 반환합니다.</p>:null}
 {r.status==='accepted'&&r.payment_due_at?<p className="text-muted-foreground">결제 기한 {formatKoreaTime(r.payment_due_at)}</p>:null}</>:null}</section>;
}
