'use client';
import Link from 'next/link';
import {useInfiniteQuery,useMutation,useQueryClient} from '@tanstack/react-query';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {formatWon} from '@dolpin/contracts';
export default function MyItems(){
 const {api,session,ready}=useApi();const queries=useQueryClient();
 const items=useInfiniteQuery({queryKey:['my-items',session?.user.id],queryFn:({pageParam})=>api.myItems(pageParam),initialPageParam:0,getNextPageParam:(rows,_pages,offset)=>rows.length===50?offset+50:undefined,enabled:!!session});
 const visibility=useMutation({mutationFn:({id,status}:{id:string;status:'active'|'hidden'})=>api.setItemStatus(id,status),onSuccess:()=>Promise.all([queries.invalidateQueries({queryKey:['my-items']}),queries.invalidateQueries({queryKey:['items']})])});
 if(!ready)return <p>계정을 확인하고 있습니다.</p>;
 if(!session)return <Link href="/account">로그인하고 내 물품 관리하기</Link>;
 return <section className="flex flex-col gap-6"><h1 className="text-3xl font-bold">내 물품 관리</h1><Link href="/items/new">물품 등록</Link><Failure error={items.error??visibility.error}/>{items.isPending?<p>불러오는 중입니다.</p>:items.data?.pages[0].length===0?<p>등록한 물품이 없습니다.</p>:null}
  {items.data?.pages.flat().map(item=><article key={item.id} className="flex flex-col gap-3 rounded border p-5"><Link href={`/items/${item.id}`}>{item.title}</Link><p>{formatWon(item.daily_price)} / 일 · {item.moderated_at?'운영 검토로 숨김':item.status==='active'?'공개 중':'숨김'}</p><p>{item.available_from??'시작 제한 없음'} ~ {item.available_to??'종료 제한 없음'}</p><Link href={`/items/new?edit=${item.id}`}>물품 수정</Link>{item.moderated_at?<Link href="/support">비노출 조치 문의</Link>:<Button variant="outline" disabled={visibility.isPending} onClick={()=>visibility.mutate({id:item.id,status:item.status==='active'?'hidden':'active'})}>{item.status==='active'?'물품 숨기기':'다시 공개하기'}</Button>}<p className="text-sm text-muted-foreground">숨긴 물품은 새 예약을 받지 않습니다. 진행 중 거래는 유지됩니다.</p></article>)}
  {items.hasNextPage?<Button variant="outline" disabled={items.isFetchingNextPage} onClick={()=>void items.fetchNextPage()}>내 물품 더 보기</Button>:null}{items.isError?<Button variant="outline" disabled={items.isFetching} onClick={()=>void items.refetch()}>다시 불러오기</Button>:null}
 </section>;
}
