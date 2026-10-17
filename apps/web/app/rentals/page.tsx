'use client';
import {useState} from 'react';
import type {RentalCursor} from '@dolpin/api-client';
import Link from 'next/link';
import {useInfiniteQuery} from '@tanstack/react-query';
import {formatKoreaTime,formatWon,rentalStatusLabels,rentalTitle,rentalNextStep} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {accountHref} from '@/components/auth-return';
export default function Rentals(){
 const [activeOnly,setActiveOnly]=useState(true);
 const {api,session,ready}=useApi();const rentals=useInfiniteQuery({queryKey:['rentals',session?.user.id,activeOnly],queryFn:({pageParam})=>api.rentals({cursor:pageParam,activeOnly}),initialPageParam:undefined as RentalCursor|undefined,getNextPageParam:page=>page.nextCursor,enabled:!!session,refetchInterval:5000});
 const rows=rentals.data?.pages.flatMap(page=>page.rows)??[];
 const sorted=activeOnly?[...rows].sort((a,b)=>rentalNextStep(a,session?.user.id).priority-rentalNextStep(b,session?.user.id).priority):rows;
 if(!ready)return <p role="status">계정을 확인하고 있습니다.</p>;
 if(!session)return <section className="mx-auto flex max-w-lg flex-col items-start gap-4 rounded-2xl border bg-card p-8"><h1 className="text-3xl font-bold">내 거래</h1><p className="leading-7 text-muted-foreground">예약 요청부터 결제, 전달과 반납까지 진행 상황을 한 곳에서 확인하세요.</p><Button asChild><Link href={accountHref('/rentals')}>로그인하고 내 거래 보기</Link></Button></section>;
 return <section className="flex flex-col gap-6"><header><p className="mb-2 text-sm font-semibold text-primary">예약부터 반납까지</p><h1 className="text-3xl font-bold">내 거래</h1><p className="mt-2 text-muted-foreground">{activeOnly?'지금 확인이 필요한 거래를 먼저 보여드려요.':'지난 거래와 현재 진행 상황을 함께 확인하세요.'}</p></header><div className="flex gap-2" aria-label="거래 목록 범위"><Button variant={activeOnly?'default':'outline'} aria-pressed={activeOnly} onClick={()=>setActiveOnly(true)}>진행 중</Button><Button variant={!activeOnly?'default':'outline'} aria-pressed={!activeOnly} onClick={()=>setActiveOnly(false)}>전체 이력</Button></div><Failure error={rentals.error}/>
 {rentals.isPending?<p role="status" className="rounded-2xl bg-muted p-6">거래를 불러오고 있습니다.</p>:!rows.length&&!rentals.error?<div className="flex flex-col items-center gap-4 rounded-2xl border border-dashed bg-card px-6 py-12 text-center"><h2 className="text-xl font-semibold">{activeOnly?'진행 중인 거래가 없어요':'아직 거래가 없어요'}</h2><p className="text-sm text-muted-foreground">필요한 물품을 찾고 대여 기간을 선택해 보세요.</p><Button asChild><Link href="/items">물품 둘러보기</Link></Button>{activeOnly?<Button variant="link" onClick={()=>setActiveOnly(false)}>지난 거래 보기</Button>:null}</div>:null}
 <div className="grid gap-4 md:grid-cols-2">{sorted.map(r=>{const next=rentalNextStep(r,session.user.id);return <Link href={`/rentals/${r.id}`} key={r.id} className="group flex flex-col gap-4 rounded-2xl border bg-card p-5 transition-colors hover:border-primary focus-visible:outline-2 focus-visible:outline-ring"><div className="flex flex-wrap items-center justify-between gap-2"><span className="text-xs font-medium text-muted-foreground">{r.borrower_id===session.user.id?'빌리는 거래':'빌려주는 거래'}</span><span className={`rounded-full px-3 py-1 text-xs font-semibold ${next.tone==='action'?'bg-primary/10 text-primary':'bg-muted text-muted-foreground'}`}>{rentalStatusLabels[r.status??'']??'상태 확인 필요'}</span></div><h2 className="text-lg font-bold">{rentalTitle(r)}</h2><p className="text-sm leading-6 text-muted-foreground">{r.starts_at?formatKoreaTime(r.starts_at):r.rental_date}<br/>→ {r.ends_at?formatKoreaTime(r.ends_at):r.return_date}</p><div className="rounded-xl bg-muted/70 p-4"><h3 className={`text-sm font-semibold ${next.tone==='action'?'text-primary':''}`}>{next.title}</h3><p className="mt-1 text-sm leading-6 text-muted-foreground">{next.body}</p></div><div className="mt-auto flex items-center justify-between gap-3 border-t pt-4"><p className="text-sm">대여료 <span className="font-semibold">{formatWon(r.rental_fee)}</span></p><span className="text-sm font-semibold text-primary">{next.actionLabel} →</span></div></Link>;})}</div>
 {rentals.hasNextPage?<Button variant="outline" disabled={rentals.isFetching} onClick={()=>void rentals.fetchNextPage()}>{rentals.isFetchingNextPage?'불러오는 중…':'거래 더 보기'}</Button>:null}{rentals.isError?<Button variant="outline" disabled={rentals.isFetching} onClick={()=>void rentals.refetch()}>거래 다시 불러오기</Button>:null}
 </section>;
}
