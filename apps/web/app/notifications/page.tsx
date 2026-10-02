'use client';
import Link from 'next/link';
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
 if(!session)return <Link href="/account">로그인하고 알림 보기</Link>;
 return <section className="mx-auto flex max-w-xl flex-col gap-5"><h1 className="text-3xl font-bold">메시지·알림</h1><p>앱을 닫아도 알림을 받으려면 모바일 앱에서 거래 알림을 켜 주세요.</p>
  {list.isPending?<p>알림을 불러오고 있습니다.</p>:null}
  {list.data?.pages.flat().map(n=><article key={n.id} className="flex flex-col gap-3 rounded border p-4"><h2 className="text-lg font-semibold">{n.read_at?'':'● '}{n.title}</h2><p>{n.body}</p><p className="text-sm text-muted-foreground">{new Date(n.created_at).toLocaleString('ko-KR')}</p>
   {n.kind==='operations'?<Link href="/operations" onClick={()=>read.mutate(n.id)}>운영 관리에서 확인</Link>:n.kind==='support'?<Link href="/support" onClick={()=>{read.mutate(n.id);void queries.invalidateQueries({queryKey:['reports']});}}>문의 처리 결과 보기</Link>:n.reservation_id?<Link href={`/rentals/${n.reservation_id}`} onClick={()=>read.mutate(n.id)}>거래·메시지 보기</Link>:null}
   {!n.read_at?<Button variant="outline" disabled={read.isPending} onClick={()=>read.mutate(n.id)}>읽음 표시</Button>:null}
  </article>)}
  {list.data?.pages[0].length===0?<p>새 알림이 없습니다.</p>:null}{list.hasNextPage?<Button variant="outline" disabled={list.isFetchingNextPage} onClick={()=>void list.fetchNextPage()}>이전 알림</Button>:null}<Failure error={list.error??read.error}/>{list.isError?<Button variant="outline" disabled={list.isFetching} onClick={()=>void list.refetch()}>알림 다시 불러오기</Button>:null}
 </section>;
}
