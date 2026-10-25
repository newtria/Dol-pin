'use client';
import {useState} from 'react';
import Link from 'next/link';
import {useInfiniteQuery,useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from './ui/button';
import {Input} from './ui/input';

export function AccountSettings() {
 const {api,session}=useApi();const queries=useQueryClient();
 const [nickname,setNickname]=useState('');const [confirmed,setConfirmed]=useState(false);const [notice,setNotice]=useState('');
 const consent=useQuery({queryKey:['consent',session?.user.id],queryFn:api.consentStatus});
 const blocks=useInfiniteQuery({queryKey:['blocked-users',session?.user.id],queryFn:({pageParam})=>api.blockedUsers(pageParam),initialPageParam:0,getNextPageParam:(rows,_pages,offset)=>rows.length===50?offset+50:undefined});
 const change=useMutation({mutationFn:()=>api.updateProfile({nickname}),onSuccess:()=>{setNotice('닉네임을 변경했습니다.');void queries.invalidateQueries({queryKey:['profile']});}});
 const agree=useMutation({mutationFn:()=>{if(!consent.data)throw {code:'SERVICE_UNAVAILABLE'};return api.recordConsent({termsVersion:consent.data.termsVersion,privacyVersion:consent.data.privacyVersion});},onSuccess:()=>queries.invalidateQueries({queryKey:['consent']})});
 const unblock=useMutation({mutationFn:(id:string)=>api.blockUser(id,false),onSuccess:()=>queries.invalidateQueries({queryKey:['blocked-users']})});
 const terms=process.env.NEXT_PUBLIC_TERMS_URL,privacy=process.env.NEXT_PUBLIC_PRIVACY_URL;
 const links=[{href:'/items/mine',title:'내 물품 관리',body:'등록한 물품을 수정하고 공개 상태를 관리해요.'},{href:'/notifications',title:'메시지·알림',body:'예약과 거래 상대의 새 소식을 확인해요.'},{href:'/account/payouts',title:'대여료 지급',body:'받을 금액과 지급 계좌를 확인해요.'},{href:'/support',title:'고객 문의',body:'서비스 이용 문의와 답변을 확인해요.'}];
 return <section className="flex flex-col gap-6">
  {!consent.data?.accepted?<section className="rounded-2xl border border-primary/20 bg-primary/5 p-5"><h2 className="text-lg font-semibold">거래 이용 준비</h2><p className="mt-2 text-sm leading-6 text-muted-foreground">예약과 물품 등록 전에 이용 안내를 확인해 주세요.</p>{consent.isPending?<p role="status" className="mt-3 text-sm">이용 동의를 확인하고 있습니다.</p>:terms&&privacy?<div className="mt-4 flex flex-col gap-4"><p className="text-sm"><a className="underline underline-offset-4" href={terms} target="_blank" rel="noreferrer">이용약관 ↗</a> · <a className="underline underline-offset-4" href={privacy} target="_blank" rel="noreferrer">개인정보 처리 안내 ↗</a></p><label className="flex items-center gap-3 text-sm"><input className="size-4" type="checkbox" checked={confirmed} onChange={e=>setConfirmed(e.target.checked)}/> 내용을 확인하고 동의합니다.</label><Button disabled={!confirmed||agree.isPending||!consent.data} onClick={()=>agree.mutate()}>{agree.isPending?'동의 저장 중…':'동의하고 거래 이용하기'}</Button></div>:<p className="mt-3 text-sm">거래 이용 안내를 준비하고 있습니다. 잠시 후 다시 확인해 주세요.</p>}</section>:null}
  <nav aria-label="계정 메뉴" className="grid gap-3 sm:grid-cols-2">{links.map(link=><Link key={link.href} href={link.href} className="rounded-2xl border bg-card p-5 transition-colors hover:border-primary focus-visible:outline-2 focus-visible:outline-ring"><h2 className="font-semibold">{link.title} <span aria-hidden="true">→</span></h2><p className="mt-2 text-sm leading-6 text-muted-foreground">{link.body}</p></Link>)}</nav>
  {session?.user.app_metadata?.dolpin_operator===true?<Button asChild variant="outline"><Link href="/operations">운영 관리 열기</Link></Button>:null}
  <section className="rounded-2xl border bg-card p-5"><h2 className="mb-4 text-lg font-semibold">프로필·보안</h2><form className="flex flex-col gap-3 sm:flex-row sm:items-end" onSubmit={e=>{e.preventDefault();if(!change.isPending&&nickname.trim().length>=2)change.mutate();}}><label className="flex-1 text-sm font-medium" htmlFor="new-nickname">새 닉네임<Input id="new-nickname" className="mt-2" value={nickname} autoComplete="nickname" placeholder="2~30자" onChange={e=>setNickname(e.target.value)} maxLength={30}/></label><Button disabled={change.isPending||nickname.trim().length<2}>{change.isPending?'저장 중…':'닉네임 변경'}</Button></form><Link className="mt-5 inline-block text-sm font-medium underline underline-offset-4" href="/auth/password">비밀번호 변경</Link></section>
  <details className="rounded-2xl border bg-card p-5"><summary className="cursor-pointer font-semibold">차단 관리</summary><div className="mt-4 flex flex-col gap-3">{blocks.isPending?<p role="status" className="text-sm text-muted-foreground">차단 목록을 불러오고 있습니다.</p>:null}{blocks.data?.pages.flat().map(user=><div key={user.id} className="flex items-center justify-between gap-3"><p className="break-all">{user.nickname}</p><Button variant="outline" disabled={unblock.isPending} onClick={()=>unblock.mutate(user.id)}>차단 해제</Button></div>)}{blocks.data?.pages[0].length===0?<p className="text-sm text-muted-foreground">차단한 사용자가 없습니다.</p>:null}{blocks.hasNextPage?<Button variant="outline" disabled={blocks.isFetchingNextPage} onClick={()=>void blocks.fetchNextPage()}>차단한 사용자 더 보기</Button>:null}</div></details>
  {notice?<p role="status" className="rounded-xl bg-primary/5 p-4 text-sm font-medium text-primary">{notice}</p>:null}<Failure error={change.error??agree.error??unblock.error??consent.error??blocks.error}/>
 </section>;
}
