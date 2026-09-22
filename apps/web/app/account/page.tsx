'use client';
import {SocialButtons} from '@/components/social-buttons';
import {EmailAuth} from '@/components/email-auth';
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
  const [phoneOpen,setPhoneOpen]=useState(false);
  const [emailBusy,setEmailBusy]=useState(false);
  const [sentPhone, setSentPhone] = useState(''); const [token, setToken] = useState(''); const [nickname, setNickname] = useState('');
  const queries = useQueryClient();
  const form = useForm({resolver: zodResolver(phoneInput), defaultValues: {phone: '+82'}});
  const profile = useQuery({queryKey: ['profile', session?.user.id], queryFn: () => api.profile(session!.user.id), enabled: !!session});
  const oauth = useMutation({mutationFn: async (provider: 'google' | 'apple' | 'kakao' | 'custom:naver') => {const {error} = await client.auth.signInWithOAuth({provider, options: {redirectTo: `${window.location.origin}/auth/callback`}}); if (error) throw error;}});
  const send = useMutation({mutationFn: async ({phone}: {phone: string}) => {const {error} = await client.auth.signInWithOtp({phone}); if (error) throw error; setSentPhone(phone);}});
  const verify = useMutation({mutationFn: async () => {const {error} = await client.auth.verifyOtp({phone: sentPhone, token, type: 'sms'}); if (error) throw error;}});
  const logout = useMutation({mutationFn: async () => {const {error} = await client.auth.signOut(); if (error) throw error; setToken(''); setSentPhone('');}});
  const create = useMutation({mutationFn: () => api.ensureProfile(nickname), onSuccess: () => queries.invalidateQueries({queryKey: ['profile', session?.user.id]})});
  const authBusy = emailBusy || oauth.isPending || send.isPending || verify.isPending;
  if (!ready) return <p>계정을 확인하고 있습니다.</p>;
  return <section className="mx-auto flex w-full max-w-[340px] flex-col gap-6 pb-12 pt-6">{session ? <h1 className="text-3xl font-bold">내 계정</h1> : null}
    {session ? <><p>{profile.data?.nickname ?? '로그인되었습니다.'}</p><p className="text-muted-foreground">{session.user.email ?? session.user.phone}</p>{!profile.isPending && !profile.error && !profile.data ? <FieldGroup><Field><FieldLabel htmlFor="nickname">닉네임</FieldLabel><Input id="nickname" value={nickname} onChange={e => setNickname(e.target.value)}/></Field><Button onClick={() => create.mutate()} disabled={create.isPending || nickname.trim().length < 2}>프로필 만들기</Button></FieldGroup> : null}<Button onClick={() => logout.mutate()} disabled={logout.isPending}>로그아웃</Button><Failure error={profile.error ?? create.error ?? logout.error}/></> : <>
      <div className="pb-3"><p className="text-lg font-extrabold tracking-tight">dol-pin</p><h1 className="mb-3 mt-7 text-[32px] font-bold leading-[1.3] tracking-[-1.2px]">콘서트 준비,<br/>가볍게 시작하세요.</h1><p className="text-[15px] leading-6 text-[#98989f]">내 계정으로 로그인하고<br/>필요한 물품을 빌려보세요.</p></div>
      <EmailAuth disabled={oauth.isPending || send.isPending || verify.isPending} onBusyChange={setEmailBusy}/>
      <p className="border-t border-[#29292c] pt-5 text-center text-sm text-muted-foreground">소셜 계정으로 계속하기</p>
      <SocialButtons onClick={provider=>oauth.mutate(provider)} disabled={authBusy}/>
      <Failure error={oauth.error}/>
      <div className="mt-1 border-t border-[#29292c] pt-5"><button type="button" aria-expanded={phoneOpen} disabled={authBusy} onClick={()=>setPhoneOpen(!phoneOpen)} className="w-full cursor-pointer py-3 text-center text-sm text-[#b5b5bc]">{phoneOpen?'전화번호 로그인 닫기':'전화번호로 로그인'}</button></div>
      {phoneOpen ? <>
      <form onSubmit={form.handleSubmit(value => {if (!authBusy) send.mutate(value);})}><FieldGroup><Field data-invalid={!!form.formState.errors.phone}><FieldLabel htmlFor="phone">전화번호</FieldLabel><Input id="phone" type="tel" autoComplete="tel" disabled={authBusy} aria-invalid={!!form.formState.errors.phone} {...form.register('phone')}/><FieldError errors={[form.formState.errors.phone]}/></Field><Button type="submit" disabled={authBusy}>인증번호 받기</Button></FieldGroup></form>
      {sentPhone ? <form onSubmit={e => {e.preventDefault(); if (!authBusy && /^\d{6}$/.test(token)) verify.mutate();}}><FieldGroup><Field><FieldLabel htmlFor="otp">인증번호</FieldLabel><Input id="otp" inputMode="numeric" autoComplete="one-time-code" value={token} disabled={authBusy} maxLength={6} onChange={e => setToken(e.target.value.replace(/\D/g, ''))}/></Field><Button disabled={authBusy || !/^\d{6}$/.test(token)}>로그인</Button></FieldGroup></form> : null}
      <Failure error={send.error ?? verify.error}/>
      </> : null}
    </>}
  </section>;
}
