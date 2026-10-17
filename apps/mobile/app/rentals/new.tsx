import {pendingRentals} from '../../src/pending-rentals';
import {DateField} from '../../src/date-field';
import {type RentalRequest} from '@dolpin/api-client';
import {useCallback,useEffect,useRef,useState} from 'react';
import {ScrollView,Text,View} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {router,useFocusEffect,useLocalSearchParams} from 'expo-router';
import {randomUUID} from 'expo-crypto';
import {Controller,useForm,useWatch} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {rentalEstimate,rentalPeriodInput,rentalPeriodConflict,koreaTime,formatWon,formatKoreaTime} from '@dolpin/contracts';
import {api} from '../../src/client';
import {useRentalDrafts} from '../../src/rental-drafts';
import {useExploreState} from '../../src/state';
import {beginSignIn} from '../../src/auth-return';
import {useSession} from '../../src/session';
import {Button,ValidationText,ErrorText,Section,EmptyState,LoadingState,s,colors} from '../../src/ui';
function validLocal(value:string|undefined){try{if(value){koreaTime(value);return value.trim().replace(' ','T');}}catch{}return '';}
export default function RequestRental() {
 const {session}=useSession();const {itemId}=useLocalSearchParams<{itemId:string}>();
 return <RentalRequestContents key={`${session?.user.id??'signed-out'}:${itemId}`}/>;
}
function RentalRequestContents(){
 const {itemId,startsAt,endsAt}=useLocalSearchParams<{itemId:string;startsAt?:string;endsAt?:string}>(); const {session,ready}=useSession();
 const mounted=useRef(false);const focused=useRef(false);
 useFocusEffect(useCallback(()=>{
  focused.current=true;
  return ()=>{focused.current=false;};
 },[]));
 const queries=useQueryClient(); const draft=useRentalDrafts.getState().drafts[itemId]; const [recovery,setRecovery]=useState<{owner:string;item:string;request:RentalRequest|null}>(); const [recoveryError,setRecoveryError]=useState<unknown>();const [recoveryAttempt,setRecoveryAttempt]=useState(0);
 const item=useQuery({queryKey:['item',itemId],queryFn:()=>api.item(itemId)});
 const profile=useQuery({queryKey:['profile',session?.user.id],queryFn:()=>api.profile(session!.user.id),enabled:!!session});
 const consent=useQuery({queryKey:['consent',session?.user.id],queryFn:api.consentStatus,enabled:!!session});
 const availability=useQuery({queryKey:['availability',itemId],queryFn:()=>api.itemAvailability(itemId)});
 const filter=useExploreState.getState();
 const form=useForm({resolver:zodResolver(rentalPeriodInput),defaultValues:{startsAt:validLocal(startsAt)||validLocal(draft?.startsAt)||validLocal(filter.startsAt),endsAt:validLocal(endsAt)||validLocal(draft?.endsAt)||validLocal(filter.endsAt)}});
 const period=useWatch({control:form.control});
 const estimate=item.data?rentalEstimate(period.startsAt??'',period.endsAt??'',item.data.daily_price,item.data.deposit):null;
 const conflict=period.startsAt&&period.endsAt?rentalPeriodConflict(period.startsAt,period.endsAt,availability.data??[],item.data?.available_from,item.data?.available_to):null;
 const recoveryReady=!!session&&recovery?.owner===session.user.id&&recovery.item===itemId;
 const saved=recoveryReady?recovery.request:null;
 useEffect(()=>{
  let active=true;mounted.current=true;setRecovery(undefined);setRecoveryError(undefined);
  if(session)void pendingRentals.read(session.user.id,itemId).then(request=>{
    if(active)setRecovery({owner:session.user.id,item:itemId,request});
  }).catch(error=>{if(active)setRecoveryError(error);});
  return ()=>{active=false;mounted.current=false;};
 },[session?.user.id,itemId,recoveryAttempt]);
 const request=useMutation({mutationFn:async(v:{startsAt:string;endsAt:string})=>{
  if(!session||!recoveryReady)throw new Error('저장된 요청을 확인하고 있습니다.');
  if(!saved){const conflict=rentalPeriodConflict(v.startsAt,v.endsAt,availability.data??[],item.data?.available_from,item.data?.available_to);if(conflict)throw new Error(conflict);}
  if(!saved&&!item.data?.updated_at)throw new Error('상품을 다시 확인해 주세요.');
  const owner=session.user.id;
  const input=saved??{p_item_id:itemId,p_starts_at:koreaTime(v.startsAt),p_ends_at:koreaTime(v.endsAt),p_item_version:item.data!.updated_at!,p_request_id:randomUUID()};
  setRecovery({owner,item:itemId,request:input});
  try {return await pendingRentals.submit(owner,input,request=>{
   if(!mounted.current||!focused.current)throw new Error('저장된 요청을 확인하고 있습니다.');
   return api.requestRental(request);
  });}
  finally {
   if(mounted.current){
    const request=await pendingRentals.read(owner,itemId);
    if(mounted.current)setRecovery({owner,item:itemId,request});
   }
  }
 },onSuccess:r=>{
  if(!mounted.current)return;
  useRentalDrafts.getState().removeDraft(itemId);void queries.invalidateQueries({queryKey:['rentals']});
  if(focused.current)router.replace(`/rentals/${r.id}`);
 }});
 const completedRental=request.isSuccess?request.data:null;
 if(completedRental)return <ScrollView contentContainerStyle={s.content}>
  <Text style={s.title}>예약 요청을 완료했습니다</Text>
  <Text style={s.body}>대여자의 수락 상태는 거래 상세에서 확인해 주세요.</Text>
  <Button label="거래 보기" onPress={()=>router.replace(`/rentals/${completedRental.id}`)}/>
 </ScrollView>;
 const setupReady=!!profile.data&&consent.data?.accepted;
 const own=!!session&&item.data?.lender_id===session.user.id;
 const blocked=!saved&&(own||!item.data||item.data.status!=='active'||availability.isPending||availability.isError||!!conflict||!!session&&(profile.isPending||consent.isPending||profile.isError||consent.isError));
 function submit(){
  if(saved){request.mutate({startsAt:'',endsAt:''});return;}
  void form.handleSubmit(values=>{
   const latestConflict=rentalPeriodConflict(values.startsAt,values.endsAt,availability.data??[],item.data?.available_from,item.data?.available_to);
   if(latestConflict){form.setError('endsAt',{message:latestConflict});return;}
   if(blocked)return;
   useRentalDrafts.getState().setDraft(itemId,values);
   if(session&&setupReady)request.mutate(values);
   else void beginSignIn(`/rentals/new?${new URLSearchParams({itemId,...values})}`);
  })();
 }
 const today=new Date(Date.now()+9*3600000).toISOString().slice(0,10);
 const availableFrom=item.data?.available_from&&item.data.available_from>today?item.data.available_from:today;
 return <View style={s.page}><ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled" automaticallyAdjustKeyboardInsets>
  <View style={{gap:8}}><Text style={s.muted}>1 날짜 선택   →   2 예약 수락   →   3 결제</Text><Text style={s.title}>언제 빌릴까요?</Text><Text style={s.heading}>{item.data?.title}</Text>{item.data&&!saved?<Text style={s.muted}>하루 {formatWon(item.data.daily_price)} · {item.data.pickup_area||'직접 만나서 전달'}</Text>:null}</View>
  {own&&!saved?<Section title="내가 등록한 물품이에요"><Text style={s.body}>내 물품은 예약할 수 없습니다. 대여 조건은 물품 수정에서 바꿀 수 있어요.</Text><Button label="물품 수정" secondary onPress={()=>router.replace(`/items/new?edit=${itemId}`)}/></Section>:null}
  {item.isSuccess&&(!item.data||item.data.status!=='active')&&!saved&&!own?<EmptyState title="지금 예약할 수 없는 물품이에요" body="물품이 숨겨졌거나 대여 조건이 변경되었을 수 있습니다. 다른 물품을 확인해 주세요." action="다른 물품 찾기" onAction={()=>router.replace('/')}/>:null}
  {item.isPending?<LoadingState label="물품과 대여 가능 시간을 확인하고 있어요"/>:null}
  {saved?<Section title="이전 예약 요청 확인"><Text style={s.body}>중복 요청을 막기 위해 먼저 이전 요청의 결과를 확인합니다. 확인 전에는 대여 기간을 변경할 수 없습니다.</Text><Text style={s.heading}>{formatKoreaTime(saved.p_starts_at)} → {formatKoreaTime(saved.p_ends_at)}</Text></Section>:item.data&&!own&&item.data.status==='active'?<Section title="빌릴 시간과 반납 시간" description="한국 시간 기준입니다. 예약된 날짜를 달력에서 함께 확인하세요.">
  {(['startsAt','endsAt'] as const).map(name=><Controller key={name} control={form.control} name={name} render={({field:{value,onChange}})=><View style={{gap:8}}><DateField label={name==='startsAt'?'빌릴 날짜·시간':'반납 날짜·시간'} value={value} onChange={v=>{onChange(v);useRentalDrafts.getState().setDraft(itemId,{...form.getValues(),[name]:v});}} periodEnd={name==='endsAt'} minDate={name==='endsAt'&&period.startsAt&&period.startsAt.slice(0,10)>availableFrom?period.startsAt:availableFrom} maxDate={item.data?.available_to??undefined} blockedPeriods={availability.data??[]} disabled={request.isPending||!!session&&!recoveryReady}/><ValidationText error={form.formState.errors[name]?.message}/></View>}/>) }
  {conflict?<ValidationText error={conflict}/>:period.startsAt&&period.endsAt&&availability.isSuccess?<Text style={{color:colors.primary,lineHeight:22}}>선택한 기간에 겹치는 확정 예약이 없습니다. 요청 시 다시 확인합니다.</Text>:null}
  {availability.isPending?<LoadingState label="대여 가능 시간을 확인하고 있어요"/>:null}
  <ErrorText error={availability.error} onRetry={()=>void availability.refetch()} retrying={availability.isFetching}/>
  </Section>:null}
  {estimate&&!saved&&!own&&item.data?.status==='active'?<Section title="예상 결제 금액"><View style={[s.row,{justifyContent:'space-between'}]}><Text style={s.body}>대여료 · {estimate.days}일</Text><Text style={s.body}>{formatWon(estimate.fee)}</Text></View><View style={[s.row,{justifyContent:'space-between'}]}><Text style={s.body}>돌려받는 보증금</Text><Text style={s.body}>{formatWon(estimate.deposit)}</Text></View><View style={[s.row,{justifyContent:'space-between',borderTopWidth:1,borderTopColor:colors.border,paddingTop:14}]}><Text style={s.heading}>총 결제 예상액</Text><Text style={s.price}>{formatWon(estimate.total)}</Text></View><Text style={s.muted}>24시간 미만은 1일 요금이며 이용 시간을 올림해 계산합니다. 보증금은 반납 확인 후 반환됩니다.</Text></Section>:!saved&&!own&&item.data?.status==='active'?<View style={s.card}><Text style={s.muted}>빌릴 시간과 반납 시간을 고르면 대여료와 보증금을 합한 예상 금액을 바로 확인할 수 있어요.</Text></View>:null}
  <Text style={s.muted}>예약 요청 후 대여자가 수락하면 결제할 수 있습니다. 요청만으로 물품이 확보되지는 않으며, 최종 금액은 요청 시 확정됩니다.</Text>
  {!session?<Text style={s.muted}>로그인 후에도 선택한 기간이 유지됩니다. 지금은 결제되지 않습니다.</Text>:null}
  {!saved?<ErrorText error={profile.error??consent.error} onRetry={()=>{void profile.refetch();void consent.refetch();}}/>:null}
  {recoveryError?<Button label="저장된 요청 다시 확인" secondary onPress={()=>setRecoveryAttempt(value=>value+1)}/>:null}
  <ErrorText error={recoveryError??item.error??request.error} onRetry={item.isError?()=>void item.refetch():undefined}/>
 </ScrollView><SafeAreaView edges={['bottom']} style={{padding:16,paddingTop:12,borderTopWidth:1,borderColor:colors.border,backgroundColor:colors.surface}}><Button label={request.isPending?'예약 확인 중…':saved?'예약 결과 다시 확인':session?setupReady?'이 기간으로 예약 요청':'프로필·동의 완료하고 예약':'로그인하고 예약 이어가기'} onPress={submit} disabled={!ready||request.isPending||!!session&&!recoveryReady||blocked}/></SafeAreaView></View>;
}
