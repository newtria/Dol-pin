'use client';
import {useState} from 'react';
import Link from 'next/link';
import {useInfiniteQuery,useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {formatWon} from '@dolpin/contracts';
import type {PayoutCursor} from '@dolpin/api-client';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
const labels={pending:'지급 대기',processing:'송금 확인 중',paid:'지급 완료',failed:'운영 확인 중'};
export default function Payouts(){
 const {session}=useApi();return <PayoutContents key={session?.user.id??'signed-out'}/>;
}
function PayoutContents(){
 const {api,session}=useApi();const queries=useQueryClient();const [bankName,setBank]=useState(''),[accountNumber,setNumber]=useState(''),[holderName,setHolder]=useState('');
 const account=useQuery({queryKey:['payout-account',session?.user.id],queryFn:api.payoutAccount,enabled:!!session,gcTime:0});
 const list=useInfiniteQuery({queryKey:['payouts',session?.user.id],queryFn:({pageParam})=>api.payouts(pageParam),initialPageParam:undefined as PayoutCursor|undefined,getNextPageParam:rows=>{const last=rows.at(-1);return rows.length===100&&last?{createdAt:last.created_at,id:last.id}:undefined;},enabled:!!session});
 const save=useMutation({mutationFn:()=>api.savePayoutAccount({bankName,accountNumber,holderName}),onSuccess:()=>{setBank('');setNumber('');setHolder('');void queries.invalidateQueries({queryKey:['payout-account']});}});
 if(!session)return <Link href="/account">로그인하고 지급 내역 보기</Link>;
 return <section className="mx-auto flex max-w-xl flex-col gap-5"><h1 className="text-3xl font-bold">대여료 지급</h1><p>거래가 끝나면 대여료를 등록한 계좌로 지급합니다. 보증금 반환과 대여료 지급은 별도로 표시됩니다.</p>{account.data?<p>등록 계좌: {account.data.bankName} · 끝 {account.data.accountNumber.slice(-4)} · {account.data.holderName}</p>:<p>지급받을 본인 명의 계좌를 등록해 주세요.</p>}<form className="flex flex-col gap-3" onSubmit={e=>{e.preventDefault();if(window.confirm('본인 명의 계좌가 맞습니까? 이미 송금 확인 중인 건은 기존 계좌로 처리됩니다.'))save.mutate();}}><label>은행<Input value={bankName} maxLength={60} required onChange={e=>setBank(e.target.value)}/></label><label>계좌번호<Input inputMode="numeric" autoComplete="off" value={accountNumber} maxLength={40} required onChange={e=>setNumber(e.target.value)}/></label><label>예금주<Input value={holderName} maxLength={60} required onChange={e=>setHolder(e.target.value)}/></label><Button disabled={save.isPending}>지급 계좌 저장</Button></form>{save.isSuccess?<p role="status">계좌를 저장했습니다.</p>:null}<Failure error={account.error??list.error??save.error}/><h2 className="text-xl font-semibold">지급 내역</h2>{list.data?.pages.flat().map(p=><article key={p.id} className="rounded border p-4"><Link href={`/rentals/${p.reservation_id}`}>거래 보기</Link><p>{labels[p.status]}</p><p>대여료 {formatWon(p.amount)} · 수수료 {formatWon(p.fee_amount)}</p><p>지급액 {formatWon(p.net_amount)}</p>{p.paid_at?<p>지급일 {new Date(p.paid_at).toLocaleDateString('ko-KR')}</p>:null}</article>)}{list.data?.pages[0].length===0?<p>지급 내역이 없습니다.</p>:null}{list.hasNextPage?<Button variant="outline" onClick={()=>void list.fetchNextPage()}>이전 지급 내역</Button>:null}</section>;
}
