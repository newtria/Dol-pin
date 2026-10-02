import {useState} from 'react';
import {ScrollView,Text} from 'react-native';
import {router} from 'expo-router';
import {useMutation} from '@tanstack/react-query';
import {client} from '../../src/client';
import {useSession} from '../../src/session';
import {Button,Field,ErrorText,s} from '../../src/ui';
export default function Password() {
 const {session}=useSession();return <PasswordContents key={session?.user.id??'signed-out'}/>;
}
function PasswordContents(){
 const {session,ready}=useSession();const [email,setEmail]=useState('');const [password,setPassword]=useState('');const [confirmation,setConfirmation]=useState('');const [notice,setNotice]=useState('');const [sentAt,setSentAt]=useState(0);
 const send=useMutation({mutationFn:async()=>{if(Date.now()-sentAt<60000)return;const {error}=await client.auth.resetPasswordForEmail(email.trim(),{redirectTo:'dolpin://auth/callback?recovery=1'});if(error)throw error;setSentAt(Date.now());setNotice('가입된 이메일이라면 재설정 메일을 보냈습니다. 이 기기에서 메일 링크를 열어 주세요.');}});
 const save=useMutation({mutationFn:async()=>{if(password.length<8||password.length>72||password!==confirmation)throw new Error('비밀번호를 확인해 주세요.');const {error}=await client.auth.updateUser({password});if(error)throw error;setPassword('');setConfirmation('');setNotice('비밀번호를 변경했습니다.');}});
 return <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled"><Text style={s.title}>비밀번호 {session?'변경':'재설정'}</Text>{!ready?<Text style={s.body}>계정을 확인하고 있습니다.</Text>:session?<><Field label="새 비밀번호 (8~72자)" value={password} onChangeText={setPassword} secureTextEntry autoComplete="new-password" maxLength={72}/><Field label="새 비밀번호 확인" value={confirmation} onChangeText={setConfirmation} secureTextEntry autoComplete="new-password"/><Button label="비밀번호 저장" disabled={save.isPending||password.length<8||password!==confirmation} onPress={()=>save.mutate()}/></>:<><Field label="가입한 이메일" value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" autoComplete="email"/><Button label="재설정 메일 보내기" disabled={send.isPending||!email.includes('@')} onPress={()=>send.mutate()}/></>}<ErrorText error={save.error??send.error}/>{notice?<Text style={s.body}>{notice}</Text>:null}<Button label="계정으로 돌아가기" secondary onPress={()=>router.replace('/account')}/></ScrollView>;
}
