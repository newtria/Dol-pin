'use client';
import {pendingRentals} from '@/lib/pending-rentals';
import {type RentalRequest} from '@dolpin/api-client';
import {use,useEffect,useState} from 'react';
import Link from 'next/link';
import {useRouter} from 'next/navigation';
import {Controller,useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {rentalPeriodInput,koreaTime,formatWon,formatKoreaTime} from '@dolpin/contracts';
import {useRentalDrafts} from '@/lib/rental-drafts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Field,FieldLabel,FieldGroup,FieldError} from '@/components/ui/field';
export default function Reserve({params}:{params:Promise<{id:string}>}) {
 const {id}=use(params); const {api,session}=useApi(); const router=useRouter(); const queries=useQueryClient();
 const draft=useRentalDrafts(state=>state.drafts[id]); const [recovery,setRecovery]=useState<{owner:string;item:string;request:RentalRequest|null}>(); const [recoveryError,setRecoveryError]=useState<unknown>();
 const form=useForm({resolver:zodResolver(rentalPeriodInput),values:{startsAt:draft?.startsAt??'',endsAt:draft?.endsAt??''}});
 const item=useQuery({queryKey:['item',id],queryFn:()=>api.item(id)});
 const recoveryReady=!!session&&recovery?.owner===session.user.id&&recovery.item===id;
 const saved=recoveryReady?recovery.request:null;
 useEffect(()=>{
  let active=true;setRecovery(undefined);setRecoveryError(undefined);
  if(session)void pendingRentals.read(session.user.id,id).then(request=>{
    if(active)setRecovery({owner:session.user.id,item:id,request});
  }).catch(error=>{if(active)setRecoveryError(error);});
  return ()=>{active=false;};
 },[session?.user.id,id]);
 const request=useMutation({mutationFn:async(v:{startsAt:string;endsAt:string})=>{
  if(!session||!recoveryReady)throw new Error('저장된 요청을 확인하고 있습니다.');
  if(!saved&&!item.data?.updated_at)throw new Error('상품을 다시 확인해 주세요.');
  const owner=session.user.id;
  const input=saved??{p_item_id:id,p_starts_at:koreaTime(v.startsAt),p_ends_at:koreaTime(v.endsAt),p_item_version:item.data!.updated_at!,p_request_id:crypto.randomUUID()};
  setRecovery({owner,item:id,request:input});
  try {return await pendingRentals.submit(owner,input,api.requestRental);}
  finally {setRecovery({owner,item:id,request:await pendingRentals.read(owner,id)});}
 },onSuccess:r=>{useRentalDrafts.getState().removeDraft(id);void queries.invalidateQueries({queryKey:['rentals']});router.replace(`/rentals/${r.id}`);}});
 if(!session)return <Button asChild><Link href="/account">로그인하고 예약하기</Link></Button>;
 return <section className="mx-auto flex max-w-xl flex-col gap-8"><h1 className="text-3xl font-bold">대여 기간 선택</h1><h2 className="text-xl font-semibold">{item.data?.title}</h2>
 {item.data&&!saved?<p>{formatWon(item.data.daily_price)} / 24시간 · 보증금 {formatWon(item.data.deposit)}</p>:null}
 <p className="text-muted-foreground">한국 시간 기준입니다. 24시간 미만은 1일 요금이며, 반납까지의 이용 시간을 올림해 계산합니다.</p>
 {saved?<p>이전 요청의 결과를 확인해 주세요. 확인 전에는 대여 기간을 변경할 수 없습니다.{'\n'}{formatKoreaTime(saved.p_starts_at)} → {formatKoreaTime(saved.p_ends_at)}</p>:null}
 <form onSubmit={e=>{e.preventDefault();if(saved)request.mutate({startsAt:'',endsAt:''});else void form.handleSubmit(v=>request.mutate(v))(e);}}><FieldGroup>
 {!saved?(['startsAt','endsAt'] as const).map(name=><Controller key={name} name={name} control={form.control} render={({field})=><Field data-invalid={!!form.formState.errors[name]}><FieldLabel htmlFor={name}>{name==='startsAt'?'시작 일시':'반납 일시'}</FieldLabel><Input {...field} id={name} type="datetime-local" disabled={request.isPending||!!saved||!recoveryReady} aria-invalid={!!form.formState.errors[name]} onInput={event=>{const value=event.currentTarget.value;field.onChange(value);useRentalDrafts.getState().setDraft(id,{...form.getValues(),[name]:value});}} onChange={event=>{const value=event.target.value;field.onChange(value);useRentalDrafts.getState().setDraft(id,{...form.getValues(),[name]:value});}}/><FieldError errors={[form.formState.errors[name]]}/></Field>}/>):null}
 <p className="text-muted-foreground">대여자가 수락하면 결제할 수 있습니다. 요청만으로 물품이 확보되지는 않습니다.</p>
 <Button disabled={request.isPending||!recoveryReady||(!saved&&!item.data)}>{saved?'예약 결과 다시 확인':'예약 요청'}</Button></FieldGroup></form><Failure error={recoveryError??item.error??request.error}/></section>;
}
