'use client';
import Link from 'next/link';
import {useQuery} from '@tanstack/react-query';
import {categories, categoryLabels, formatWon} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {useExploreState} from '@/lib/explore-state';
import {Failure} from '@/lib/feedback';
import {Input} from '@/components/ui/input';
import {Field, FieldLabel} from '@/components/ui/field';
import {Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter} from '@/components/ui/card';
import {Select, SelectTrigger, SelectValue, SelectContent, SelectGroup, SelectItem} from '@/components/ui/select';
import {ToggleGroup, ToggleGroupItem} from '@/components/ui/toggle-group';
import {Skeleton} from '@/components/ui/skeleton';
import {Empty, EmptyHeader, EmptyTitle, EmptyDescription} from '@/components/ui/empty';

export default function Items() {
  const {api} = useApi();
  const {search, category, concertId, set} = useExploreState();
  const setSearch = (search: string) => set({search});
  const setCategory = (category: string) => set({category});
  const setConcertId = (concertId: string) => set({concertId});
  const concerts = useQuery({queryKey: ['concerts'], queryFn: api.concerts});
  const items = useQuery({queryKey: ['items', concertId, category, search], queryFn: () => api.items({search, category, concertId})});
  return <div className="flex flex-col gap-8">
    <div><h1 className="text-4xl font-bold tracking-tight">콘서트 준비물</h1><p className="mt-3 text-lg text-muted-foreground">필요한 순간에 빌려 쓰세요</p></div>
    <div className="grid items-start gap-10 md:grid-cols-[240px_1fr]">
      <aside className="flex flex-col gap-8 rounded-lg bg-card p-5" aria-label="물품 필터">
        <Field><FieldLabel htmlFor="concert">콘서트</FieldLabel><Select value={concertId || 'all'} onValueChange={v => setConcertId(v === 'all' ? '' : v)}><SelectTrigger id="concert" className="w-full"><SelectValue/></SelectTrigger><SelectContent><SelectGroup><SelectItem value="all">전체 콘서트</SelectItem>{concerts.data?.map(c => <SelectItem key={c.id} value={c.id}>{c.title}</SelectItem>)}</SelectGroup></SelectContent></Select></Field>
        <Field><FieldLabel>품목</FieldLabel><ToggleGroup type="single" value={category || 'all'} onValueChange={v => setCategory(v === 'all' ? '' : v)} orientation="vertical" className="grid w-full grid-cols-2 items-stretch gap-1 md:flex md:flex-col"><ToggleGroupItem value="all" className="justify-start">전체</ToggleGroupItem>{categories.map(c => <ToggleGroupItem key={c} value={c} className="justify-start">{categoryLabels[c]}</ToggleGroupItem>)}</ToggleGroup></Field>
      </aside>
      <section className="flex min-w-0 flex-col gap-6" aria-label="상품 목록">
        <Field><FieldLabel htmlFor="search" className="sr-only">상품 검색</FieldLabel><Input id="search" placeholder="상품 검색" value={search} onChange={e => setSearch(e.target.value)} className="h-12"/></Field>
        <Failure error={items.error ?? concerts.error}/>
        {items.isPending ? <Skeleton className="h-80 w-full"/> : items.data?.length ? <div className="grid gap-6 sm:grid-cols-2 xl:grid-cols-3">{items.data.map(item => <Link key={item.id} href={`/items/${item.id}`} aria-label={item.title}>
          <Card className="h-full overflow-hidden p-0"><CardContent className="p-0">{item.photos[0] ? <img src={item.photos[0]} alt={item.title} className="aspect-square w-full object-cover"/> : null}</CardContent><CardHeader><CardTitle>{item.title}</CardTitle><CardDescription>{categoryLabels[item.category as keyof typeof categoryLabels] ?? item.category}</CardDescription></CardHeader><CardFooter className="flex flex-col items-start gap-1 pb-6"><strong>{formatWon(item.daily_price)} / 일</strong><span className="text-sm text-muted-foreground">보증금 {formatWon(item.deposit)}</span></CardFooter></Card>
        </Link>)}</div> : <Empty><EmptyHeader><EmptyTitle>조건에 맞는 물품이 아직 없습니다.</EmptyTitle><EmptyDescription>검색어나 품목을 바꿔 보세요.</EmptyDescription></EmptyHeader></Empty>}
      </section>
    </div>
  </div>;
}
