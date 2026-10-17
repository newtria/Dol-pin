'use client';

import {Suspense, use} from 'react';
import Link from 'next/link';
import {useSearchParams} from 'next/navigation';
import {useQuery} from '@tanstack/react-query';
import {ArrowLeft, ArrowRight, CalendarDays, MapPin, Handshake, RotateCcw} from 'lucide-react';
import {categoryLabels, formatWon, rentalEstimate} from '@dolpin/contracts';
import {Button} from '@/components/ui/button';
import {Skeleton} from '@/components/ui/skeleton';
import {Alert, AlertTitle, AlertDescription} from '@/components/ui/alert';
import {ProductGallery} from '@/components/product-gallery';
import {ItemReport} from '@/components/item-report';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {localExploreTime} from '@/lib/explore-state';

export default function Detail({params}: {params: Promise<{id: string}>}) {
  const {id} = use(params);
  return <Suspense fallback={<DetailSkeleton/>}><ItemDetail key={id} id={id}/></Suspense>;
}

function DetailSkeleton() {
  return <div className="flex flex-col gap-6" aria-label="물품을 불러오는 중"><Skeleton className="h-10 w-2/3"/><div className="grid gap-6 md:grid-cols-2"><Skeleton className="aspect-[4/3] w-full"/><Skeleton className="h-80 w-full"/></div></div>;
}

function ItemDetail({id}: {id: string}) {
  const {api, session} = useApi();
  const params = useSearchParams();
  const item = useQuery({queryKey: ['item', id], queryFn: () => api.item(id)});
  const own = !!session && item.data?.lender_id === session.user.id;
  const ownNote = useQuery({queryKey: ['item-private', id, session?.user.id], queryFn: () => api.ownItemPickupNote(id), enabled: own});
  const reserveParams = new URLSearchParams();
  const startsAt = localExploreTime(params.get('startsAt')), endsAt = localExploreTime(params.get('endsAt'));
  if (startsAt) reserveParams.set('startsAt', startsAt);
  if (endsAt) reserveParams.set('endsAt', endsAt);
  const reserveHref = `/items/${id}/reserve${reserveParams.size ? `?${reserveParams}` : ''}`;
  const exploreParams = new URLSearchParams();
  for (const key of ['search', 'category', 'concertId', 'pickupArea', 'startsAt', 'endsAt']) {
    const value = params.get(key); if (value) exploreParams.set(key, value);
  }
  const backHref = `/items${exploreParams.size ? `?${exploreParams}` : ''}`;
  if (item.isPending) return <DetailSkeleton/>;
  if (!item.data) return <div className="surface flex flex-col items-start gap-5"><h1 className="page-heading">물품을 확인할 수 없어요</h1><Failure error={item.error ?? new Error('물품이 숨겨졌거나 더 이상 제공되지 않습니다.')}/><Button variant="outline" onClick={() => {void item.refetch();}}>다시 불러오기</Button><Button asChild><Link href={backHref}>다른 물품 찾기</Link></Button></div>;
  const data = item.data;
  const estimate = rentalEstimate(startsAt, endsAt, data.daily_price, data.deposit);
  const unavailable = data.status !== 'active';

  return <article className="flex flex-col gap-6 pb-24 md:pb-0">
    <Link href={backHref} className="inline-flex min-h-11 w-fit items-center gap-2 text-sm text-muted-foreground"><ArrowLeft className="size-4" aria-hidden="true"/>물품 탐색으로</Link>
    <header className="flex flex-col gap-2"><p className="eyebrow">{categoryLabels[data.category as keyof typeof categoryLabels] ?? data.category} · 직접 만나서 대여</p><h1 className="page-heading break-words">{data.title}</h1><p className="flex items-center gap-1.5 text-sm text-muted-foreground"><MapPin className="size-4 shrink-0" aria-hidden="true"/>{data.pickup_area || '만남 지역 확인 필요'}</p></header>
    <div className="grid items-start gap-6 lg:grid-cols-[minmax(0,1.3fr)_minmax(320px,1fr)] lg:gap-10">
      <ProductGallery key={id} photos={data.photos} title={data.title} category={data.category}/>
      <aside className="surface flex flex-col gap-5 lg:sticky lg:top-24 lg:row-span-2" aria-label="대여 금액과 예약">
        <div><p className="text-sm text-muted-foreground">{estimate ? `선택한 기간 · ${estimate.days}일 대여료` : '하루 대여료 · 24시간 기준'}</p><p className="mt-1 text-3xl font-extrabold tracking-tight">{formatWon(estimate?.fee ?? data.daily_price)}</p></div>
        <dl className="flex flex-col gap-3 border-y py-4 text-sm"><div className="flex flex-wrap justify-between gap-2"><dt className="text-muted-foreground">반납 확인 후 돌려받는 보증금</dt><dd className="font-semibold">{formatWon(data.deposit)}</dd></div>{estimate ? <div className="flex justify-between gap-2"><dt className="font-semibold">예상 총 결제액</dt><dd className="text-lg font-bold text-primary">{formatWon(estimate.total)}</dd></div> : null}</dl>
        {data.available_from || data.available_to ? <div className="flex items-start gap-2 text-sm"><CalendarDays className="mt-0.5 size-4 shrink-0 text-primary" aria-hidden="true"/><div><p className="font-semibold">등록된 대여 가능 기간</p><p className="mt-1 text-muted-foreground">{data.available_from ?? '시작일 제한 없음'} ~ {data.available_to ?? '종료일 제한 없음'}</p></div></div> : null}
        {own ? <><Alert><AlertTitle>내가 빌려주는 물품이에요</AlertTitle><AlertDescription>가격과 대여 가능 기간을 최신 상태로 관리해 주세요.</AlertDescription></Alert><Button asChild><Link href={`/items/new?edit=${id}`}>물품 수정</Link></Button><Button asChild variant="outline"><Link href="/items/mine">내 물품 관리</Link></Button></>
          : unavailable ? <Alert><AlertTitle>지금은 예약할 수 없는 물품이에요</AlertTitle><AlertDescription><Link href={backHref} className="underline underline-offset-4">다른 물품을 찾아보세요.</Link></AlertDescription></Alert>
          : <><Button asChild size="lg"><Link href={reserveHref}>{estimate ? '선택한 날짜로 예약하기' : '대여 기간 선택'}<ArrowRight data-icon="inline-end" aria-hidden="true"/></Link></Button><p className="text-center text-xs text-muted-foreground">로그인 없이 일정과 예상 금액을 확인할 수 있어요.</p><p className="text-sm text-muted-foreground">예약 요청 후 상대가 수락하면 결제해요. 결제 전까지 물품이 확정된 것은 아니에요.</p></>}
      </aside>
      <div className="flex flex-col gap-6">
        <section className="surface flex flex-col gap-4"><h2 className="text-xl font-bold">물품 소개</h2><p className="whitespace-pre-wrap leading-8">{data.description || '추가 설명이 등록되지 않았어요. 거래 메시지에서 필요한 내용을 확인해 주세요.'}</p></section>
        <section className="surface flex flex-col gap-5"><h2 className="text-xl font-bold">수령부터 반납까지</h2>
          <div className="flex items-start gap-3"><Handshake className="mt-1 size-5 shrink-0 text-primary" aria-hidden="true"/><div><h3 className="font-semibold">직접 만나서 물품을 확인해요</h3><p className="mt-1 text-sm text-muted-foreground">{data.pickup_area || '안내된 만남 지역'}에서 만나요. 상세 장소는 예약 수락 후 거래 화면에서 확인할 수 있어요. 물품 상태와 구성품을 함께 확인한 뒤 수령을 완료해 주세요.</p></div></div>
          <div className="flex items-start gap-3"><RotateCcw className="mt-1 size-5 shrink-0 text-primary" aria-hidden="true"/><div><h3 className="font-semibold">약속한 시간에 반납해요</h3><p className="mt-1 text-sm text-muted-foreground">반납할 때 사진을 남기고, 빌려준 분의 확인 후 보증금 반환이 진행돼요. 문제가 생기면 거래 화면에서 문의할 수 있어요.</p></div></div>
          {own && ownNote.data ? <p className="rounded-xl bg-secondary p-4 text-sm"><strong>거래 상대에게 안내할 장소</strong><br/>{ownNote.data}</p> : null}<Failure error={ownNote.error}/>
        </section>
        {!own ? <ItemReport key={`${id}:${session?.user.id}`} id={id}/> : null}
      </div>
    </div>
    {!own && !unavailable ? <div className="fixed inset-x-0 bottom-[calc(4.75rem+env(safe-area-inset-bottom))] z-30 flex items-center justify-between gap-4 border-y bg-card px-4 py-3 md:hidden"><div className="min-w-0"><p className="text-xs text-muted-foreground">{estimate ? `${estimate.days}일 대여료` : '하루 대여료'}</p><p className="text-lg font-bold">{formatWon(estimate?.fee ?? data.daily_price)}</p></div><Button asChild><Link href={reserveHref}>날짜·금액 확인<ArrowRight data-icon="inline-end" aria-hidden="true"/></Link></Button></div> : null}
  </article>;
}
