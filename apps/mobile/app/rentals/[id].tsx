import * as WebBrowser from 'expo-web-browser';
import {useFocusEffect} from 'expo-router';
import {useCallback,useState,useEffect} from 'react';
import * as ImagePicker from 'expo-image-picker';
import {ScrollView,Text,Image,View,Alert} from 'react-native';
import {useLocalSearchParams,usePathname} from 'expo-router';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {rentalGuidance,formatKoreaTime,formatWon,rentalStatusLabels,rentalTitle,rentalTerms} from '@dolpin/contracts';
import {api,client} from '../../src/client';
import {useSession} from '../../src/session';
import {Button,ErrorText,s} from '../../src/ui';
export default function Rental(){
 const pathname=usePathname(); const {id}=useLocalSearchParams<{id:string}>(); const {session}=useSession(); const queries=useQueryClient();
 const rental=useQuery({queryKey:['rental',id,session?.user.id],queryFn:()=>api.rental(id),enabled:!!session&&pathname===`/rentals/${id}`,refetchInterval:5000});
 const action=useMutation({mutationFn:(kind:'accept'|'reject'|'cancel')=>api.respondToRental(id,kind),onSettled:()=>{void queries.invalidateQueries({queryKey:['rental',id]});void queries.invalidateQueries({queryKey:['rentals']});}});
 const payment=useMutation({mutationFn:async()=>{const {checkoutUrl}=await api.preparePayment(id,true);await WebBrowser.openBrowserAsync(checkoutUrl);await queries.invalidateQueries({queryKey:['rental',id]});}});
 useFocusEffect(useCallback(()=>{void queries.invalidateQueries({queryKey:['rental',id]});},[id,queries]));
 const [notice,setNotice]=useState('');
 const [photo,setPhoto]=useState<ImagePicker.ImagePickerAsset>();
 const choosePhoto=useMutation({mutationFn:async()=>{const result=await ImagePicker.launchImageLibraryAsync({mediaTypes:['images'],quality:0.8,base64:true});if(!result.canceled)setPhoto(result.assets[0]);}});
 const refresh=()=>{void queries.invalidateQueries({queryKey:['rental',id]});void queries.invalidateQueries({queryKey:['rentals']});};
 const command=useMutation({mutationFn:async(kind:'pickup'|'refund'|'settle'|'recover')=>{
  if(kind==='pickup'){await api.pickupRental(id);return;}
  const result=kind==='recover'?await api.recoverPayment(id):await api.moneyAction(id,kind);
  setNotice(result.status==='processing'?'결제사 결과를 확인 중입니다. 앱을 닫아도 서버에서 계속 확인합니다.':'처리 결과를 반영했습니다.');
 },onSettled:refresh});
 const returnPhoto=useMutation({mutationFn:async()=>{
  if(!session)throw new Error('로그인이 필요합니다.');
  if(!photo)throw new Error('반납 사진을 먼저 선택해 주세요.');
  const asset=photo;if(!asset.base64)throw new Error('사진을 읽지 못했습니다.');
  const bytes=Uint8Array.from(atob(asset.base64),c=>c.charCodeAt(0));const mime=asset.mimeType??'image/jpeg';
  if(bytes.byteLength>5*1024*1024||!['image/jpeg','image/png','image/webp'].includes(mime))throw new Error('5MB 이하 JPG, PNG, WebP 사진을 선택해 주세요.');
  const path=`${id}/${session.user.id}/${Date.now()}-${Math.random().toString(36).slice(2)}.${mime.split('/')[1]}`;
  const {error}=await client.storage.from('rental-evidence').upload(path,bytes.buffer,{contentType:mime});if(error)throw error;
  return api.returnRental(id,path);
 },onSuccess:()=>setPhoto(undefined),onSettled:refresh});
 const r=session?rental.data:undefined;const terms=rentalTerms(r?.terms_snapshot);
 useEffect(()=>{setNotice('');setPhoto(undefined);},[id,session?.user.id,r?.status]);
 const guidance=r?rentalGuidance(r,r.lender_id===session?.user.id):null;
 const recovery=useQuery({queryKey:['payment-recovery',id,session?.user.id],queryFn:()=>api.recoverPayment(id),enabled:!!r&&r.status==='accepted'&&!!r.payment_attempt_merchant_uid&&r.borrower_id===session?.user.id,refetchInterval:5000,retry:false});
 useEffect(()=>{if(recovery.data)void queries.invalidateQueries({queryKey:['rental',id]});},[recovery.dataUpdatedAt,id,queries]);
 const evidence=useQuery({queryKey:['evidence',id,session?.user.id,r?.return_photo],queryFn:()=>api.evidenceUrl(r!.return_photo!),enabled:!!session&&!!r?.return_photo?.startsWith(`${id}/`),staleTime:240000});
 return <ScrollView contentContainerStyle={s.content}><Text style={s.title}>거래 상세</Text><ErrorText error={rental.error??action.error??payment.error??command.error??returnPhoto.error??choosePhoto.error??evidence.error}/>
 {!session?<Text style={s.muted}>거래를 확인하려면 로그인해 주세요.</Text>:rental.isPending?<Text style={s.muted}>거래를 불러오고 있습니다.</Text>:null}
 {r?<><Text style={s.heading}>{rentalTitle(r)}</Text><Text style={s.body}>{rentalStatusLabels[r.status??'']??'상태 확인 필요'}</Text>
 <Text style={s.body}>{r.starts_at?formatKoreaTime(r.starts_at):r.rental_date} → {r.ends_at?formatKoreaTime(r.ends_at):r.return_date}</Text>
 <View style={s.card}><Text style={s.muted}>{r.lender_id===session?.user.id?'빌려주는 거래':'빌리는 거래'}</Text><Text style={s.heading}>{guidance?.title}</Text><Text style={s.body}>{guidance?.body}</Text>{r.status==='accepted'&&r.payment_due_at?<Text style={s.body}>결제 기한 {formatKoreaTime(r.payment_due_at)}</Text>:null}
 {r.status==='requested'&&r.lender_id===session?.user.id?<><Button label="예약 수락" onPress={()=>action.mutate('accept')} disabled={action.isPending}/><Button label="예약 거절" secondary onPress={()=>action.mutate('reject')} disabled={action.isPending}/></>:null}
 {r.status==='requested'&&r.borrower_id===session?.user.id?<Button label="요청 취소" secondary onPress={()=>action.mutate('cancel')} disabled={action.isPending}/>:null}
 {r.status==='accepted'&&(!r.payment_due_at||Date.parse(r.payment_due_at)>Date.now())&&!r.payment_attempt_merchant_uid&&r.borrower_id===session?.user.id?<Button label="결제하기" onPress={()=>payment.mutate()} disabled={payment.isPending}/>:null}
 {notice?<Text style={s.body}>{notice}</Text>:null}
 {r.payment_action?<Text style={s.muted}>환불 결과 확인 중에는 인수·반납을 진행할 수 없습니다.</Text>:null}
 {r.status==='accepted'&&r.payment_attempt_merchant_uid&&r.borrower_id===session?.user.id?<Button label="결제 결과 다시 확인" secondary disabled={command.isPending} onPress={()=>command.mutate('recover')}/>:null}
 {r.status==='paid'&&!r.payment_action&&r.lender_id===session?.user.id?<Button label="물품을 전달했어요" disabled={command.isPending} onPress={()=>command.mutate('pickup')}/>:null}
 {r.status==='paid'?<Button label={r.payment_action?'환불 결과 다시 확인':'거래 취소 · 전액 환불'} secondary disabled={command.isPending} onPress={()=>r.payment_action?command.mutate('refund'):Alert.alert('거래를 취소할까요?',`대여료와 보증금 합계 ${formatWon(r.total_paid)} 전액을 원래 결제 수단으로 환불합니다. 취소 후에는 이 거래로 물품을 받을 수 없습니다.`,[{text:'거래 유지',style:'cancel'},{text:`취소하고 ${formatWon(r.total_paid)} 환불`,style:'destructive',onPress:()=>command.mutate('refund')}])}/>:null}
 {r.status==='picked_up'&&!r.payment_action&&r.borrower_id===session?.user.id?<><Text style={s.muted}>반납 사진은 거래 당사자만 볼 수 있습니다.</Text><Button label={photo?"사진 다시 선택":"반납 사진 선택"} disabled={returnPhoto.isPending||choosePhoto.isPending} onPress={()=>choosePhoto.mutate()}/>{photo?<><Image source={{uri:photo.uri}} accessibilityLabel="제출할 반납 사진" style={{height:240,width:"100%"}} resizeMode="contain"/><Text style={s.body}>실제로 물품을 반납하셨나요? 제출하면 빌려주는 분에게 반납 확인을 요청합니다.</Text><Button label="사진 제거" secondary disabled={returnPhoto.isPending} onPress={()=>setPhoto(undefined)}/><Button label={returnPhoto.isPending?"반납 제출 중…":"반납 제출"} disabled={returnPhoto.isPending} onPress={()=>returnPhoto.mutate()}/></>:null}</>:null}
 {evidence.data?<Image source={{uri:evidence.data}} accessibilityLabel="반납 증빙" style={{height:240,width:'100%'}} resizeMode="contain"/>:null}
 {r.status==='returned'&&r.lender_id===session?.user.id?<Button label={r.payment_action?'보증금 반환 결과 다시 확인':'반납 수령 확인 · 보증금 반환'} disabled={command.isPending} onPress={()=>command.mutate('settle')}/>:null}
 {r.status==='returned'&&r.borrower_id===session?.user.id?<Text style={s.muted}>대여자의 수령 확인 후 보증금을 반환합니다.</Text>:null}
 </View>
 <Text style={s.body}>대여료 {formatWon(r.rental_fee)}</Text><Text style={s.body}>보증금 {formatWon(r.deposit)}</Text><Text style={s.price}>합계 {formatWon(r.total_paid)}</Text>
 {r.terms_snapshot&&r.status!=='requested'?<><Text style={s.heading}>수락한 거래 조건</Text><Text style={s.body}>{terms.description}</Text><Text style={s.body}>인수·반납 장소: {terms.pickupNote||'수락 당시 장소 정보가 없습니다.'}</Text></>:<Text style={s.muted}>거래 조건은 예약 수락 시 확정됩니다.</Text>}

 </>:null}</ScrollView>;
}
