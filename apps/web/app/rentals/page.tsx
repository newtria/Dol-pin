'use client';
import {useState} from 'react';
import type {RentalCursor} from '@dolpin/api-client';
import Link from 'next/link';
import {useInfiniteQuery} from '@tanstack/react-query';
import {formatKoreaTime,formatWon,rentalStatusLabels,rentalTitle} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
export default function Rentals(){
 const [activeOnly,setActiveOnly]=useState(true);
 const {api,session}=useApi();const rentals=useInfiniteQuery({queryKey:['rentals',session?.user.id,activeOnly],
 queryFn:({pageParam})=>api.rentals({cursor:pageParam,activeOnly}),initialPageParam:undefined as RentalCursor|undefined,
 getNextPageParam:page=>page.nextCursor,enabled:!!session,refetchInterval:5000});
 const rows=rentals.data?.pages.flatMap(page=>page.rows)??[];
 if(!session)return <Button asChild><Link href="/account">로그인하고 내 거래 보기</Link></Button>;
 return <section className="flex flex-col gap-8"><h1 className="text-3xl font-bold">내 거래</h1><div className="flex gap-3"><Button variant={activeOnly?'default':'outline'} onClick={()=>setActiveOnly(true)}>진행 중</Button><Button variant={!activeOnly?'default':'outline'} onClick={()=>setActiveOnly(false)}>전체 이력</Button></div><Failure error={rentals.error}/>
 {rentals.isPending?<p>거래를 불러오고 있습니다.</p>:!rows.length?<p>아직 거래가 없습니다.</p>:null}
 <div className="grid gap-4 md:grid-cols-2">{rows.map(r=><Link href={`/rentals/${r.id}`} key={r.id} className="flex flex-col gap-3 rounded-lg border p-6 hover:border-primary"><h2 className="text-xl font-semibold">{rentalTitle(r)}</h2><p>{rentalStatusLabels[r.status??'']??'상태 확인 필요'}</p><p className="text-muted-foreground">{r.borrower_id===session.user.id?'빌리는 거래':'빌려주는 거래'}</p><p>{r.starts_at?formatKoreaTime(r.starts_at):r.rental_date}</p><p className="text-primary">{formatWon(r.total_paid)}</p></Link>)}</div>{rentals.hasNextPage?<Button disabled={rentals.isFetching} onClick={()=>{void rentals.fetchNextPage();}}>{rentals.isFetchingNextPage?'불러오는 중':'거래 더 보기'}</Button>:null}</section>;
}
