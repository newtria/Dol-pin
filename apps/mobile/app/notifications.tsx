import {useState} from 'react';
import {ScrollView,Text,View,Linking} from 'react-native';
import {router,usePathname} from 'expo-router';
import {useInfiniteQuery,useMutation,useQueryClient} from '@tanstack/react-query';
import type {ServiceCursor} from '@dolpin/api-client';
import {api} from '../src/client';
import {useSession} from '../src/session';
import {enablePush,disablePush} from '../src/push';
import {beginSignIn} from '../src/auth-return';
import {Button,EmptyState,LoadingState,Section,ErrorText,s,colors} from '../src/ui';
export default function Notifications(){
 const {session,ready}=useSession();const active=usePathname()==='/notifications';const queries=useQueryClient();
 const [settingsOpen,setSettingsOpen]=useState(false);
 const list=useInfiniteQuery({queryKey:['notifications',session?.user.id],queryFn:({pageParam})=>api.notifications(pageParam),initialPageParam:undefined as ServiceCursor|undefined,getNextPageParam:rows=>{const last=rows.at(-1);return rows.length===50&&last?{createdAt:last.created_at,id:last.id}:undefined;},enabled:!!session&&active,refetchInterval:active?30000:false});
 const read=useMutation({mutationFn:api.markNotificationRead,onSuccess:()=>queries.invalidateQueries({queryKey:['notifications']})});
 const push=useMutation({mutationFn:(enable:boolean)=>enable?enablePush():disablePush()});
 const settings=useMutation({mutationFn:()=>Linking.openSettings()});
 return <ScrollView contentContainerStyle={s.content}><Text style={s.title}>메시지·알림</Text><Text style={s.muted}>예약 진행 상황과 상대방의 메시지를 확인하세요.</Text>{!ready?<LoadingState label="계정을 확인하고 있어요"/>:session?<>
  <Button label={settingsOpen?'기기 알림 설정 닫기':'기기 알림 설정'} secondary onPress={()=>setSettingsOpen(!settingsOpen)}/>
  {settingsOpen?<Section title="놓치지 않고 받아보세요" description="이 기기에만 적용됩니다. 앱 설정과 기기 설정에서 모두 알림을 허용해야 받을 수 있어요."><Button label="거래 알림 켜기" disabled={push.isPending} onPress={()=>push.mutate(true)}/><Button label="거래 알림 끄기" secondary disabled={push.isPending} onPress={()=>push.mutate(false)}/><Button label="기기 설정 열기" secondary onPress={()=>settings.mutate()}/>{push.isSuccess?<Text style={s.body}>알림 설정을 반영했습니다.</Text>:null}</Section>:null}
  {list.isPending?<LoadingState label="알림을 불러오고 있어요"/>:null}
  {list.data?.pages.flat().map(n=><View key={n.id} style={[s.card,!n.read_at?{borderColor:colors.primary}:null]}><View style={s.row}>{!n.read_at?<View accessibilityLabel="읽지 않은 알림" style={{width:8,height:8,borderRadius:4,backgroundColor:colors.primary}}/>:null}<Text style={[s.heading,{flex:1}]}>{n.title}</Text></View><Text style={s.body}>{n.body}</Text><Text style={s.muted}>{new Date(n.created_at).toLocaleString('ko-KR')}</Text>
   {n.kind==='operations'?<Text style={s.body}>운영 웹의 ‘운영 관리’에서 확인해 주세요.</Text>:n.kind==='support'?<Button label="문의 처리 결과 보기" onPress={()=>{read.mutate(n.id);void queries.invalidateQueries({queryKey:['reports']});router.push('/support');}}/>:n.reservation_id?<Button label="거래·메시지 보기" onPress={()=>{read.mutate(n.id);router.push(`/rentals/${n.reservation_id}`);}}/>:null}
   {!n.read_at?<Button label="읽음 표시" secondary disabled={read.isPending} onPress={()=>read.mutate(n.id)}/>:null}
  </View>)}
  {list.data?.pages[0].length===0?<EmptyState title="아직 도착한 알림이 없어요" body="예약 상태가 바뀌거나 새 메시지가 오면 이곳에 표시됩니다." action="내 거래 보기" onAction={()=>router.push('/rentals')}/>:null}{list.hasNextPage?<Button label="이전 알림" secondary disabled={list.isFetchingNextPage} onPress={()=>void list.fetchNextPage()}/>:null}
 </>:<EmptyState title="내 알림을 확인하세요" body="로그인하면 거래 소식과 문의 답변을 확인할 수 있어요." action="로그인" onAction={()=>void beginSignIn('/notifications')}/>}<ErrorText error={list.error??read.error??push.error??settings.error} onRetry={list.isError?()=>void list.refetch():undefined} retrying={list.isFetching}/></ScrollView>;
}
