'use client';
import {SocialButtons} from '@/components/social-buttons';
import {EmailAuth} from '@/components/email-auth';
import {AccountSettings} from '@/components/account-settings';
import {authCallbackUrl,safeReturnTo} from '@/components/auth-return';
import {Suspense,useEffect,useState} from 'react';
import Link from 'next/link';
import {useRouter,useSearchParams} from 'next/navigation';
import {useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {phoneInput} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Field,FieldGroup,FieldLabel,FieldError} from '@/components/ui/field';

export default function Account(){return <Suspense fallback={<p role="status">계정을 확인하고 있습니다.</p>}><AccountContents/></Suspense>;}
function AccountContents() {
 const {client,api,session,ready}=useApi();const router=useRouter();const returnTo=safeReturnTo(useSearchParams().get('returnTo'));
 const needsSetup=/^\/items\/(?:new(?:\?|$)|[^/]+\/reserve(?:\?|$))/.test(returnTo);
 const [phoneOpen,setPhoneOpen]=useState(false),[emailBusy,setEmailBusy]=useState(false);
 const [sentPhone,setSentPhone]=useState(''),[token,setToken]=useState(''),[nickname,setNickname]=useState('');
 const queries=useQueryClient();
 const form=useForm({resolver:zodResolver(phoneInput),defaultValues:{phone:'+82'}});
 const profile=useQuery({queryKey:['profile',session?.user.id],queryFn:()=>api.profile(session!.user.id),enabled:!!session});
 const consent=useQuery({queryKey:['consent',session?.user.id],queryFn:api.consentStatus,enabled:!!session&&!!profile.data});
 const canResume=!!session&&(!needsSetup||!!profile.data&&!!consent.data?.accepted);
 useEffect(()=>{if(canResume&&returnTo!=='/account')router.replace(returnTo);},[canResume,returnTo,router]);
 const oauth=useMutation({mutationFn:async(provider:'google'|'apple'|'kakao'|'custom:naver')=>{const {error}=await client.auth.signInWithOAuth({provider,options:{redirectTo:authCallbackUrl(returnTo)}});if(error)throw error;}});
 const send=useMutation({mutationFn:async({phone}:{phone:string})=>{const {error}=await client.auth.signInWithOtp({phone});if(error)throw error;setSentPhone(phone);}});
 const verify=useMutation({mutationFn:async()=>{const {error}=await client.auth.verifyOtp({phone:sentPhone,token,type:'sms'});if(error)throw error;}});
 const logout=useMutation({mutationFn:async()=>{const {error}=await client.auth.signOut();if(error)throw error;setToken('');setSentPhone('');router.replace('/account');}});
 const create=useMutation({mutationFn:()=>api.ensureProfile(nickname),onSuccess:()=>queries.invalidateQueries({queryKey:['profile',session?.user.id]})});
 const authBusy=emailBusy||oauth.isPending||send.isPending||verify.isPending;
 if(!ready)return <p role="status">계정을 확인하고 있습니다.</p>;
 if(session)return <section className="mx-auto flex max-w-3xl flex-col gap-6"><header className="flex flex-wrap items-start justify-between gap-4"><div><p className="mb-2 text-sm font-semibold text-primary">내 계정</p><h1 className="text-3xl font-bold">{profile.data?.nickname?`${profile.data.nickname}님`:'계정을 준비해 주세요'}</h1><p className="mt-2 break-all text-sm text-muted-foreground">{session.user.email??session.user.phone}</p></div><Button variant="outline" onClick={()=>logout.mutate()} disabled={logout.isPending}>{logout.isPending?'로그아웃 중…':'로그아웃'}</Button></header>
  {returnTo!=='/account'?<div role="status" className="rounded-2xl border border-primary/20 bg-primary/5 p-4 text-sm leading-6">{canResume?'이전 작업으로 돌아가고 있습니다.':'아래 계정 설정을 마치면 선택한 화면으로 돌아갑니다. 예약 기간도 그대로 유지됩니다.'}</div>:null}
  {profile.isPending?<p role="status">프로필을 불러오고 있습니다.</p>:null}
  {!profile.isPending&&!profile.error&&!profile.data?<form className="rounded-2xl border bg-card p-6" onSubmit={e=>{e.preventDefault();if(!create.isPending&&nickname.trim().length>=2)create.mutate();}}><FieldGroup><div><h2 className="text-xl font-semibold">거래에 사용할 이름</h2><p className="mt-2 text-sm text-muted-foreground">상대에게 표시할 닉네임을 2~30자로 입력해 주세요.</p></div><Field><FieldLabel htmlFor="nickname">닉네임</FieldLabel><Input id="nickname" value={nickname} autoComplete="nickname" maxLength={30} onChange={e=>setNickname(e.target.value)}/></Field><Button disabled={create.isPending||nickname.trim().length<2}>{create.isPending?'만드는 중…':'프로필 만들기'}</Button></FieldGroup></form>:null}
  <Failure error={profile.error??create.error??logout.error??consent.error}/>{profile.isError?<Button variant="outline" onClick={()=>void profile.refetch()}>프로필 다시 불러오기</Button>:null}
  {profile.data?<AccountSettings key={session.user.id}/>:null}
 </section>;
 return <section className="mx-auto grid max-w-4xl gap-8 lg:grid-cols-[1fr_380px] lg:gap-16"><header className="lg:pt-12"><p className="mb-4 text-sm font-semibold text-primary">돌핀과 함께하는 콘서트 준비</p><h1 className="text-3xl font-bold leading-tight tracking-tight sm:text-4xl">필요한 순간만 빌리고,<br/>공연은 가볍게 즐기세요.</h1><p className="mt-5 max-w-md leading-7 text-muted-foreground">예약부터 물품 전달, 반납까지 한 곳에서 이어집니다.</p>{returnTo!=='/account'?<p className="mt-6 rounded-xl border border-primary/20 bg-primary/5 p-4 text-sm leading-6">로그인하면 선택한 화면으로 돌아갑니다. 예약 중이었다면 선택한 기간을 이어서 확인할 수 있어요.</p>:null}<Link href={returnTo.startsWith('/items/')?returnTo:'/items'} className="mt-6 inline-block text-sm font-medium underline underline-offset-4">{returnTo.startsWith('/items/')?'예약 화면으로 돌아가기':'먼저 물품 둘러보기'}</Link></header>
  <div className="rounded-2xl border bg-card p-5 sm:p-7"><EmailAuth returnTo={returnTo} disabled={oauth.isPending||send.isPending||verify.isPending} onBusyChange={setEmailBusy}/><p className="mb-4 mt-7 border-t pt-5 text-center text-sm text-muted-foreground">소셜 계정으로 계속하기</p><SocialButtons onClick={provider=>oauth.mutate(provider)} disabled={authBusy}/><Failure error={oauth.error}/>
   <button type="button" aria-expanded={phoneOpen} aria-controls="phone-login" disabled={authBusy} onClick={()=>setPhoneOpen(!phoneOpen)} className="mt-5 min-h-11 w-full rounded-lg text-center text-sm text-muted-foreground underline underline-offset-4 focus-visible:outline-2 focus-visible:outline-ring">{phoneOpen?'전화번호 로그인 닫기':'전화번호로 로그인'}</button>
   {phoneOpen?<div id="phone-login" className="mt-4 flex flex-col gap-5"><form onSubmit={form.handleSubmit(value=>{if(!authBusy)send.mutate(value);})}><FieldGroup><Field data-invalid={!!form.formState.errors.phone}><FieldLabel htmlFor="phone">전화번호</FieldLabel><Input id="phone" type="tel" autoComplete="tel" placeholder="+821012345678" disabled={authBusy} aria-invalid={!!form.formState.errors.phone} {...form.register('phone')}/><p className="text-xs text-muted-foreground">010으로 시작하는 번호는 +8210으로 입력해 주세요.</p><FieldError errors={[form.formState.errors.phone]}/></Field><Button type="submit" disabled={authBusy}>{send.isPending?'인증번호 보내는 중…':sentPhone?'인증번호 다시 받기':'인증번호 받기'}</Button></FieldGroup></form>{sentPhone?<form onSubmit={e=>{e.preventDefault();if(!authBusy&&/^\d{6}$/.test(token))verify.mutate();}}><FieldGroup><p role="status" className="text-sm">{sentPhone}로 인증번호를 보냈습니다.</p><Field><FieldLabel htmlFor="otp">인증번호 6자리</FieldLabel><Input id="otp" inputMode="numeric" autoComplete="one-time-code" value={token} disabled={authBusy} maxLength={6} onChange={e=>setToken(e.target.value.replace(/\D/g,''))}/></Field><Button disabled={authBusy||!/^\d{6}$/.test(token)}>{verify.isPending?'확인 중…':'로그인'}</Button></FieldGroup></form>:null}<Failure error={send.error??verify.error}/></div>:null}
  </div>
 </section>;
}
