import {ScrollView,Text,View} from 'react-native';
import {router} from 'expo-router';
import {useInfiniteQuery,useMutation,useQueryClient} from '@tanstack/react-query';
import {api} from '../../src/client';
import {useSession} from '../../src/session';
import {Button,ErrorText,s} from '../../src/ui';
import {formatWon} from '@dolpin/contracts';
export default function MyItems(){
 const {session,ready}=useSession();const queries=useQueryClient();
 const items=useInfiniteQuery({queryKey:['my-items',session?.user.id],queryFn:({pageParam})=>api.myItems(pageParam),initialPageParam:0,getNextPageParam:(rows,_pages,offset)=>rows.length===50?offset+50:undefined,enabled:!!session});
 const visibility=useMutation({mutationFn:({id,status}:{id:string;status:'active'|'hidden'})=>api.setItemStatus(id,status),onSuccess:()=>Promise.all([queries.invalidateQueries({queryKey:['my-items']}),queries.invalidateQueries({queryKey:['items']})])});
 return <ScrollView contentContainerStyle={s.content}><Text style={s.title}>내 물품 관리</Text>{!ready?<Text style={s.body}>계정을 확인하고 있습니다.</Text>:!session?<Button label="로그인" onPress={()=>router.push('/account')}/>:<>
  <Button label="물품 등록" onPress={()=>router.push('/items/new')}/>{items.isPending?<Text style={s.body}>불러오는 중입니다.</Text>:items.data?.pages[0].length===0?<Text style={s.body}>등록한 물품이 없습니다.</Text>:null}
  {items.data?.pages.flat().map(item=><View key={item.id} style={s.card}><Text style={s.heading}>{item.title}</Text><Text style={s.body}>{formatWon(item.daily_price)} / 일 · {item.moderated_at?'운영 검토로 숨김':item.status==='active'?'공개 중':'숨김'}</Text><Text style={s.muted}>{item.available_from??'시작 제한 없음'} ~ {item.available_to??'종료 제한 없음'}</Text><Button label="물품 보기" secondary onPress={()=>router.push(`/items/${item.id}`)}/><Button label="물품 수정" onPress={()=>router.push(`/items/new?edit=${item.id}`)}/>{item.moderated_at?<Button label="비노출 조치 문의" secondary onPress={()=>router.push('/support')}/>:<Button label={item.status==='active'?'물품 숨기기':'다시 공개하기'} secondary disabled={visibility.isPending} onPress={()=>visibility.mutate({id:item.id,status:item.status==='active'?'hidden':'active'})}/>}<Text style={s.muted}>숨겨도 진행 중 거래는 유지됩니다.</Text></View>)}
  {items.hasNextPage?<Button label="내 물품 더 보기" secondary disabled={items.isFetchingNextPage} onPress={()=>void items.fetchNextPage()}/>:null}
 </>}<ErrorText error={items.error??visibility.error} onRetry={items.isError?()=>void items.refetch():undefined} retrying={items.isFetching}/></ScrollView>;
}
