import {useState} from 'react';
import {Alert,Linking,Text,View,Switch} from 'react-native';
import {router} from 'expo-router';
import {useInfiniteQuery,useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {api,client} from './client';
import {useSession} from './session';
import {Button,Field,ErrorText,s} from './ui';
export function AccountSettings() {
 const {session}=useSession();const queries=useQueryClient();const [nickname,setNickname]=useState('');const [confirmed,setConfirmed]=useState(false);
 const consent=useQuery({queryKey:['consent',session?.user.id],queryFn:api.consentStatus});
 const blocks=useInfiniteQuery({queryKey:['blocked-users',session?.user.id],queryFn:({pageParam})=>api.blockedUsers(pageParam),initialPageParam:0,getNextPageParam:(rows,_pages,offset)=>rows.length===50?offset+50:undefined});
 const change=useMutation({mutationFn:()=>api.updateProfile({nickname}),onSuccess:()=>{void queries.invalidateQueries({queryKey:['profile']});Alert.alert('변경했습니다','닉네임을 변경했습니다.');}});
 const agree=useMutation({mutationFn:()=>{if(!consent.data)throw {code:'SERVICE_UNAVAILABLE'};return api.recordConsent({termsVersion:consent.data.termsVersion,privacyVersion:consent.data.privacyVersion});},onSuccess:()=>queries.invalidateQueries({queryKey:['consent']})});
 const unblock=useMutation({mutationFn:(id:string)=>api.blockUser(id,false),onSuccess:()=>queries.invalidateQueries({queryKey:['blocked-users']})});
 const close=useMutation({mutationFn:api.closeAccount,onSuccess:async()=>{const {error}=await client.auth.signOut({scope:'local'});queries.clear();if(error)throw error;router.replace('/account');}});
 const terms=process.env.EXPO_PUBLIC_TERMS_URL,privacy=process.env.EXPO_PUBLIC_PRIVACY_URL;
 const open=useMutation({mutationFn:(url:string)=>Linking.openURL(url)});
 return <View style={{gap:16}}>
  <Button label="내 물품 관리" secondary onPress={()=>router.push('/items/mine')}/><Button label="메시지·알림" secondary onPress={()=>router.push('/notifications')}/><Button label="대여료 지급 내역·계좌" secondary onPress={()=>router.push('/payouts')}/><Button label="비밀번호 변경" secondary onPress={()=>router.push('/auth/password')}/>
  <Button label="고객 문의·처리 내역" secondary onPress={()=>router.push('/support')}/>
  <Field label="새 닉네임" value={nickname} onChangeText={setNickname} maxLength={30}/><Button label="닉네임 변경" disabled={change.isPending||nickname.trim().length<2} onPress={()=>change.mutate()}/>
  {!consent.data?.accepted?<><Text style={s.heading}>거래 이용 동의</Text>{terms&&privacy?<><Button label="이용약관 보기" secondary onPress={()=>open.mutate(terms)}/><Button label="개인정보 처리 안내 보기" secondary onPress={()=>open.mutate(privacy)}/><Text style={s.body}>내용을 확인하고 동의합니다.</Text><Switch accessibilityLabel="거래 이용 동의" value={confirmed} onValueChange={setConfirmed}/><Button label="동의하고 거래 이용하기" disabled={!confirmed||agree.isPending} onPress={()=>agree.mutate()}/></>:<Text style={s.body}>거래 이용 안내를 준비하고 있습니다. 잠시 후 다시 확인해 주세요.</Text>}</>:null}
  <Text style={s.heading}>차단 관리</Text>{blocks.data?.pages.flat().map(user=><Button key={user.id} label={`${user.nickname} 차단 해제`} secondary disabled={unblock.isPending} onPress={()=>unblock.mutate(user.id)}/>)}
  {blocks.data?.pages[0].length===0?<Text style={s.body}>차단한 사용자가 없습니다.</Text>:null}{blocks.hasNextPage?<Button label="차단한 사용자 더 보기" secondary disabled={blocks.isFetchingNextPage} onPress={()=>void blocks.fetchNextPage()}/>:null}
  <Button label="회원 탈퇴" secondary disabled={close.isPending} onPress={()=>Alert.alert('탈퇴하시겠습니까?','진행 중 거래나 미지급 대여료가 있으면 먼저 처리해야 합니다. 탈퇴 후 계정은 복구할 수 없으며 필요한 거래 기록은 보존됩니다.',[{text:'취소',style:'cancel'},{text:'탈퇴',style:'destructive',onPress:()=>close.mutate()}])}/>
  <ErrorText error={change.error??agree.error??close.error??consent.error??blocks.error??unblock.error??open.error}/>
 </View>;
}
