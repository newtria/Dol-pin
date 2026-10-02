'use client';
import {useState} from 'react';
import Link from 'next/link';
import {useInfiniteQuery,useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from './ui/button';
import {Input} from './ui/input';

export function AccountSettings() {
 const {api,client,session}=useApi();const queries=useQueryClient();
 const [nickname,setNickname]=useState('');const [confirmed,setConfirmed]=useState(false);const [notice,setNotice]=useState('');
 const consent=useQuery({queryKey:['consent',session?.user.id],queryFn:api.consentStatus});
 const blocks=useInfiniteQuery({queryKey:['blocked-users',session?.user.id],queryFn:({pageParam})=>api.blockedUsers(pageParam),initialPageParam:0,getNextPageParam:(rows,_pages,offset)=>rows.length===50?offset+50:undefined});
 const change=useMutation({mutationFn:()=>api.updateProfile({nickname}),onSuccess:()=>{setNotice('닉네임을 변경했습니다.');void queries.invalidateQueries({queryKey:['profile']});}});
 const agree=useMutation({mutationFn:()=>{if(!consent.data)throw {code:'SERVICE_UNAVAILABLE'};return api.recordConsent({termsVersion:consent.data.termsVersion,privacyVersion:consent.data.privacyVersion});},onSuccess:()=>queries.invalidateQueries({queryKey:['consent']})});
 const unblock=useMutation({mutationFn:(id:string)=>api.blockUser(id,false),onSuccess:()=>queries.invalidateQueries({queryKey:['blocked-users']})});
 const close=useMutation({mutationFn:api.closeAccount,onSuccess:async()=>{const {error}=await client.auth.signOut({scope:'local'});queries.clear();if(error)throw error;window.location.assign('/account');}});
 const terms=process.env.NEXT_PUBLIC_TERMS_URL,privacy=process.env.NEXT_PUBLIC_PRIVACY_URL;
 return <section className="flex flex-col gap-4">
  <Link href="/items/mine">내 물품 관리</Link><Link href="/notifications">메시지·알림</Link><Link href="/account/payouts">대여료 지급 내역·계좌</Link><Link href="/auth/password">비밀번호 변경</Link>
  <Link href="/support">고객 문의·처리 내역</Link>
  {session?.user.app_metadata?.dolpin_operator===true?<Link href="/operations">운영 관리</Link>:null}
  <label>새 닉네임<Input value={nickname} onChange={e=>setNickname(e.target.value)} maxLength={30}/></label><Button disabled={change.isPending||nickname.trim().length<2} onClick={()=>change.mutate()}>닉네임 변경</Button>
  {!consent.data?.accepted?<><h2 className="font-semibold">거래 이용 동의</h2>{terms&&privacy?<><p><a href={terms} target="_blank" rel="noreferrer">이용약관</a> · <a href={privacy} target="_blank" rel="noreferrer">개인정보 처리 안내</a></p><label><input type="checkbox" checked={confirmed} onChange={e=>setConfirmed(e.target.checked)}/> 내용을 확인하고 동의합니다.</label><Button disabled={!confirmed||agree.isPending} onClick={()=>agree.mutate()}>동의하고 거래 이용하기</Button></>:<p>거래 이용 안내를 준비하고 있습니다. 잠시 후 다시 확인해 주세요.</p>}</>:null}
  <h2 className="font-semibold">차단 관리</h2>{blocks.data?.pages.flat().map(user=><div key={user.id}>{user.nickname}<Button variant="outline" disabled={unblock.isPending} onClick={()=>unblock.mutate(user.id)}>차단 해제</Button></div>)}{blocks.data?.pages[0].length===0?<p>차단한 사용자가 없습니다.</p>:null}
  {blocks.hasNextPage?<Button variant="outline" disabled={blocks.isFetchingNextPage} onClick={()=>void blocks.fetchNextPage()}>차단한 사용자 더 보기</Button>:null}
  <Button variant="outline" disabled={close.isPending} onClick={()=>{if(window.confirm('탈퇴하시겠습니까? 진행 중 거래나 미지급 대여료가 있으면 먼저 처리해야 합니다. 탈퇴 후 계정은 복구할 수 없으며 필요한 거래 기록은 보존됩니다.'))close.mutate();}}>회원 탈퇴</Button>
  {notice?<p role="status">{notice}</p>:null}<Failure error={change.error??agree.error??close.error??unblock.error??consent.error??blocks.error}/>
 </section>;
}
