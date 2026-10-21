'use client';
import {pendingRentals} from '@/lib/pending-rentals';
import {type RentalRequest} from '@dolpin/api-client';
import {Suspense,use,useEffect,useLayoutEffect,useRef,useState,type FormEvent} from 'react';
import Link from 'next/link';
import {useRouter,useSearchParams} from 'next/navigation';
import {Controller,useForm,useWatch} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {rentalEstimate,rentalPeriodInput,rentalPeriodConflict,koreaTime,formatWon,formatKoreaTime,reservationInitialPeriod,reservationContextKey,type ReservationPeriodSource} from '@dolpin/contracts';
import {useRentalDrafts} from '@/lib/rental-drafts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Field,FieldLabel,FieldGroup,FieldError} from '@/components/ui/field';
import {RentalCalendar} from '@/components/rental-calendar';
import {accountHref} from '@/components/auth-return';

export default function Reserve({params}:{params:Promise<{id:string}>}) {
 const {id}=use(params);
 return <Suspense fallback={<p role="status">예약 정보를 불러오고 있습니다.</p>}><RentalRequestRoute id={id}/></Suspense>;
}
function RentalRequestRoute({id}:{id:string}) {
 const {session}=useApi();const search=useSearchParams();
 const routePeriod={startsAt:search.get('startsAt'),endsAt:search.get('endsAt')};
 return <RentalRequestContents key={reservationContextKey(session?.user.id,id,routePeriod)} id={id} routePeriod={routePeriod}/>;
}
function RentalRequestContents({id,routePeriod}:{id:string;routePeriod:ReservationPeriodSource}) {
 const {api,client,session,ready}=useApi(); const router=useRouter(); const queries=useQueryClient();
 const mounted=useRef(false);
 useLayoutEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 const draft=useRentalDrafts(state=>state.drafts[id]); const [recovery,setRecovery]=useState<{owner:string;item:string;request:RentalRequest|null}>(); const [recoveryError,setRecoveryError]=useState<unknown>();const [recoveryAttempt,setRecoveryAttempt]=useState(0);
 const form=useForm({resolver:zodResolver(rentalPeriodInput),defaultValues:reservationInitialPeriod(routePeriod,draft)});
 const item=useQuery({queryKey:['item',id],queryFn:()=>api.item(id)});
 const availability=useQuery({queryKey:['availability',id],queryFn:()=>api.itemAvailability(id)});
 const consent=useQuery({queryKey:['consent',session?.user.id],queryFn:api.consentStatus,enabled:!!session});
 const profile=useQuery({queryKey:['profile',session?.user.id],queryFn:()=>api.profile(session!.user.id),enabled:!!session});
 const period=useWatch({control:form.control});
 const estimate=item.data?rentalEstimate(period.startsAt??'',period.endsAt??'',item.data.daily_price,item.data.deposit):null;
 const conflict=period.startsAt&&period.endsAt&&availability.data&&item.data?rentalPeriodConflict(period.startsAt,period.endsAt,availability.data,item.data.available_from,item.data.available_to):null;
 const recoveryReady=!!session&&recovery?.owner===session.user.id&&recovery.item===id;
 const saved=recoveryReady?recovery.request:null;
 const owner=item.data?.lender_id===session?.user.id;
 const prerequisites=!!session&&!!profile.data&&consent.data?.accepted;
 useEffect(()=>{
  let active=true;setRecovery(undefined);setRecoveryError(undefined);
  if(session)void pendingRentals.read(session.user.id,id).then(request=>{if(active)setRecovery({owner:session.user.id,item:id,request});}).catch(error=>{if(active)setRecoveryError(error);});
  return ()=>{active=false;};
 },[session?.user.id,id,recoveryAttempt]);
 const request=useMutation({mutationFn:async(v:{startsAt:string;endsAt:string})=>{
  if(!mounted.current||!ready||!session||!recoveryReady)throw new Error('저장된 요청을 확인하고 있습니다.');
  if(!saved&&item.data?.status!=='active')throw new Error('현재 새 예약을 받지 않는 물품입니다. 다른 물품을 선택해 주세요.');
  if(!saved&&!item.data?.updated_at)throw new Error('상품을 다시 확인해 주세요.');
  if(!saved&&(owner||!availability.isSuccess||!prerequisites||consent.isError||profile.isError))throw new Error('상품을 다시 확인해 주세요.');
  if(!saved){const conflict=rentalPeriodConflict(v.startsAt,v.endsAt,availability.data!,item.data?.available_from,item.data?.available_to);if(conflict)throw new Error(conflict);}
  const requestOwner=session.user.id;
  const input=saved??{p_item_id:id,p_starts_at:koreaTime(v.startsAt),p_ends_at:koreaTime(v.endsAt),p_item_version:item.data!.updated_at!,p_request_id:crypto.randomUUID()};
  setRecoveryError(undefined);
  setRecovery({owner:requestOwner,item:id,request:input});
  try {return await pendingRentals.submit(requestOwner,input,request=>{if(!mounted.current)throw new Error('저장된 요청을 확인하고 있습니다.');return api.requestRental(request,requestOwner);});}
  catch(error){
   if(mounted.current)try{const request=await pendingRentals.read(requestOwner,id);if(mounted.current)setRecovery({owner:requestOwner,item:id,request});}
   catch(recoveryError){if(mounted.current)setRecoveryError(recoveryError);}
   throw error;
  }
 },onSuccess:async r=>{
  if(!mounted.current)return;
  const {data,error}=await client.auth.getSession();
  if(!mounted.current||error||data.session?.user.id!==session?.user.id)return;
  useRentalDrafts.getState().removeDraft(id);void queries.invalidateQueries({queryKey:['rentals']});router.replace(`/rentals/${r.id}`);
 }});
 function update(name:'startsAt'|'endsAt',value:string){form.setValue(name,value,{shouldValidate:true});useRentalDrafts.getState().setDraft(id,form.getValues());}
 function selectDay(name:'startsAt'|'endsAt',day:string,time?:string){
  const value=`${day}T${time||form.getValues(name).split('T')[1]||(name==='startsAt'?'12:00':'18:00')}`;update(name,value);
  if(name==='startsAt'&&(!form.getValues('endsAt')||form.getValues('endsAt')<=value))update('endsAt',value.slice(11)<'18:00'?`${day}T18:00`:new Date(Date.parse(koreaTime(value))+33*3600000).toISOString().slice(0,16));
 }
 const busy=request.isPending||!!saved;
 const blocked=!ready||request.isPending||!!session&&!recoveryReady||!saved&&(owner||item.data?.status!=='active'||!estimate||!!conflict||!availability.isSuccess||!!session&&(consent.isPending||profile.isPending||consent.isError||profile.isError));
 function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();
  if(blocked||!mounted.current)return;
  if(saved){request.mutate({startsAt:'',endsAt:''});return;}
  void form.handleSubmit(values=>{
   if(!mounted.current)return;
   useRentalDrafts.getState().setDraft(id,values);
   if(!session||!prerequisites){router.push(accountHref(`/items/${id}/reserve?${new URLSearchParams(values)}`));return;}
   request.mutate(values);
  })(event);
 }
 return <section className="mx-auto flex max-w-5xl flex-col gap-6">
  <Link href={`/items/${id}?${new URLSearchParams({startsAt:period.startsAt??'',endsAt:period.endsAt??''})}`} className="w-fit text-sm font-medium text-muted-foreground hover:text-foreground">← 물품으로 돌아가기</Link>
  <header><p className="mb-2 text-sm font-semibold text-primary">예약 요청</p><h1 className="text-3xl font-bold tracking-tight">언제 필요하세요?</h1><p className="mt-2 text-muted-foreground">기간과 예상 금액을 확인한 뒤 예약을 요청하세요. 지금 결제되지는 않습니다.</p></header>
  <Failure error={item.error}/>{item.isPending?<p role="status">물품 정보를 불러오고 있습니다.</p>:null}{item.isError?<Button variant="outline" onClick={()=>void item.refetch()}>물품 다시 불러오기</Button>:!item.isPending&&!item.data?<div className="rounded-2xl border bg-card p-6"><h2 className="font-semibold">지금 예약할 수 없는 물품이에요</h2><p className="mt-2 text-sm text-muted-foreground">물품이 숨겨졌거나 더 이상 제공되지 않을 수 있습니다.</p><Button asChild className="mt-4"><Link href="/items">다른 물품 찾기</Link></Button></div>:null}
  {saved&&!item.data?<section className="rounded-2xl border border-primary/20 bg-primary/5 p-5"><h2 className="font-semibold">이전 예약 요청의 결과를 확인해 주세요</h2><p className="mt-2 text-sm leading-6">현재 물품 정보를 불러오지 못해도 이미 보낸 예약 요청은 이어서 확인할 수 있습니다.</p><p className="my-4 text-sm">{formatKoreaTime(saved.p_starts_at)} → {formatKoreaTime(saved.p_ends_at)}</p><Button disabled={request.isPending||!recoveryReady} onClick={()=>request.mutate({startsAt:'',endsAt:''})}>{request.isPending?'예약 확인 중…':'예약 결과 다시 확인'}</Button><Failure error={request.error}/></section>:null}
  {!item.data&&recoveryError?<div><Failure error={recoveryError}/><Button variant="outline" onClick={()=>setRecoveryAttempt(value=>value+1)}>저장된 요청 다시 확인</Button></div>:null}
  {item.data?<form onSubmit={submit} className="grid gap-6 lg:grid-cols-[1fr_340px]">
   <div className="flex min-w-0 flex-col gap-5">
    <div className="flex items-center gap-4 rounded-2xl border bg-card p-4">{item.data.photos?.[0]?<img src={item.data.photos[0]} alt="" className="size-16 rounded-xl object-cover"/>:null}<div className="min-w-0"><h2 className="font-semibold">{item.data.title}</h2><p className="mt-1 text-sm text-muted-foreground">{item.data.pickup_area} · 직접 전달</p><p className="mt-1 text-sm">{formatWon(item.data.daily_price)} / 24시간</p></div></div>
    {saved?<section role="status" className="rounded-2xl border border-primary/30 bg-primary/5 p-5"><h2 className="font-semibold">이전 예약 요청을 먼저 확인해 주세요</h2><p className="mt-2 text-sm leading-6">중복 예약을 막기 위해 이전 요청의 결과를 확인합니다. 확인이 끝날 때까지 기간은 바뀌지 않습니다.</p><p className="mt-3 font-medium">{formatKoreaTime(saved.p_starts_at)} → {formatKoreaTime(saved.p_ends_at)}</p></section>:<>
     {availability.isPending?<p role="status" className="rounded-2xl bg-muted p-5">예약 가능한 날짜를 확인하고 있습니다.</p>:null}
     <Failure error={availability.error}/>{availability.isError?<Button type="button" variant="outline" onClick={()=>void availability.refetch()}>예약 가능 시간 다시 불러오기</Button>:null}
     {availability.data?<RentalCalendar startsAt={period.startsAt??''} endsAt={period.endsAt??''} slots={availability.data} availableFrom={item.data.available_from} availableTo={item.data.available_to} disabled={busy} onSelect={selectDay}/>:null}
     <FieldGroup className="grid gap-4 sm:grid-cols-2">{(['startsAt','endsAt'] as const).map(name=><Controller key={name} name={name} control={form.control} render={({field})=><Field data-invalid={!!form.formState.errors[name]}><FieldLabel htmlFor={name}>{name==='startsAt'?'받는 날짜와 시간':'반납 날짜와 시간'}</FieldLabel><Input {...field} id={name} type="datetime-local" disabled={busy} aria-invalid={!!form.formState.errors[name]} aria-describedby={`${name}-error`} onChange={event=>update(name,event.target.value)}/><FieldError id={`${name}-error`} errors={[form.formState.errors[name]]}/></Field>}/>)}</FieldGroup>
     {conflict?<p role="alert" className="rounded-xl border border-destructive/30 bg-destructive/5 p-4 text-sm text-destructive">{conflict}</p>:estimate&&availability.data?<p role="status" className="text-sm font-medium text-primary">선택한 기간에 확정된 예약이 없습니다. 최종 가능 여부는 요청할 때 확인합니다.</p>:null}
     {availability.data?.length?<details className="rounded-xl border bg-card p-4"><summary className="cursor-pointer text-sm font-semibold">이미 예약된 시간 {availability.data.length}건</summary><ul className="mt-3 flex flex-col gap-2 text-sm text-muted-foreground">{availability.data.map((slot,index)=><li key={index}>{formatKoreaTime(slot.starts_at)} → {formatKoreaTime(slot.ends_at)}</li>)}</ul></details>:null}
     <p className="text-xs leading-5 text-muted-foreground">한국 시간 기준 · 24시간 미만은 1일 요금이며, 초과 시간은 하루 단위로 올림합니다.</p>
    </>}
   </div>
   <aside className="h-fit rounded-2xl border bg-card p-5 lg:sticky lg:top-24">
    <h2 className="text-lg font-semibold">{saved?'예약 결과 확인':'예상 결제 금액'}</h2>
    {!saved?<div aria-live="polite" className="mt-5">{estimate?<section aria-label="예상 결제 금액"><dl className="grid grid-cols-2 gap-y-3 text-sm"><dt>대여료 · {estimate.days}일</dt><dd className="text-right">{formatWon(estimate.fee)}</dd><dt>반환 예정 보증금</dt><dd className="text-right">{formatWon(estimate.deposit)}</dd><dt className="mt-2 border-t pt-4 font-semibold">총 결제액</dt><dd className="mt-2 border-t pt-4 text-right text-xl font-bold">{formatWon(estimate.total)}</dd></dl></section>:<p className="rounded-xl bg-muted p-4 text-sm text-muted-foreground">받는 시간과 반납 시간을 선택하면 금액이 표시됩니다.</p>}<p className="mt-4 text-xs leading-5 text-muted-foreground">보증금은 반납 확인 후 반환됩니다. 최종 금액은 예약 요청 시 확정됩니다.</p></div>:null}
    <ol className="my-5 flex flex-col gap-2 border-t pt-5 text-sm text-muted-foreground"><li><span className="mr-2 font-semibold text-foreground">1</span>기간 선택 후 예약 요청</li><li><span className="mr-2 font-semibold text-foreground">2</span>빌려주는 분이 수락</li><li><span className="mr-2 font-semibold text-foreground">3</span>결제하면 예약 확정</li></ol>
    {owner&&!saved?<p className="rounded-xl bg-muted p-4 text-sm">내가 등록한 물품입니다. 다른 물품을 선택해 주세요.</p>:item.data.status!=='active'&&!saved?<div className="flex flex-col gap-3"><p className="rounded-xl bg-muted p-4 text-sm">현재 새 예약을 받지 않는 물품입니다.</p><Button asChild variant="outline"><Link href="/items">다른 물품 찾기</Link></Button></div>:<Button className="w-full" disabled={blocked}>{request.isPending?'예약 확인 중…':saved?'예약 결과 다시 확인':!session?'로그인하고 예약 요청':!prerequisites?'거래 이용 준비하고 계속':'예약 요청'}</Button>}
    {!session?<p className="mt-3 text-xs text-muted-foreground">선택한 기간은 로그인 후에도 이어집니다.</p>:null}
    <Failure error={recoveryError??request.error??consent.error??profile.error}/>
    {recoveryError?<Button type="button" variant="outline" className="mt-3 w-full" onClick={()=>setRecoveryAttempt(value=>value+1)}>저장된 요청 다시 확인</Button>:null}
    {consent.isError||profile.isError?<Button type="button" variant="outline" className="mt-3 w-full" onClick={()=>{void consent.refetch();void profile.refetch();}}>계정 정보 다시 확인</Button>:null}
   </aside>
  </form>:null}
 </section>;
}
