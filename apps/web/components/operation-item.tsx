'use client';
import {useQuery} from '@tanstack/react-query';
import {formatWon} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';

export function OperationItem({id}:{id:string}){
 const {api,session}=useApi();
 const item=useQuery({queryKey:['ops-item',session?.user.id,id],queryFn:()=>api.operationItem(id),gcTime:0,retry:false});
 return <section className="flex flex-col gap-3 rounded border p-5" aria-label="운영 물품 조사">
  <h2 className="text-xl font-semibold">물품 조사</h2><Failure error={item.error}/>
  {item.isPending?<p>물품 정보를 확인하고 있습니다.</p>:null}
  {item.data&&!item.isError?<><h3>{item.data.title}</h3><p className="whitespace-pre-wrap">{item.data.description}</p><p>하루 {formatWon(item.data.daily_price)} · 보증금 {formatWon(item.data.deposit)}</p><p>물품 번호 {id}</p><p>{item.data.moderated_at?'운영 비노출 제한 중':item.data.status==='active'?'공개 중':'소유자 비공개'}</p><div className="flex flex-wrap gap-3">{item.data.photos.map(photo=><img key={photo} src={photo} alt="신고 물품 사진" className="h-48 max-w-full object-contain" referrerPolicy="no-referrer"/>)}</div></>:null}
  <Button variant="outline" disabled={item.isFetching} onClick={()=>void item.refetch()}>물품 다시 조회</Button>
 </section>;
}
