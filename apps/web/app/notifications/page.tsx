'use client';
import Link from 'next/link';
import {formatKoreaTime} from '@dolpin/contracts';
import {accountHref} from '@/components/auth-return';
import {useInfiniteQuery,useMutation,useQueryClient} from '@tanstack/react-query';
import type {ServiceCursor} from '@dolpin/api-client';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
export default function Notifications(){
 const {api,session,ready}=useApi();const queries=useQueryClient();
 const list=useInfiniteQuery({queryKey:['notifications',session?.user.id],queryFn:({pageParam})=>api.notifications(pageParam),initialPageParam:undefined as ServiceCursor|undefined,getNextPageParam:rows=>{const last=rows.at(-1);return rows.length===50&&last?{createdAt:last.created_at,id:last.id}:undefined;},enabled:!!session,refetchInterval:30000});
 const read=useMutation({mutationFn:api.markNotificationRead,onSuccess:()=>queries.invalidateQueries({queryKey:['notifications']})});
 if(!ready)return <p>계정을 확인하고 있습니다.</p>;
 if(!session)return <section className="mx-auto flex max-w-lg flex-col items-start gap-4 rounded-2xl border bg-card p-8"><h1 className="text-3xl font-bold">메시지·알림</h1><p className="text-muted-foreground">예약과 거래 메시지, 문의 답변을 확인하세요.</p><Button asChild><Link href={accountHref('/notifications')}>로그인하고 알림 보기</Link></Button></section>;
 return <section className="mx-auto flex max-w-2xl flex-col gap-5"><h1 className="text-3xl font-bold">메시지·알림</h1><p className="text-sm leading-6 text-muted-foreground">예약, 결제, 반납과 메시지 소식을 한 곳에서 확인하세요.</p>
  {list.isPending?<p>알림을 불러오고 있습니다.</p>:null}
  {list.data?.pages.flat().map(n=><article key={n.id} className={`flex flex-col gap-3 rounded-2xl border p-5 ${n.read_at?'bg-card':'border-primary/20 bg-primary/5'}`}><h2 className="text-lg font-semibold">{!n.read_at?<span className="mr-2 text-xs text-primary" aria-label="읽지 않음">●</span>:null}{n.title}</h2><p>{n.body}</p><p className="text-sm text-muted-foreground">{formatKoreaTime(n.created_at)}</p>
   {n.kind==='operations'?<Link className="font-medium text-primary underline underline-offset-4" href="/operations" onClick={()=>read.mutate(n.id)}>운영 관리에서 확인</Link>:n.kind==='support'?<Link className="font-medium text-primary underline underline-offset-4" href="/support" onClick={()=>{read.mutate(n.id);void queries.invalidateQueries({queryKey:['reports']});}}>문의 처리 결과 보기</Link>:n.reservation_id?<Link className="font-medium text-primary underline underline-offset-4" href={`/rentals/${n.reservation_id}`} onClick={()=>read.mutate(n.id)}>거래·메시지 보기</Link>:null}
   {!n.read_at?<Button className="self-start" variant="ghost" disabled={read.isPending} onClick={()=>read.mutate(n.id)}>읽음 표시</Button>:null}
  </article>)}
  {list.data?.pages[0].length===0?<div className="rounded-2xl border border-dashed bg-card px-6 py-10 text-center"><h2 className="text-lg font-semibold">아직 알림이 없어요</h2><p className="mt-2 text-sm text-muted-foreground">예약이나 거래에 변화가 생기면 여기에 알려드려요.</p><Button asChild variant="outline" className="mt-5"><Link href="/rentals">내 거래 확인</Link></Button></div>:null}{list.hasNextPage?<Button variant="outline" disabled={list.isFetchingNextPage} onClick={()=>void list.fetchNextPage()}>이전 알림</Button>:null}<Failure error={list.error??read.error}/>{list.isError?<Button variant="outline" disabled={list.isFetching} onClick={()=>void list.refetch()}>알림 다시 불러오기</Button>:null}
 </section>;
}
