import {pendingRentals} from '../../src/pending-rentals';
import {type RentalRequest} from '@dolpin/api-client';
import {useEffect,useState} from 'react';
import {ScrollView,Text} from 'react-native';
import {router,useLocalSearchParams} from 'expo-router';
import {randomUUID} from 'expo-crypto';
import {Controller,useForm,useWatch} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {rentalEstimate,rentalPeriodInput,koreaTime,formatWon,formatKoreaTime} from '@dolpin/contracts';
import {api} from '../../src/client';
import {useRentalDrafts} from '../../src/rental-drafts';
import {useSession} from '../../src/session';
import {Field,Button,ValidationText,ErrorText,s} from '../../src/ui';
export default function RequestRental() {
 const {itemId}=useLocalSearchParams<{itemId:string}>(); const {session}=useSession();
 const queries=useQueryClient(); const draft=useRentalDrafts.getState().drafts[itemId]; const [recovery,setRecovery]=useState<{owner:string;item:string;request:RentalRequest|null}>(); const [recoveryError,setRecoveryError]=useState<unknown>();
 const item=useQuery({queryKey:['item',itemId],queryFn:()=>api.item(itemId)});
 const form=useForm({resolver:zodResolver(rentalPeriodInput),defaultValues:{startsAt:draft?.startsAt??'',endsAt:draft?.endsAt??''}});
 const period=useWatch({control:form.control});
 const estimate=item.data?rentalEstimate(period.startsAt??'',period.endsAt??'',item.data.daily_price,item.data.deposit):null;
 const recoveryReady=!!session&&recovery?.owner===session.user.id&&recovery.item===itemId;
 const saved=recoveryReady?recovery.request:null;
 useEffect(()=>{
  let active=true;setRecovery(undefined);setRecoveryError(undefined);
  if(session)void pendingRentals.read(session.user.id,itemId).then(request=>{
    if(active)setRecovery({owner:session.user.id,item:itemId,request});
  }).catch(error=>{if(active)setRecoveryError(error);});
  return ()=>{active=false;};
 },[session?.user.id,itemId]);
 const request=useMutation({mutationFn:async(v:{startsAt:string;endsAt:string})=>{
  if(!session||!recoveryReady)throw new Error('저장된 요청을 확인하고 있습니다.');
  if(!saved&&!item.data?.updated_at)throw new Error('상품을 다시 확인해 주세요.');
  const owner=session.user.id;
  const input=saved??{p_item_id:itemId,p_starts_at:koreaTime(v.startsAt),p_ends_at:koreaTime(v.endsAt),p_item_version:item.data!.updated_at!,p_request_id:randomUUID()};
  setRecovery({owner,item:itemId,request:input});
  try {return await pendingRentals.submit(owner,input,api.requestRental);}
  finally {setRecovery({owner,item:itemId,request:await pendingRentals.read(owner,itemId)});}
 },onSuccess:r=>{useRentalDrafts.getState().removeDraft(itemId);void queries.invalidateQueries({queryKey:['rentals']});router.replace(`/rentals/${r.id}`);}});
 if (!session) return <ScrollView contentContainerStyle={s.content}><Text style={s.title}>예약하려면 로그인해 주세요</Text><Button label="로그인" onPress={()=>router.push('/account')}/></ScrollView>;
 return <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
  <Text style={s.title}>대여 기간 선택</Text><Text style={s.heading}>{item.data?.title}</Text>
  {item.data&&!saved?<Text style={s.muted}>{formatWon(item.data.daily_price)} / 24시간 · 보증금 {formatWon(item.data.deposit)}</Text>:null}
  <Text style={s.body}>한국 시간 기준으로 입력해 주세요. 24시간 미만은 1일 요금이며, 반납 시각까지의 이용 시간을 올림해 계산합니다.</Text>
  {saved?<Text style={s.body}>이전 요청의 결과를 확인해 주세요. 확인 전에는 대여 기간을 변경할 수 없습니다.{'\n'}{formatKoreaTime(saved.p_starts_at)} → {formatKoreaTime(saved.p_ends_at)}</Text>:null}
  {!saved?(['startsAt','endsAt'] as const).map(name=><Controller key={name} control={form.control} name={name} render={({field:{value,onChange}})=><><Field label={name==='startsAt'?'시작 일시':'반납 일시'} placeholder="2026-09-20 10:00" value={value} onChangeText={v=>{onChange(v);useRentalDrafts.getState().setDraft(itemId,{...form.getValues(),[name]:v});}} autoCapitalize="none" editable={!request.isPending&&!saved&&recoveryReady}/><ValidationText error={form.formState.errors[name]?.message}/></>}/>):null}
  {estimate&&!saved?<><Text style={s.heading}>예상 결제 금액</Text><Text style={s.body}>대여료 ({estimate.days}일) {formatWon(estimate.fee)}</Text><Text style={s.body}>보증금 {formatWon(estimate.deposit)}</Text><Text style={s.price}>총 결제액 {formatWon(estimate.total)}</Text><Text style={s.muted}>보증금은 반납 확인 후 반환됩니다. 최종 금액은 예약 요청 시 확정됩니다.</Text></>:null}
  <Text style={s.muted}>예약 요청 후 대여자가 수락하면 결제할 수 있습니다. 요청만으로 물품이 확보되지는 않습니다.</Text>
  <Button label={saved?"예약 결과 다시 확인":"예약 요청"} onPress={()=>saved?request.mutate({startsAt:'',endsAt:''}):void form.handleSubmit(v=>request.mutate(v))()} disabled={request.isPending||!recoveryReady||(!saved&&!item.data)}/>
  <ErrorText error={recoveryError??item.error??request.error}/>
 </ScrollView>;
}
