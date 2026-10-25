import {Alert,Text} from 'react-native';
import {router} from 'expo-router';
import {useMutation,useQueryClient} from '@tanstack/react-query';
import {api,client} from './client';
import {useSession} from './session';
import {Button,ErrorText,Section,s} from './ui';

export function AccountClosure(){
 const {session}=useSession();const queries=useQueryClient();
 const close=useMutation({mutationFn:(owner:string)=>api.closeAccount(owner),onSuccess:async(result,owner)=>{
  const {data,error}=await client.auth.getSession();
  if(error)throw error;
  if(data.session?.user.id!==owner)return;
  const signedOut=await client.auth.signOut({scope:'local'});
  if(signedOut.error)throw signedOut.error;
  queries.clear();router.replace({pathname:'/account',params:{closure:result.status}});
 }});
 return <Section title="회원 탈퇴"><Text style={s.muted}>프로필을 만들지 않았어도 탈퇴할 수 있습니다. 진행 중 거래와 미지급 대여료는 먼저 처리해야 합니다. 탈퇴 후 계정은 복구할 수 없으며 필요한 거래·문의 기록은 보존됩니다.</Text><Button label={close.isPending?'처리 중…':'회원 탈퇴'} secondary disabled={!session||close.isPending} onPress={()=>{if(session&&!close.isPending)Alert.alert('회원 탈퇴','탈퇴 후 계정은 복구할 수 없습니다.',[{text:'취소',style:'cancel'},{text:'탈퇴',style:'destructive',onPress:()=>close.mutate(session.user.id)}]);}}/><ErrorText error={close.error}/></Section>;
}
