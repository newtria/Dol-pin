'use client';
import Link from 'next/link';
import {formatKoreaTime} from '@dolpin/contracts';
import {accountHref} from '@/components/auth-return';
import {useState} from 'react';
import {useInfiniteQuery,useMutation,useQueryClient} from '@tanstack/react-query';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';

const labels:Record<string,string>={pending:'접수 · 확인 중',resolved:'답변 완료',dismissed:'검토 종료'};
export default function Support(){
 const {session}=useApi();return <SupportContents key={session?.user.id??'signed-out'}/>;
}
function SupportContents(){
 const {api,session,ready}=useApi();
 const queries=useQueryClient();const [description,setDescription]=useState('');
 const send=useMutation({mutationFn:()=>api.report({reason:'other',description:description.trim()}),onSuccess:()=>{setDescription('');void queries.invalidateQueries({queryKey:['reports']});}});
 const reports=useInfiniteQuery({queryKey:['reports',session?.user.id],queryFn:({pageParam})=>api.reports(pageParam),initialPageParam:0,getNextPageParam:(rows,_pages,offset)=>rows.length===50?offset+50:undefined,enabled:!!session,refetchInterval:30000});
 if(!ready)return <p>계정을 확인하고 있습니다.</p>;
 if(!session)return <section className="flex flex-col gap-4"><h1 className="text-2xl font-bold">고객 문의</h1><Button asChild><Link href={accountHref('/support')}>로그인하고 문의 내역 보기</Link></Button></section>;
 return <section className="mx-auto flex max-w-2xl flex-col gap-6"><h1 className="text-3xl font-bold">고객 문의</h1><div className="rounded-2xl border border-primary/20 bg-primary/5 p-5"><h2 className="font-semibold">진행 중인 거래에 문제가 있나요?</h2><p className="mb-4 mt-2 text-sm leading-6 text-muted-foreground">환불·파손·미반납 문제는 해당 거래의 ‘운영 검토 요청’으로 접수하면 거래 정보와 함께 확인할 수 있습니다.</p><Button asChild variant="outline"><Link href="/rentals">내 거래에서 문의하기</Link></Button></div>
 <form className="flex flex-col gap-4 rounded-2xl border bg-card p-5" onSubmit={e=>{e.preventDefault();if(!send.isPending&&description.trim().length>=10)send.mutate();}}><label htmlFor="support-description" className="font-semibold">일반 문의</label><textarea id="support-description" aria-describedby="support-count" className="min-h-36 w-full rounded-xl border bg-background p-3 text-base font-normal leading-6 focus-visible:outline-2 focus-visible:outline-ring" value={description} maxLength={2000} disabled={send.isPending} onChange={e=>setDescription(e.target.value)} placeholder="계정이나 서비스 이용 중 겪은 문제를 10자 이상 입력해 주세요. 비밀번호나 카드번호는 입력하지 마세요."/><span id="support-count" className="text-xs font-normal text-muted-foreground">{description.length}/2,000 · 최소 10자</span><Button disabled={send.isPending||description.trim().length<10}>{send.isPending?'접수 중…':'문의 접수'}</Button></form>{send.isSuccess?<p role="status">문의를 접수했습니다. 아래에서 답변을 확인할 수 있습니다.</p>:null}<Failure error={send.error}/>
 <h2 className="text-xl font-semibold">내 문의·신고</h2>{reports.isPending?<p>문의 내역을 불러오고 있습니다.</p>:null}{reports.data?.pages[0].length===0?<p className="rounded-2xl border border-dashed bg-card p-6 text-center text-sm text-muted-foreground">아직 접수한 문의가 없어요. 문의하면 접수 상태와 답변이 여기에 표시됩니다.</p>:null}{reports.data?.pages.flat().map(report=><article key={report.id} className="flex flex-col gap-3 rounded-2xl border bg-card p-5"><h3 className="font-semibold">{labels[report.status??'']??'확인 중'}</h3><p className="whitespace-pre-wrap break-words">{report.description||'접수한 신고'}</p><p className="text-sm text-muted-foreground">접수일 {report.created_at?formatKoreaTime(report.created_at):''}</p>{report.resolution_note?<div className="rounded bg-muted p-3"><h4 className="font-semibold">운영팀 답변</h4><p className="whitespace-pre-wrap break-words">{report.resolution_note}</p>{report.resolved_at?<p className="text-sm">{formatKoreaTime(report.resolved_at)}</p>:null}</div>:null}{report.reservation_id?<Link href={`/rentals/${report.reservation_id}`}>관련 거래 보기</Link>:null}</article>)}{reports.hasNextPage?<Button variant="outline" disabled={reports.isFetchingNextPage} onClick={()=>void reports.fetchNextPage()}>이전 문의 더 보기</Button>:null}<Failure error={reports.error}/>{reports.isError?<Button variant="outline" disabled={reports.isFetching} onClick={()=>void reports.refetch()}>다시 불러오기</Button>:null}</section>;
}
