'use client';
import Link from 'next/link';
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
 if(!session)return <section className="flex flex-col gap-4"><h1 className="text-2xl font-bold">고객 문의</h1><Link href="/account">로그인하고 문의 내역 보기</Link></section>;
 return <section className="mx-auto flex max-w-xl flex-col gap-5"><h1 className="text-3xl font-bold">고객 문의</h1><p>거래 문제는 거래 상세의 ‘운영 검토 요청’으로 접수해 주세요. 환불과 분쟁 결과는 해당 거래에서 확인할 수 있습니다.</p><Link href="/rentals">내 거래에서 문의하기</Link>
 <form className="flex flex-col gap-3" onSubmit={e=>{e.preventDefault();if(!send.isPending&&description.trim().length>=10)send.mutate();}}><label>일반 문의<textarea className="mt-2 min-h-28 w-full rounded border p-3" value={description} maxLength={2000} disabled={send.isPending} onChange={e=>setDescription(e.target.value)} placeholder="계정이나 서비스 이용 중 겪은 문제를 10자 이상 입력해 주세요. 비밀번호나 카드번호는 입력하지 마세요."/></label><Button disabled={send.isPending||description.trim().length<10}>문의 접수</Button></form>{send.isSuccess?<p role="status">문의를 접수했습니다. 아래에서 답변을 확인할 수 있습니다.</p>:null}<Failure error={send.error}/>
 {reports.hasNextPage?<Button variant="outline" disabled={reports.isFetchingNextPage} onClick={()=>void reports.fetchNextPage()}>이전 문의 더 보기</Button>:null}
 <h2 className="text-xl font-semibold">내 문의·신고</h2>{reports.isPending?<p>문의 내역을 불러오고 있습니다.</p>:null}{reports.data?.pages[0].length===0?<p>접수한 문의·신고가 없습니다.</p>:null}{reports.data?.pages.flat().map(report=><article key={report.id} className="flex flex-col gap-3 rounded border p-4"><h3 className="font-semibold">{labels[report.status??'']??'확인 중'}</h3><p className="whitespace-pre-wrap break-words">{report.description||'접수한 신고'}</p><p className="text-sm text-muted-foreground">접수일 {report.created_at?new Date(report.created_at).toLocaleString('ko-KR'):''}</p>{report.resolution_note?<div className="rounded bg-muted p-3"><h4 className="font-semibold">운영팀 답변</h4><p className="whitespace-pre-wrap break-words">{report.resolution_note}</p>{report.resolved_at?<p className="text-sm">{new Date(report.resolved_at).toLocaleString('ko-KR')}</p>:null}</div>:null}{report.reservation_id?<Link href={`/rentals/${report.reservation_id}`}>관련 거래 보기</Link>:null}</article>)}<Failure error={reports.error}/>{reports.isError?<Button variant="outline" disabled={reports.isFetching} onClick={()=>void reports.refetch()}>다시 불러오기</Button>:null}</section>;
}
