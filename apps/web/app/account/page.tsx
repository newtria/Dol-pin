'use client';
import {useState} from 'react';
import {useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation, useQuery, useQueryClient} from '@tanstack/react-query';
import {phoneInput} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Field, FieldGroup, FieldLabel, FieldError} from '@/components/ui/field';

export default function Account() {
  const {client, api, session, ready} = useApi();
  const [sentPhone, setSentPhone] = useState(''); const [token, setToken] = useState(''); const [nickname, setNickname] = useState('');
  const queries = useQueryClient();
  const form = useForm({resolver: zodResolver(phoneInput), defaultValues: {phone: '+82'}});
  const profile = useQuery({queryKey: ['profile', session?.user.id], queryFn: () => api.profile(session!.user.id), enabled: !!session});
  const send = useMutation({mutationFn: async ({phone}: {phone: string}) => {const {error} = await client.auth.signInWithOtp({phone}); if (error) throw error; setSentPhone(phone);}});
  const verify = useMutation({mutationFn: async () => {const {error} = await client.auth.verifyOtp({phone: sentPhone, token, type: 'sms'}); if (error) throw error;}});
  const logout = useMutation({mutationFn: async () => {const {error} = await client.auth.signOut(); if (error) throw error; setToken(''); setSentPhone('');}});
  const create = useMutation({mutationFn: () => api.ensureProfile(nickname), onSuccess: () => queries.invalidateQueries({queryKey: ['profile', session?.user.id]})});
  if (!ready) return <p>계정을 확인하고 있습니다.</p>;
  return <section className="mx-auto flex max-w-md flex-col gap-8"><h1 className="text-3xl font-bold">{session ? '내 계정' : '전화번호로 로그인'}</h1>
    {session ? <><p>{profile.data?.nickname ?? '로그인되었습니다.'}</p><p className="text-muted-foreground">{session.user.phone}</p>{!profile.isPending && !profile.data ? <FieldGroup><Field><FieldLabel htmlFor="nickname">닉네임</FieldLabel><Input id="nickname" value={nickname} onChange={e => setNickname(e.target.value)}/></Field><Button onClick={() => create.mutate()} disabled={create.isPending || nickname.trim().length < 2}>프로필 만들기</Button></FieldGroup> : null}<Button onClick={() => logout.mutate()} disabled={logout.isPending}>로그아웃</Button><Failure error={profile.error ?? create.error ?? logout.error}/></> : <>
      <p className="text-muted-foreground">거래에 사용할 전화번호를 인증해 주세요.</p>
      <form onSubmit={form.handleSubmit(value => send.mutate(value))}><FieldGroup><Field data-invalid={!!form.formState.errors.phone}><FieldLabel htmlFor="phone">전화번호</FieldLabel><Input id="phone" type="tel" autoComplete="tel" aria-invalid={!!form.formState.errors.phone} {...form.register('phone')}/><FieldError errors={[form.formState.errors.phone]}/></Field><Button type="submit" disabled={send.isPending}>인증번호 받기</Button></FieldGroup></form>
      {sentPhone ? <form onSubmit={e => {e.preventDefault(); verify.mutate();}}><FieldGroup><Field><FieldLabel htmlFor="otp">인증번호</FieldLabel><Input id="otp" inputMode="numeric" autoComplete="one-time-code" value={token} onChange={e => setToken(e.target.value)}/></Field><Button disabled={verify.isPending || token.length !== 6}>로그인</Button></FieldGroup></form> : null}
      <Failure error={send.error ?? verify.error}/>
    </>}
  </section>;
}
