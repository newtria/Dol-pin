'use client';
import {use,useState} from 'react';
import Link from 'next/link';
import {useRouter} from 'next/navigation';
import {useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {rentalPeriodInput,koreaTime,formatWon} from '@dolpin/contracts';
import {useRentalDrafts} from '@/lib/rental-drafts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Field,FieldLabel,FieldGroup,FieldError} from '@/components/ui/field';
export default function Reserve({params}:{params:Promise<{id:string}>}) {
 const {id}=use(params); const {api,session}=useApi(); const router=useRouter(); const queries=useQueryClient();
 const draft=useRentalDrafts.getState().drafts[id]; const [identity,setIdentity]=useState<string|undefined>(draft?.requestId);
 const form=useForm({resolver:zodResolver(rentalPeriodInput),defaultValues:{startsAt:draft?.startsAt??'',endsAt:draft?.endsAt??''}});
 const item=useQuery({queryKey:['item',id],queryFn:()=>api.item(id)});
 const request=useMutation({mutationFn:async(v:{startsAt:string;endsAt:string})=>{
  if(!item.data?.updated_at)throw new Error('상품을 다시 확인해 주세요.');
  const requestId=identity??crypto.randomUUID();setIdentity(requestId);useRentalDrafts.getState().setDraft(id,{...v,requestId});
  return api.requestRental({p_item_id:id,p_starts_at:koreaTime(v.startsAt),p_ends_at:koreaTime(v.endsAt),p_item_version:item.data.updated_at,p_request_id:requestId});
 },onSuccess:r=>{useRentalDrafts.getState().removeDraft(id);void queries.invalidateQueries({queryKey:['rentals']});router.replace(`/rentals/${r.id}`);}});
 if(!session)return <Button asChild><Link href="/account">로그인하고 예약하기</Link></Button>;
 return <section className="mx-auto flex max-w-xl flex-col gap-8"><h1 className="text-3xl font-bold">대여 기간 선택</h1><h2 className="text-xl font-semibold">{item.data?.title}</h2>
 {item.data?<p>{formatWon(item.data.daily_price)} / 24시간 · 보증금 {formatWon(item.data.deposit)}</p>:null}
 <p className="text-muted-foreground">한국 시간 기준입니다. 24시간 미만은 1일 요금이며, 반납까지의 이용 시간을 올림해 계산합니다.</p>
 <form onSubmit={form.handleSubmit(v=>request.mutate(v))}><FieldGroup>
 {(['startsAt','endsAt'] as const).map(name=><Field key={name} data-invalid={!!form.formState.errors[name]}><FieldLabel htmlFor={name}>{name==='startsAt'?'시작 일시':'반납 일시'}</FieldLabel><Input id={name} type="datetime-local" disabled={request.isPending} aria-invalid={!!form.formState.errors[name]} {...form.register(name,{onChange:()=>{setIdentity(undefined);useRentalDrafts.getState().setDraft(id,form.getValues());}})}/><FieldError errors={[form.formState.errors[name]]}/></Field>)}
 <p className="text-muted-foreground">대여자가 수락하면 결제할 수 있습니다. 요청만으로 물품이 확보되지는 않습니다.</p>
 <Button disabled={request.isPending||!item.data}>예약 요청</Button></FieldGroup></form><Failure error={item.error??request.error}/></section>;
}
