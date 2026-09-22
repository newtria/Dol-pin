'use client';
import {use} from 'react';
import Link from 'next/link';
import {Button} from '@/components/ui/button';
import {useQuery} from '@tanstack/react-query';
import {formatWon} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Skeleton} from '@/components/ui/skeleton';
export default function Detail({params}: {params: Promise<{id: string}>}) {
  const {id} = use(params); const {api, session} = useApi();
  const item = useQuery({queryKey: ['item', id], queryFn: () => api.item(id)});
  const ownNote = useQuery({queryKey: ['item-private', id, session?.user.id], queryFn: () => api.ownItemPickupNote(id), enabled: !!session && item.data?.lender_id === session.user.id});
  if (item.isPending) return <Skeleton className="h-96 w-full"/>;
  if (!item.data) return <Failure error={item.error ?? new Error('물품을 찾을 수 없습니다.')}/>;
  const data = item.data;
  return <article className="grid gap-12 md:grid-cols-2">
    <div className="flex flex-col gap-4">{data.photos.map((src, i) => <img key={src} src={src} alt={`${data.title} 사진 ${i + 1}`} className="aspect-square w-full rounded-lg object-cover"/>)}</div>
    <div className="flex flex-col gap-6"><h1 className="text-4xl font-bold">{data.title}</h1><p className="text-2xl font-semibold text-primary">{formatWon(data.daily_price)} / 일</p><p className="text-muted-foreground">보증금 {formatWon(data.deposit)}</p><p className="whitespace-pre-wrap leading-8">{data.description}</p><p>만남 지역: {data.pickup_area??'등록된 공개 지역이 없습니다.'}</p><p className="text-muted-foreground">상세 인수·반납 장소는 예약 수락 후 거래 상세에서 확인할 수 있습니다.</p>{data.lender_id===session?.user.id?<><p className="text-muted-foreground">내가 등록한 물품입니다.</p>{ownNote.data?<p>상대에게 안내할 상세 장소: {ownNote.data}</p>:null}<Failure error={ownNote.error}/></>:<Button asChild><Link href={`/items/${id}/reserve`}>대여 기간 선택</Link></Button>}</div>
  </article>;
}
