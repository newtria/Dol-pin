import {SocialButtons} from '../src/social-buttons';
import {signInWithSocial} from '../src/oauth';
import {useState} from 'react';
import {Pressable, ScrollView, Text, View} from 'react-native';
import {Controller, useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation, useQuery, useQueryClient} from '@tanstack/react-query';
import {phoneInput} from '@dolpin/contracts';
import {client, api} from '../src/client';
import {useSession} from '../src/session';
import {Button, Field, ErrorText, s} from '../src/ui';

export default function Account() {
  const {session, ready} = useSession();
  const [sentPhone, setSentPhone] = useState<string>();
  const [phoneOpen, setPhoneOpen] = useState(false);
  const [token, setToken] = useState('');
  const [nickname, setNickname] = useState('');
  const queries = useQueryClient();
  const form = useForm({resolver: zodResolver(phoneInput), defaultValues: {phone: '+82'}});
  const profile = useQuery({queryKey: ['profile', session?.user.id], queryFn: () => api.profile(session!.user.id), enabled: !!session});
  const oauth = useMutation({mutationFn: signInWithSocial});
  const send = useMutation({mutationFn: async ({phone}: {phone: string}) => {
    const {error} = await client.auth.signInWithOtp({phone}); if (error) throw error; setSentPhone(phone);
  }});
  const verify = useMutation({mutationFn: async () => {
    const {error} = await client.auth.verifyOtp({phone: sentPhone!, token, type: 'sms'}); if (error) throw error;
  }});
  const logout = useMutation({mutationFn: async () => {const {error} = await client.auth.signOut(); if (error) throw error; setSentPhone(undefined); setToken('');}});
  const createProfile = useMutation({mutationFn: () => api.ensureProfile(nickname), onSuccess: () => queries.invalidateQueries({queryKey: ['profile', session?.user.id]})});
  return <ScrollView contentContainerStyle={{paddingHorizontal:28,paddingTop:32,paddingBottom:40,flexGrow:1}} keyboardShouldPersistTaps="handled">
    {session ? <Text style={[s.title,{marginBottom:24}]}>내 계정</Text> : null}
    {!ready ? <Text style={s.muted}>계정을 확인하고 있습니다.</Text> : session ? <View style={{gap: 20}}>
      <Text style={s.body}>{profile.data?.nickname ?? '로그인되었습니다.'}</Text>
      <Text style={s.muted}>{session.user.phone}</Text>
      {!profile.isPending && !profile.data ? <><Field label="닉네임" value={nickname} onChangeText={setNickname}/><Button label="프로필 만들기" onPress={() => createProfile.mutate()} disabled={nickname.trim().length < 2 || createProfile.isPending}/></> : null}
      <Button label="로그아웃" onPress={() => logout.mutate()} disabled={logout.isPending}/>
      <ErrorText error={profile.error ?? logout.error ?? createProfile.error}/>
    </View> : <View style={{width:'100%',maxWidth:340,alignSelf:'center',flex:1}}>
      <View style={{paddingTop:12,paddingBottom:36,gap:12}}>
        <Text style={{color:'#F5F5F5',fontSize:18,fontWeight:'800',letterSpacing:-0.6}}>dol-pin</Text>
        <Text style={{color:'#F5F5F5',fontSize:32,fontWeight:'700',letterSpacing:-1.2,lineHeight:41,marginTop:16}}>콘서트 준비,{'\n'}가볍게 시작하세요.</Text>
        <Text style={{color:'#98989F',fontSize:15,lineHeight:23}}>내 계정으로 로그인하고{ '\n'}필요한 물품을 빌려보세요.</Text>
      </View>
      <SocialButtons onPress={provider=>oauth.mutate(provider)} disabled={oauth.isPending}/>
      <ErrorText error={oauth.error}/>
      <View style={{marginTop:28,paddingTop:24,borderTopWidth:1,borderTopColor:'#29292C'}}>
        <Pressable accessibilityRole="button" accessibilityState={{expanded:phoneOpen}} onPress={()=>setPhoneOpen(!phoneOpen)} style={{paddingVertical:10}}>
          <Text style={{textAlign:'center',color:'#B5B5BC',fontSize:14}}>{phoneOpen?'전화번호 로그인 닫기':'전화번호로 로그인'}</Text>
        </Pressable>
      </View>
      {phoneOpen ? <View style={{gap:16,paddingTop:20}}>
      <Controller control={form.control} name="phone" render={({field: {value, onChange}}) => <Field label="전화번호" value={value} onChangeText={onChange} keyboardType="phone-pad" autoComplete="tel"/>}/>
      <ErrorText error={form.formState.errors.phone?.message}/>
      <Button label="인증번호 받기" onPress={form.handleSubmit(v => send.mutate(v))} disabled={send.isPending}/>
      {sentPhone ? <><Field label="인증번호" value={token} onChangeText={setToken} keyboardType="number-pad" autoComplete="sms-otp"/><Button label="로그인" onPress={() => verify.mutate()} disabled={verify.isPending || token.length !== 6}/></> : null}
      <ErrorText error={send.error ?? verify.error}/>
      </View> : null}
    </View>}
  </ScrollView>;
}
