import {ScrollView,Text,View,Linking} from 'react-native';
import {router,usePathname} from 'expo-router';
import {useInfiniteQuery,useMutation,useQueryClient} from '@tanstack/react-query';
import type {ServiceCursor} from '@dolpin/api-client';
import {api} from '../src/client';
import {useSession} from '../src/session';
import {enablePush,disablePush} from '../src/push';
import {Button,ErrorText,s} from '../src/ui';
export default function Notifications(){
 const {session,ready}=useSession();const active=usePathname()==='/notifications';const queries=useQueryClient();
 const list=useInfiniteQuery({queryKey:['notifications',session?.user.id],queryFn:({pageParam})=>api.notifications(pageParam),initialPageParam:undefined as ServiceCursor|undefined,getNextPageParam:rows=>{const last=rows.at(-1);return rows.length===50&&last?{createdAt:last.created_at,id:last.id}:undefined;},enabled:!!session&&active,refetchInterval:active?30000:false});
 const read=useMutation({mutationFn:api.markNotificationRead,onSuccess:()=>queries.invalidateQueries({queryKey:['notifications']})});
 const push=useMutation({mutationFn:(enable:boolean)=>enable?enablePush():disablePush()});
 const settings=useMutation({mutationFn:()=>Linking.openSettings()});
 return <ScrollView contentContainerStyle={s.content}><Text style={s.title}>메시지·알림</Text>{!ready?<Text style={s.body}>계정을 확인하고 있습니다.</Text>:session?<>
  <Button label="이 기기에서 거래 알림 켜기" disabled={push.isPending} onPress={()=>push.mutate(true)}/><Button label="이 기기에서 거래 알림 끄기" secondary disabled={push.isPending} onPress={()=>push.mutate(false)}/><Button label="기기 알림 설정" secondary onPress={()=>settings.mutate()}/>{push.isSuccess?<Text style={s.body}>알림 설정을 반영했습니다.</Text>:null}
  {list.isPending?<Text style={s.body}>알림을 불러오고 있습니다.</Text>:null}
  {list.data?.pages.flat().map(n=><View key={n.id} style={s.card}><Text style={s.heading}>{n.read_at?'':'● '}{n.title}</Text><Text style={s.body}>{n.body}</Text><Text style={s.muted}>{new Date(n.created_at).toLocaleString('ko-KR')}</Text>
   {n.kind==='operations'?<Text style={s.body}>운영 웹의 ‘운영 관리’에서 확인해 주세요.</Text>:n.kind==='support'?<Button label="문의 처리 결과 보기" onPress={()=>{read.mutate(n.id);void queries.invalidateQueries({queryKey:['reports']});router.push('/support');}}/>:n.reservation_id?<Button label="거래·메시지 보기" onPress={()=>{read.mutate(n.id);router.push(`/rentals/${n.reservation_id}`);}}/>:null}
   {!n.read_at?<Button label="읽음 표시" secondary disabled={read.isPending} onPress={()=>read.mutate(n.id)}/>:null}
  </View>)}
  {list.data?.pages[0].length===0?<Text style={s.body}>새 알림이 없습니다.</Text>:null}{list.hasNextPage?<Button label="이전 알림" secondary disabled={list.isFetchingNextPage} onPress={()=>void list.fetchNextPage()}/>:null}
 </>:<Button label="로그인" onPress={()=>router.push('/account')}/>}<ErrorText error={list.error??read.error??push.error??settings.error} onRetry={list.isError?()=>void list.refetch():undefined} retrying={list.isFetching}/></ScrollView>;
}
