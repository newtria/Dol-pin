'use client';
import {useInfiniteQuery} from '@tanstack/react-query';
import {useApi} from '@/lib/providers';
import {type ConcertCursor} from '@dolpin/api-client';
import {Failure} from '@/lib/feedback';
import {Button} from './ui/button';
export function ConcertSelect({value,onChange}:{value:string|null;onChange:(id:string|null)=>void}) {
 const {api}=useApi();const concerts=useInfiniteQuery({queryKey:['concert-options'],queryFn:({pageParam})=>api.concerts(pageParam),initialPageParam:undefined as ConcertCursor|undefined,getNextPageParam:page=>page.nextCursor});
 return <div className="flex flex-col gap-3"><label className="text-sm font-medium">연결할 공연 · 선택<select className="mt-2 block min-h-11 w-full rounded-xl border bg-background p-3 text-sm focus-visible:outline-2 focus-visible:outline-ring" value={value??''} onChange={e=>onChange(e.target.value||null)}><option value="">{concerts.isPending?'공연을 불러오는 중…':'모든 공연에서 사용 가능'}</option>{concerts.data?.pages.flatMap(p=>p.rows).map(c=><option key={c.id} value={c.id}>{c.title} · {c.concert_date}</option>)}</select></label>{concerts.hasNextPage?<Button type="button" variant="outline" disabled={concerts.isFetchingNextPage} onClick={()=>void concerts.fetchNextPage()}>공연 더 보기</Button>:null}<Failure error={concerts.error}/></div>;
}
