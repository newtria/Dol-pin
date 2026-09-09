import {signInWithSocial} from '../src/oauth';
import {useState} from 'react';
import {ScrollView, Text, View} from 'react-native';
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
  return <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
    <Text style={s.title}>{session ? '내 계정' : '로그인'}</Text>
    {!ready ? <Text style={s.muted}>계정을 확인하고 있습니다.</Text> : session ? <View style={{gap: 20}}>
      <Text style={s.body}>{profile.data?.nickname ?? '로그인되었습니다.'}</Text>
      <Text style={s.muted}>{session.user.phone}</Text>
      {!profile.isPending && !profile.data ? <><Field label="닉네임" value={nickname} onChangeText={setNickname}/><Button label="프로필 만들기" onPress={() => createProfile.mutate()} disabled={nickname.trim().length < 2 || createProfile.isPending}/></> : null}
      <Button label="로그아웃" onPress={() => logout.mutate()} disabled={logout.isPending}/>
      <ErrorText error={profile.error ?? logout.error ?? createProfile.error}/>
    </View> : <View style={{gap: 20}}>
      <Button label="카카오로 계속하기" onPress={() => oauth.mutate('kakao')} disabled={oauth.isPending}/><Button label="네이버로 계속하기" onPress={() => oauth.mutate('custom:naver')} disabled={oauth.isPending}/>
      <Button label="Google로 계속하기" onPress={() => oauth.mutate('google')} disabled={oauth.isPending}/><Button label="Apple로 계속하기" onPress={() => oauth.mutate('apple')} disabled={oauth.isPending}/>
      <Text style={s.muted}>거래에 사용할 전화번호를 인증해 주세요.</Text>
      <Controller control={form.control} name="phone" render={({field: {value, onChange}}) => <Field label="전화번호" value={value} onChangeText={onChange} keyboardType="phone-pad" autoComplete="tel"/>}/>
      <ErrorText error={form.formState.errors.phone?.message}/>
      <Button label="인증번호 받기" onPress={form.handleSubmit(v => send.mutate(v))} disabled={send.isPending}/>
      {sentPhone ? <><Field label="인증번호" value={token} onChangeText={setToken} keyboardType="number-pad" autoComplete="sms-otp"/><Button label="로그인" onPress={() => verify.mutate()} disabled={verify.isPending || token.length !== 6}/></> : null}
      <ErrorText error={oauth.error ?? send.error ?? verify.error}/>
    </View>}
  </ScrollView>;
}
