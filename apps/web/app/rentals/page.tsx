'use client';
import Link from 'next/link';
import {useQuery} from '@tanstack/react-query';
import {formatKoreaTime,formatWon,rentalStatusLabels,rentalTitle} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
export default function Rentals(){
 const {api,session}=useApi();const rentals=useQuery({queryKey:['rentals'],queryFn:api.rentals,enabled:!!session});
 if(!session)return <Button asChild><Link href="/account">로그인하고 내 거래 보기</Link></Button>;
 return <section className="flex flex-col gap-8"><h1 className="text-3xl font-bold">내 거래</h1><Failure error={rentals.error}/>
 {rentals.isPending?<p>거래를 불러오고 있습니다.</p>:!rentals.data?.length?<p>아직 거래가 없습니다.</p>:null}
 <div className="grid gap-4 md:grid-cols-2">{rentals.data?.map(r=><Link href={`/rentals/${r.id}`} key={r.id} className="flex flex-col gap-3 rounded-lg border p-6 hover:border-primary"><h2 className="text-xl font-semibold">{rentalTitle(r)}</h2><p>{rentalStatusLabels[r.status??'']??'상태 확인 필요'}</p><p className="text-muted-foreground">{r.borrower_id===session.user.id?'빌리는 거래':'빌려주는 거래'}</p><p>{r.starts_at?formatKoreaTime(r.starts_at):r.rental_date}</p><p className="text-primary">{formatWon(r.total_paid)}</p></Link>)}</div></section>;
}
