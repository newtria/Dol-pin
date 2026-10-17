import {EmailAuth} from '../src/email-auth';
import {AccountSettings} from '../src/account-settings';
import {disablePush} from '../src/push';
import {SocialButtons} from '../src/social-buttons';
import {signInWithSocial} from '../src/oauth';
import {useEffect,useState} from 'react';
import {router,useFocusEffect,type Href} from 'expo-router';
import {useCallback} from 'react';
import {authReturn,clearAuthReturn} from '../src/auth-return';
import {Alert, Pressable, ScrollView, Text, View} from 'react-native';
import {Controller, useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation, useQuery, useQueryClient} from '@tanstack/react-query';
import {phoneInput} from '@dolpin/contracts';
import {client, api} from '../src/client';
import {useSession} from '../src/session';
import {useSessionPersistence} from '../src/session-storage';
import {Button,ValidationText, Field, ErrorText, Section, s,colors} from '../src/ui';

export default function Account() {
  const {session, ready} = useSession();
  const persistent = useSessionPersistence();
  const [focused,setFocused]=useState(false);
  const [returnTo,setReturnTo]=useState<Href|null>(null);
  const requiresSetup=typeof returnTo==='string'&&/^\/(?:rentals\/new|items\/new)(?:\?|$)/.test(returnTo);
  useFocusEffect(useCallback(()=>{let active=true;setFocused(true);void authReturn().then(path=>{if(active)setReturnTo(path);});return()=>{active=false;setFocused(false);};},[]));
  const consent=useQuery({queryKey:['consent',session?.user.id],queryFn:api.consentStatus,enabled:!!session});
  const [emailBusy, setEmailBusy] = useState(false);
  const [sentPhone, setSentPhone] = useState<string>();
  const [phoneOpen, setPhoneOpen] = useState(false);
  const [token, setToken] = useState('');
  const [nickname, setNickname] = useState('');
  const queries = useQueryClient();
  const form = useForm({resolver: zodResolver(phoneInput), defaultValues: {phone: '+82'}});
  const profile = useQuery({queryKey: ['profile', session?.user.id], queryFn: () => api.profile(session!.user.id), enabled: !!session});
  useEffect(()=>{if(focused&&session&&returnTo&&(!requiresSetup||profile.data&&consent.data?.accepted)){const destination=returnTo;setReturnTo(null);void clearAuthReturn().then(()=>router.replace(destination));}},[focused,session,profile.data,consent.data?.accepted,returnTo,requiresSetup]);
  const oauth = useMutation({mutationFn: signInWithSocial});
  const send = useMutation({mutationFn: async ({phone}: {phone: string}) => {
    const {error} = await client.auth.signInWithOtp({phone}); if (error) throw error; setSentPhone(phone);
  }});
  const verify = useMutation({mutationFn: async () => {
    const {error} = await client.auth.verifyOtp({phone: sentPhone!, token, type: 'sms'}); if (error) throw error;
  }});
  const logout = useMutation({mutationFn: async () => {
    let pushFailed=false;
    try {await disablePush();} catch {pushFailed=true;}
    const {error} = await client.auth.signOut(); if (error) throw error;
    setSentPhone(undefined); setToken('');setNickname('');setPhoneOpen(false);setReturnTo(null);
    if(pushFailed)Alert.alert('로그아웃했습니다','기기 알림 해제를 확인하지 못했습니다. 공용 기기라면 기기 설정에서 dol-pin 알림을 꺼 주세요.');
  }});
  const createProfile = useMutation({mutationFn: () => api.ensureProfile(nickname), onSuccess: () => queries.invalidateQueries({queryKey: ['profile', session?.user.id]})});
  const authBusy=emailBusy||oauth.isPending||send.isPending||verify.isPending;
  return <ScrollView contentContainerStyle={{paddingHorizontal:28,paddingTop:32,paddingBottom:40,flexGrow:1}} keyboardShouldPersistTaps="handled" automaticallyAdjustKeyboardInsets keyboardDismissMode="on-drag">
    {session ? <Text style={[s.title,{marginBottom:24}]}>내 정보</Text> : null}
    {returnTo?<View style={[s.card,{marginBottom:20}]}><Text style={s.heading}>하던 작업을 이어갈게요</Text><Text style={s.muted}>{session?requiresSetup?'프로필과 거래 이용 동의를 완료하면 선택한 화면으로 돌아갑니다.':'이전 화면으로 돌아갑니다.':'로그인하면 선택한 날짜와 함께 이전 화면으로 돌아갑니다.'}</Text><Button label="이어서 진행하지 않고 내 정보 보기" secondary onPress={()=>{setReturnTo(null);void clearAuthReturn();}}/></View>:null}
    {!persistent?<Text accessibilityRole="alert" style={s.muted}>이 기기에 로그인을 저장하지 못했습니다. 앱을 다시 열면 로그인해야 할 수 있습니다.</Text>:null}
    {!ready ? <Text style={s.muted}>계정을 확인하고 있습니다.</Text> : session ? <View style={{gap: 20}}>
      <Text style={s.body}>{profile.data?.nickname ?? '로그인되었습니다.'}</Text>
      <Text style={s.muted}>{session.user.email ?? session.user.phone}</Text>
      {!profile.isPending && !profile.isError && !profile.data ? <><Field label="닉네임" value={nickname} onChangeText={setNickname}/><Button label="프로필 만들기" onPress={() => createProfile.mutate()} disabled={nickname.trim().length < 2 || createProfile.isPending}/></> : null}
      <ErrorText error={profile.error ?? consent.error ?? logout.error ?? createProfile.error}/>
      {profile.data?<AccountSettings key={session.user.id}/>:null}
      <Button label="로그아웃" secondary onPress={() => logout.mutate()} disabled={logout.isPending}/>
    </View> : <View style={{width:'100%',maxWidth:340,alignSelf:'center',flex:1}}>
      <View style={{paddingTop:12,paddingBottom:36,gap:12}}>
        <Text style={{color:colors.text,fontSize:18,fontWeight:'800',letterSpacing:-0.6}}>dol-pin</Text>
        <Text style={{color:colors.text,fontSize:32,fontWeight:'700',letterSpacing:-1.2,lineHeight:41,marginTop:16}}>콘서트 준비,{'\n'}가볍게 시작하세요.</Text>
        <Text style={{color:colors.muted,fontSize:15,lineHeight:23}}>내 계정으로 로그인하고{ '\n'}필요한 물품을 빌려보세요.</Text>
      </View>
      <EmailAuth disabled={oauth.isPending||send.isPending||verify.isPending} onBusyChange={setEmailBusy}/>
      <View style={{marginTop:24,paddingTop:24,borderTopWidth:1,borderTopColor:colors.border,gap:16}}>
      <Text style={[s.muted,{textAlign:'center'}]}>다른 방법으로 로그인</Text>
      <SocialButtons onPress={provider=>oauth.mutate(provider)} disabled={authBusy}/>
      <ErrorText error={oauth.error}/>
      </View>
      <View style={{marginTop:28,paddingTop:24,borderTopWidth:1,borderTopColor:colors.border}}>
        <Pressable accessibilityRole="button" accessibilityState={{expanded:phoneOpen}} disabled={authBusy} onPress={()=>setPhoneOpen(!phoneOpen)} style={{paddingVertical:10}}>
          <Text style={{textAlign:'center',color:colors.muted,fontSize:14}}>{phoneOpen?'전화번호 로그인 닫기':'전화번호로 로그인'}</Text>
        </Pressable>
      </View>
      {phoneOpen ? <View style={{gap:16,paddingTop:20}}>
      <Controller control={form.control} name="phone" render={({field: {value, onChange}}) => <Field label="전화번호" value={value} onChangeText={onChange} editable={!authBusy} keyboardType="phone-pad" autoComplete="tel"/>}/>
      <ValidationText error={form.formState.errors.phone?.message}/>
      <Button label="인증번호 받기" onPress={form.handleSubmit(v => {if(!authBusy)send.mutate(v);})} disabled={authBusy}/>
      {sentPhone ? <><Field label="인증번호" value={token} onChangeText={value=>setToken(value.replace(/\D/g,''))} maxLength={6} editable={!authBusy} keyboardType="number-pad" autoComplete="sms-otp"/><Button label="로그인" onPress={() => verify.mutate()} disabled={authBusy || !/^\d{6}$/.test(token)}/></> : null}
      <ErrorText error={send.error ?? verify.error}/>
      </View> : null}
    </View>}
  </ScrollView>;
}
