import {useState} from 'react';
import {Platform, Pressable, Text, View} from 'react-native';
import {useMutation} from '@tanstack/react-query';
import {client} from './client';
import {emailLoginInput, emailSignupInput} from './email-auth-input';
import {Button, ErrorText, Field, ValidationText, s} from './ui';

const redirectTo = () => Platform.OS === 'web' ? `${window.location.origin}/auth/callback` : 'dolpin://auth/callback';

export function EmailAuth() {
  const [mode, setMode] = useState<'login' | 'signup'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [errors, setErrors] = useState<Record<string,string>>({});
  const [pendingEmail, setPendingEmail] = useState<string>();
  const [notice, setNotice] = useState('');
  const [resendAfter, setResendAfter] = useState(0);
  const auth = useMutation({mutationFn: async (input: {email:string; password:string; mode:'login'|'signup'}) => {
    if(input.mode === 'login') {
      const {error} = await client.auth.signInWithPassword({email:input.email,password:input.password});
      if(error) throw error;
    } else {
      const {data,error} = await client.auth.signUp({email:input.email,password:input.password,options:{emailRedirectTo:redirectTo()}});
      if(error) throw error;
      if(!data.session) {
        setPendingEmail(input.email);
        setNotice('확인 메일을 보냈습니다. 메일의 링크로 가입을 확인해 주세요. 이미 가입한 이메일이라면 로그인해 주세요.');
        setResendAfter(Date.now()+60000);
        setMode('login');
      }
    }
    // Passwords stay in component memory only and are cleared after success.
    setPassword(''); setConfirmation('');
  }, onError: (error,input) => {
    if('code' in error && error.code==='email_not_confirmed') setPendingEmail(input.email);
  }});
  const resend = useMutation({mutationFn: async () => {
    if(!pendingEmail) return;
    if(Date.now()<resendAfter) {setNotice('확인 메일을 보낸 지 얼마 되지 않았습니다. 잠시 후 다시 시도해 주세요.');return;}
    const {error} = await client.auth.resend({type:'signup',email:pendingEmail,options:{emailRedirectTo:redirectTo()}});
    if(error) throw error;
    setNotice('확인 메일을 다시 보냈습니다. 받은편지함과 스팸함을 확인해 주세요.');
    setResendAfter(Date.now()+60000);
  }});
  const busy=auth.isPending||resend.isPending;
  function submit() {
    if(busy) return;
    const input=(mode==='signup'?emailSignupInput:emailLoginInput).safeParse({email,password,confirmation});
    if(!input.success) {setErrors(Object.fromEntries(input.error.issues.map(issue=>[String(issue.path[0]),issue.message])));return;}
    setErrors({});setNotice('');
    auth.mutate({...input.data,mode});
  }
  function switchMode() {
    if(busy) return;
    setMode(mode==='login'?'signup':'login');setPassword('');setConfirmation('');setErrors({});auth.reset();resend.reset();
  }
  return <View style={{gap:16}}>
    <Text style={s.heading}>{mode==='login'?'이메일로 로그인':'이메일 회원가입'}</Text>
    <Field label="이메일" placeholder="name@example.com" value={email} onChangeText={value=>{setEmail(value);setPendingEmail(undefined);setNotice('');}} keyboardType="email-address" autoComplete="email" autoCapitalize="none" autoCorrect={false} editable={!busy}/>
    <ValidationText error={errors.email}/>
    <Field label="비밀번호" placeholder={mode==='signup'?'8자 이상 입력해 주세요':'비밀번호를 입력해 주세요'} value={password} onChangeText={setPassword} secureTextEntry autoCapitalize="none" autoCorrect={false} autoComplete={mode==='signup'?'new-password':'current-password'} editable={!busy} onSubmitEditing={mode==='login'?submit:undefined}/>
    <ValidationText error={errors.password}/>
    {mode==='signup'?<><Field label="비밀번호 확인" value={confirmation} onChangeText={setConfirmation} secureTextEntry autoCapitalize="none" autoCorrect={false} autoComplete="new-password" editable={!busy} onSubmitEditing={submit}/><ValidationText error={errors.confirmation}/></>:null}
    <Button label={auth.isPending?'처리 중':mode==='login'?'이메일 로그인':'가입하기'} onPress={submit} disabled={busy}/>
    <ErrorText error={auth.error??resend.error}/>
    {notice?<Text accessibilityRole="alert" style={s.body}>{notice}</Text>:null}
    {pendingEmail?<Button label="확인 메일 다시 받기" secondary disabled={busy} onPress={()=>resend.mutate()}/>:null}
    <Pressable accessibilityRole="button" disabled={busy} onPress={switchMode} style={{paddingVertical:10}}><Text style={[s.body,{textAlign:'center'}]}>{mode==='login'?'처음이신가요? 이메일로 가입하기':'이미 계정이 있나요? 로그인하기'}</Text></Pressable>
  </View>;
}
