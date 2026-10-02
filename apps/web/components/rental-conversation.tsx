'use client';
import {useEffect,useRef,useState} from 'react';
import {useInfiniteQuery,useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import type {ServiceCursor} from '@dolpin/api-client';
import {formatKoreaTime,formatWon} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from './ui/button';
import {Input} from './ui/input';
import {DisputeEvidence} from './dispute-evidence';
export function RentalConversation({id,otherUser,status}:{id:string;otherUser:string;status:string}) {
 const {api,session}=useApi();const queries=useQueryClient();const [text,setText]=useState('');const [reason,setReason]=useState('');const [notice,setNotice]=useState('');const attempt=useRef<{text:string;id:string}|null>(null);
 const messages=useInfiniteQuery({queryKey:['messages',id,session?.user.id],queryFn:({pageParam})=>api.messages(id,pageParam),initialPageParam:undefined as ServiceCursor|undefined,getNextPageParam:rows=>{const last=rows.at(-1);return rows.length===50&&last?.created_at?{createdAt:last.created_at,id:last.id}:undefined;},refetchInterval:10000});
 const disputes=useQuery({queryKey:['disputes',id,session?.user.id,status],queryFn:()=>api.disputes(id),enabled:!!session,refetchInterval:status==='disputed'?10000:false});
 const resolution=useQuery({queryKey:['dispute-resolution',id,session?.user.id,status],queryFn:()=>api.disputeResolution(id),enabled:!!session&&status==='resolved'});
 const read=useMutation({mutationFn:()=>api.markMessagesRead(id)});
 useEffect(()=>{if(messages.dataUpdatedAt)read.mutate();},[messages.dataUpdatedAt]);
 const send=useMutation({mutationFn:()=>{const body=text.trim();if(!attempt.current||attempt.current.text!==body)attempt.current={text:body,id:crypto.randomUUID()};return api.sendMessage(id,body,attempt.current.id);},onSuccess:()=>{setText('');attempt.current=null;void queries.invalidateQueries({queryKey:['messages',id]});}});
 const dispute=useMutation({mutationFn:()=>api.openDispute(id,reason.trim()),onSuccess:()=>{setReason('');setNotice('운영 검토를 요청했습니다. 아래에 증빙 사진을 추가할 수 있습니다.');void queries.invalidateQueries({queryKey:['disputes',id]});void queries.invalidateQueries({queryKey:['rental',id]});}});
 const block=useMutation({mutationFn:()=>api.blockUser(otherUser,true),onSuccess:()=>setNotice('차단했습니다. 진행 중 거래의 의무는 유지되며 문제가 있으면 운영 검토를 요청해 주세요.')});
 const report=useMutation({mutationFn:()=>api.report({userId:otherUser,reservationId:id,reason:'other',description:reason.trim()}),onSuccess:()=>setNotice('신고를 접수했습니다. 계정의 고객 문의에서 처리 결과를 확인할 수 있습니다.')});
 return <section className="flex flex-col gap-5 border-t pt-6"><h2 className="text-xl font-semibold">거래 메시지</h2>{messages.hasNextPage?<Button variant="outline" disabled={messages.isFetchingNextPage} onClick={()=>void messages.fetchNextPage()}>이전 메시지</Button>:null}<ol className="flex max-h-80 flex-col gap-3 overflow-auto">{messages.data?.pages.flat().slice().reverse().map(m=><li key={m.id} className="rounded border p-3"><p className="text-sm text-muted-foreground">{m.sender_id===session?.user.id?'나':'거래 상대'} · {m.created_at?new Date(m.created_at).toLocaleString('ko-KR'):''}</p><p className="whitespace-pre-wrap break-words">{m.message}</p></li>)}</ol>
 <form className="flex gap-3" onSubmit={e=>{e.preventDefault();if(text.trim()&&!send.isPending)send.mutate();}}><Input aria-label="거래 메시지" value={text} maxLength={2000} disabled={send.isPending} onChange={e=>setText(e.target.value)}/><Button disabled={send.isPending||!text.trim()}>보내기</Button></form>
 <h2 className="text-xl font-semibold">거래 문제·문의</h2>
 {status==='resolved'?<section className="flex flex-col gap-3 rounded border p-4" aria-label="운영 검토 결과"><h3 className="font-semibold">운영 검토 결과</h3>{resolution.data?<><p>환불액 {formatWon(resolution.data.refund_amount)}</p><p className="whitespace-pre-wrap">{resolution.data.reason}</p>{resolution.data.created_at?<p>처리일 {formatKoreaTime(resolution.data.created_at)}</p>:null}<p className="text-sm text-muted-foreground">환불액의 결제 수단 반영 시점은 결제사에 따라 다릅니다. 대여료 지급 상태는 계정의 지급 내역에서 확인해 주세요.</p></>:<p>{resolution.isPending?'처리 결과를 불러오고 있습니다.':'처리 결과를 확인하지 못했습니다. 고객 문의에서 거래 번호로 문의해 주세요.'}</p>}<Failure error={resolution.error}/>{resolution.isError?<Button variant="outline" disabled={resolution.isFetching} onClick={()=>void resolution.refetch()}>처리 결과 다시 확인</Button>:null}</section>:null}
 <label>문제 상황<textarea className="mt-2 min-h-28 w-full rounded border p-3" maxLength={2000} value={reason} onChange={e=>setReason(e.target.value)} placeholder="파손, 미반납, 약속 불이행 등 상황을 설명해 주세요."/></label>
 {['paid','picked_up','returned','disputed'].includes(status)?<Button disabled={reason.trim().length<10||dispute.isPending} onClick={()=>{if(window.confirm('운영 검토를 요청할까요? 처리 중에는 물품 인수와 자동 환불을 진행할 수 없습니다.'))dispute.mutate();}}>운영 검토 요청</Button>:null}
 <Button variant="outline" disabled={reason.trim().length<10||report.isPending} onClick={()=>report.mutate()}>상대 신고·문의 접수</Button><Button variant="outline" disabled={block.isPending} onClick={()=>{if(window.confirm('상대를 차단할까요? 진행 중 거래는 유지됩니다.'))block.mutate();}}>상대 차단</Button>
 {disputes.data?.map(d=><article key={d.id} className="rounded border p-4"><p>{d.resolved_at?'처리 완료':'검토 중'}</p><p className="whitespace-pre-wrap">{d.reason}</p><p>접수일 {new Date(d.created_at).toLocaleString('ko-KR')}</p><DisputeEvidence id={id} paths={d.evidence_paths} canUpload={!d.resolved_at&&d.reporter_id===session?.user.id}/></article>)}
 {notice?<p role="status">{notice}</p>:null}<Failure error={messages.error??send.error??read.error??dispute.error??disputes.error??block.error??report.error}/></section>;
}
