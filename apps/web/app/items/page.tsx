'use client';

import Link from 'next/link';
import {Suspense, useState} from 'react';
import {useInfiniteQuery} from '@tanstack/react-query';
import {Search, MapPin, CalendarDays, ArrowRight, PackageOpen, RotateCcw, Camera, Smartphone, WandSparkles, Shirt, Flag, Shapes, ChevronDown} from 'lucide-react';
import type {RentalCursor, ConcertCursor} from '@dolpin/api-client';
import {categories, categoryLabels, formatWon, koreaTime, rentalEstimate, rentalPeriodConflict} from '@dolpin/contracts';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Field, FieldLabel, FieldGroup, FieldDescription} from '@/components/ui/field';
import {Select, SelectTrigger, SelectValue, SelectContent, SelectGroup, SelectItem} from '@/components/ui/select';
import {ToggleGroup, ToggleGroupItem} from '@/components/ui/toggle-group';
import {Skeleton} from '@/components/ui/skeleton';
import {Empty, EmptyHeader, EmptyTitle, EmptyDescription, EmptyContent, EmptyMedia} from '@/components/ui/empty';
import {ProductImage} from '@/components/product-gallery';
import {useApi} from '@/lib/providers';
import {useExploreState, type ExploreFilters} from '@/lib/explore-state';
import {Failure} from '@/lib/feedback';

const categoryIcons = {lightstick: WandSparkles, phone: Smartphone, camera: Camera, slogan: Flag, costume: Shirt, etc: Shapes};
const cleared: ExploreFilters = {search: '', category: '', concertId: '', pickupArea: '', startsAt: '', endsAt: ''};

export default function ItemsPage() {
  return <Suspense fallback={<CatalogueSkeleton/>}><Items/></Suspense>;
}

function CatalogueSkeleton() {
  return <div aria-label="물품을 불러오는 중" className="flex flex-col gap-6"><Skeleton className="h-32 w-full"/><Skeleton className="h-32 w-full"/><div className="grid grid-cols-2 gap-4 md:grid-cols-3">{[0, 1, 2].map(i => <Skeleton key={i} className="aspect-[3/4]"/>)}</div></div>;
}

function Items() {
  const {api} = useApi();
  const filters = useExploreState();
  const {search, category, concertId, pickupArea, startsAt, endsAt, set} = filters;
  const periodError = startsAt || endsAt ? rentalPeriodConflict(startsAt, endsAt, []) : null;
  const range = startsAt && endsAt && !periodError ? {startsAt: koreaTime(startsAt), endsAt: koreaTime(endsAt)} : {};
  const concerts = useInfiniteQuery({queryKey: ['concerts'], queryFn: ({pageParam}) => api.concerts(pageParam), initialPageParam: undefined as ConcertCursor | undefined, getNextPageParam: page => page.nextCursor});
  const items = useInfiniteQuery({queryKey: ['items', concertId, category, search, pickupArea, startsAt, endsAt], queryFn: ({pageParam}) => api.items({search, category, concertId, pickupArea, ...range}, pageParam), initialPageParam: undefined as RentalCursor | undefined, getNextPageParam: page => page.nextCursor, enabled: !periodError});
  const rows = items.data?.pages.flatMap(page => page.rows) ?? [];
  const concertRows = concerts.data?.pages.flatMap(page => page.rows) ?? [];
  const selectedConcert = concertRows.find(concert => concert.id === concertId);
  const hasFilters = !!(search || category || concertId || pickupArea || startsAt || endsAt);
  const dateParams = new URLSearchParams();
  if (search) dateParams.set('search', search);
  if (category) dateParams.set('category', category);
  if (concertId) dateParams.set('concertId', concertId);
  if (pickupArea) dateParams.set('pickupArea', pickupArea);
  if (startsAt) dateParams.set('startsAt', startsAt);
  if (endsAt) dateParams.set('endsAt', endsAt);
  const suffix = dateParams.size ? `?${dateParams}` : '';

  return <div className="flex flex-col gap-6 md:gap-10">
    <section className="flex flex-col justify-between gap-5 sm:flex-row sm:items-end" aria-labelledby="explore-title">
      <div className="flex flex-col gap-3"><p className="eyebrow hidden sm:block">LESS TO CARRY. MORE TO ENJOY.</p><h1 id="explore-title" className="page-heading">공연 준비, 가볍게.</h1><p className="max-w-xl text-sm text-muted-foreground sm:text-base">응원봉부터 촬영 장비까지. 필요한 날짜에, 만날 수 있는 곳에서 빌려요.</p></div>
      <Link href="/items/mine" className="hidden min-h-11 shrink-0 items-center gap-2 text-sm font-semibold text-primary sm:inline-flex">내가 빌려주는 물품<ArrowRight className="size-4" aria-hidden="true"/></Link>
    </section>

    <section aria-label="대여 조건 검색" className="surface">
      <SearchForm key={JSON.stringify([search, pickupArea, startsAt, endsAt, concertId])} filters={filters} onApply={set}
        concerts={concertRows.map(concert => ({id: concert.id, title: concert.title, date: concert.concert_date}))}
        loadConcerts={concerts.hasNextPage ? () => {void concerts.fetchNextPage();} : undefined} concertsLoading={concerts.isFetching}/>
      <Failure error={concerts.error}/>
    </section>

    <section aria-label="물품 목록" className="flex flex-col gap-6">
      <div className="overflow-x-auto pb-2">
        <ToggleGroup type="single" spacing={2} value={category || 'all'} onValueChange={value => set({category: value === 'all' ? '' : value})} className="w-max min-w-full justify-start gap-2" aria-label="품목">
          <ToggleGroupItem value="all" className="min-h-12 shrink-0 rounded-full border px-5">전체</ToggleGroupItem>
          {categories.map(value => {const Icon = categoryIcons[value]; return <ToggleGroupItem key={value} value={value} className="min-h-12 shrink-0 gap-2 rounded-full border px-5"><Icon aria-hidden="true" className="size-4"/>{categoryLabels[value]}</ToggleGroupItem>;})}
        </ToggleGroup>
      </div>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div><h2 className="text-xl font-bold">{selectedConcert ? `${selectedConcert.title} 준비물` : hasFilters ? '조건에 맞는 물품' : '빌릴 수 있는 물품'}</h2><p className="mt-1 text-sm text-muted-foreground">{startsAt && !periodError ? '선택한 기간에 맞는 물품을 찾아요. 최종 예약 가능 여부는 요청할 때 다시 확인합니다.' : '날짜와 만남 지역을 선택하면 필요한 물품을 더 빠르게 찾을 수 있어요.'}</p></div>
        {hasFilters ? <Button variant="ghost" size="sm" onClick={() => set(cleared)}><RotateCcw data-icon="inline-start" aria-hidden="true"/>조건 초기화</Button> : null}
      </div>
      <div aria-live="polite" className="sr-only">{!periodError && !items.isPending && !items.error ? `${rows.length}개 물품을 불러왔습니다.${items.hasNextPage ? ' 더 불러올 수 있습니다.' : ''}` : ''}</div>
      <Failure error={items.error}/>
      {periodError ? <p role="alert" className="rounded-xl border border-destructive/30 bg-card p-5 text-destructive">{periodError} 검색 날짜를 수정해 주세요.</p> : items.isPending ? <div className="grid grid-cols-2 gap-4 md:grid-cols-3">{[0, 1, 2, 3, 4, 5].map(i => <Skeleton key={i} className="aspect-[3/4] rounded-2xl"/>)}</div>
      : rows.length ? <div className="grid grid-cols-2 gap-x-4 gap-y-8 md:grid-cols-3 lg:gap-x-6">{rows.map(item => {
        const estimate = startsAt && endsAt ? rentalEstimate(startsAt, endsAt, item.daily_price, item.deposit) : null;
        return <Link key={item.id} href={`/items/${item.id}${suffix}`} className="group flex min-w-0 flex-col gap-3 rounded-2xl outline-offset-4">
          <div className="relative overflow-hidden rounded-2xl bg-secondary"><ProductImage src={item.photos[0]} alt={item.title} category={item.category} className="aspect-[4/3] w-full object-cover transition-transform duration-300 group-hover:scale-[1.025]"/>
            <span className="absolute bottom-3 left-3 rounded-full bg-card/95 px-2.5 py-1 text-xs font-semibold">{categoryLabels[item.category as keyof typeof categoryLabels] ?? item.category}</span>
          </div>
          <div className="flex min-w-0 flex-col gap-1.5 px-1"><h3 className="line-clamp-2 text-base font-semibold leading-snug group-hover:text-primary sm:text-lg">{item.title}</h3>
            <p className="flex items-center gap-1 text-xs text-muted-foreground sm:text-sm"><MapPin className="size-3.5 shrink-0" aria-hidden="true"/><span className="truncate">{item.pickup_area || '만남 지역 확인 필요'}</span></p>
            <p className="mt-1"><strong className="text-lg font-extrabold sm:text-xl">{formatWon(estimate?.fee ?? item.daily_price)}</strong><span className="ml-1 text-xs text-muted-foreground">/ {estimate ? `${estimate.days}일 대여료` : '24시간'}</span></p>
            <p className="text-xs text-muted-foreground">반환 보증금 {formatWon(item.deposit)}{estimate ? ` · 총 ${formatWon(estimate.total)}` : ''}</p>
          </div>
        </Link>;
      })}</div>
      : !items.error ? <Empty className="min-h-72 border bg-card"><EmptyHeader><EmptyMedia variant="icon"><PackageOpen aria-hidden="true"/></EmptyMedia><EmptyTitle>{hasFilters ? '이 조건에 맞는 물품이 없어요' : '아직 등록된 물품이 없어요'}</EmptyTitle><EmptyDescription>{hasFilters ? '만남 지역을 넓히거나 다른 날짜로 찾아보세요. 선택한 조건은 위에서 바로 바꿀 수 있어요.' : '빌려줄 수 있는 공연 물품이 있다면 첫 물품을 등록해 보세요.'}</EmptyDescription></EmptyHeader><EmptyContent>{hasFilters ? <Button variant="outline" onClick={() => set(cleared)}>모든 물품 보기</Button> : <Button asChild><Link href="/items/new">물품 등록하기</Link></Button>}</EmptyContent></Empty> : <Button variant="outline" onClick={() => {void items.refetch();}}>물품 다시 불러오기</Button>}
      {items.hasNextPage ? <Button variant="outline" className="mx-auto min-w-48" disabled={items.isFetching} onClick={() => {void items.fetchNextPage();}}>{items.isFetchingNextPage ? '물품을 불러오는 중…' : '물품 더 보기'}</Button> : null}
    </section>
    <aside className="grid gap-5 rounded-2xl border px-6 py-5 text-sm sm:grid-cols-3" aria-label="대여 이용 순서">
      {[['01', '날짜와 장소 선택', '내 일정에 맞는 물품을 찾아요.'], ['02', '수락 후 결제', '상대가 수락하면 금액을 확인하고 결제해요.'], ['03', '만나서 수령·반납', '서로 확인하고, 반납 후 보증금을 돌려받아요.']].map(([number, title, description]) => <div key={number} className="flex items-start gap-3"><span className="eyebrow pt-1">{number}</span><div><p className="font-semibold">{title}</p><p className="mt-1 text-muted-foreground">{description}</p></div></div>)}
    </aside>
  </div>;
}

function SearchForm({filters, concerts, onApply, loadConcerts, concertsLoading}: {filters: ExploreFilters; concerts: {id: string; title: string; date: string}[]; onApply: (values: Partial<ExploreFilters>) => void; loadConcerts?: () => void; concertsLoading: boolean}) {
  const [values, setValues] = useState(filters);
  const [error, setError] = useState<string | null>(null);
  const [expanded, setExpanded] = useState(!!(filters.pickupArea || filters.startsAt || filters.endsAt || filters.concertId));
  const field = (key: keyof ExploreFilters, value: string) => {setValues(current => ({...current, [key]: value})); setError(null);};
  return <form onSubmit={event => {
    event.preventDefault();
    const problem = values.startsAt || values.endsAt ? rentalPeriodConflict(values.startsAt, values.endsAt, []) : null;
    if (problem) {setError(problem); setExpanded(true); return;}
    const {search, pickupArea, startsAt, endsAt, concertId} = values;
    onApply({search: search.trim(), pickupArea: pickupArea.trim(), startsAt, endsAt, concertId});
  }}>
    <FieldGroup className="gap-3 sm:gap-4">
      <div className="grid min-w-0 items-end gap-3 grid-cols-[minmax(0,1fr)_auto]">
        <Field><FieldLabel htmlFor="explore-search" className="sr-only sm:not-sr-only"><Search className="size-4" aria-hidden="true"/>찾는 물품</FieldLabel><Input id="explore-search" value={values.search} maxLength={80} onChange={event => field('search', event.target.value)} placeholder="응원봉, 카메라, 상품명"/></Field>
        <Button type="submit" size="lg" aria-label="물품 찾기"><Search data-icon="inline-start" aria-hidden="true"/><span className="hidden sm:inline">물품 </span>찾기</Button>
      </div>
      <button type="button" aria-expanded={expanded} aria-controls="explore-conditions" onClick={() => setExpanded(value => !value)} className="flex min-h-11 items-center justify-between gap-2 rounded-lg text-sm font-semibold text-primary sm:hidden"><span>날짜·지역·공연 조건</span><ChevronDown aria-hidden="true" className={`size-4 transition-transform ${expanded ? 'rotate-180' : ''}`}/></button>
      <div id="explore-conditions" className={`${expanded ? 'grid' : 'hidden'} min-w-0 gap-4 sm:grid sm:grid-cols-2 lg:grid-cols-4`}>
        <Field><FieldLabel htmlFor="explore-concert">어느 공연에 가세요?</FieldLabel><Select value={values.concertId || 'all'} onValueChange={value => field('concertId', value === 'all' ? '' : value)}><SelectTrigger id="explore-concert" className="w-full"><SelectValue/></SelectTrigger><SelectContent><SelectGroup><SelectItem value="all">모든 공연</SelectItem>{concerts.map(concert => <SelectItem key={concert.id} value={concert.id}>{concert.title} · {concert.date}</SelectItem>)}</SelectGroup></SelectContent></Select>{loadConcerts ? <Button type="button" variant="link" size="sm" disabled={concertsLoading} onClick={loadConcerts}>공연 더 보기</Button> : null}</Field>
        <Field><FieldLabel htmlFor="explore-area"><MapPin className="size-4" aria-hidden="true"/>만남 지역</FieldLabel><Input id="explore-area" value={values.pickupArea} maxLength={100} onChange={event => field('pickupArea', event.target.value)} placeholder="예: 잠실, 홍대, KSPO"/></Field>
        <Field data-invalid={!!error}><FieldLabel htmlFor="explore-start"><CalendarDays className="size-4" aria-hidden="true"/>수령 일시 <span className="font-normal text-muted-foreground">선택</span></FieldLabel><Input id="explore-start" type="datetime-local" value={values.startsAt} onChange={event => field('startsAt', event.target.value)} aria-invalid={!!error} aria-describedby={error ? 'explore-period-error' : 'explore-date-hint'}/></Field>
        <Field data-invalid={!!error}><FieldLabel htmlFor="explore-end">반납 일시</FieldLabel><Input id="explore-end" type="datetime-local" min={values.startsAt || undefined} value={values.endsAt} onChange={event => field('endsAt', event.target.value)} aria-invalid={!!error} aria-describedby={error ? 'explore-period-error' : 'explore-date-hint'}/></Field>
        {error ? <p id="explore-period-error" role="alert" className="text-sm text-destructive sm:col-span-2 lg:col-span-4">{error}</p> : <FieldDescription id="explore-date-hint" className="sm:col-span-2 lg:col-span-4">날짜를 입력하면 예약이 겹치지 않는 물품과 기간별 대여료를 보여드려요. 한국 시간 기준입니다.</FieldDescription>}
        <Button type="submit" size="lg" className="sm:hidden">선택한 조건으로 찾기</Button>
      </div>
    </FieldGroup>
  </form>;
}
