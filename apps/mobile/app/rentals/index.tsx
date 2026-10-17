import type {RentalCursor} from '@dolpin/api-client';
import {useState} from 'react';
import {FlatList,Text,Pressable,View} from 'react-native';
import {router,usePathname} from 'expo-router';
import {useInfiniteQuery} from '@tanstack/react-query';
import {formatKoreaTime,formatWon,rentalStatusLabels,rentalTitle,rentalNextStep} from '@dolpin/contracts';
import {api} from '../../src/client';
import {useSession} from '../../src/session';
import {beginSignIn} from '../../src/auth-return';
import {Button,Chip,EmptyState,LoadingState,ErrorText,s,colors} from '../../src/ui';
export default function Rentals(){
 const [activeOnly,setActiveOnly]=useState(true);
 const [role,setRole]=useState<'all'|'borrower'|'lender'>('all');
 const [refreshing,setRefreshing]=useState(false); const pathname=usePathname(); const {session,ready}=useSession(); const rentals=useInfiniteQuery({queryKey:['rentals',session?.user.id,activeOnly],
 queryFn:({pageParam})=>api.rentals({cursor:pageParam,activeOnly}),initialPageParam:undefined as RentalCursor|undefined,
 getNextPageParam:page=>page.nextCursor,enabled:!!session&&pathname==='/rentals',refetchInterval:5000});
 const rows=(rentals.data?.pages.flatMap(page=>page.rows)??[]).filter(r=>role==='all'||(role==='borrower'?r.borrower_id:r.lender_id)===session?.user.id).sort((a,b)=>rentalNextStep(a,session?.user.id).priority-rentalNextStep(b,session?.user.id).priority);
 if(!ready)return <View style={s.content}><LoadingState label="계정을 확인하고 있어요"/></View>;
 if(!session)return <View style={s.content}><EmptyState title="거래를 한곳에서 관리해요" body="예약 수락, 결제, 인수와 반납까지 지금 해야 할 일을 확인할 수 있어요." action="로그인하고 내 거래 보기" onAction={()=>void beginSignIn('/rentals')}/></View>;
 return <FlatList contentContainerStyle={s.content} data={rows} keyExtractor={r=>r.id} refreshing={refreshing} onRefresh={()=>{setRefreshing(true);void rentals.refetch().finally(()=>setRefreshing(false));}}
 ItemSeparatorComponent={()=> <View style={{height:12}}/>}
 ListHeaderComponent={<View style={{gap:16,marginBottom:16}}><Text style={s.title}>내 거래</Text><Text style={s.muted}>확인이 필요한 거래부터 보여드려요.</Text><View style={{flexDirection:'row',gap:8}}><Chip label="진행 중" selected={activeOnly} onPress={()=>setActiveOnly(true)}/><Chip label="전체 이력" selected={!activeOnly} onPress={()=>setActiveOnly(false)}/></View><View style={{flexDirection:'row',gap:8,flexWrap:'wrap'}}><Chip label="전체" selected={role==='all'} onPress={()=>setRole('all')}/><Chip label="빌리는 물품" selected={role==='borrower'} onPress={()=>setRole('borrower')}/><Chip label="빌려주는 물품" selected={role==='lender'} onPress={()=>setRole('lender')}/></View><ErrorText error={rentals.error} retrying={rentals.isFetching} onRetry={()=>{void rentals.refetch();}}/></View>}
 ListFooterComponent={rentals.hasNextPage?<Button label={rentals.isFetchingNextPage?'불러오는 중':'거래 더 보기'} secondary disabled={rentals.isFetching} onPress={()=>{void rentals.fetchNextPage();}}/>:null}
 ListEmptyComponent={rentals.isPending?<LoadingState label="거래를 불러오고 있어요"/>:rentals.isError?null:<EmptyState title={activeOnly?'진행 중인 거래가 없어요':'표시할 거래가 없어요'} body={role==='lender'?'내 물품을 등록하면 이곳에서 예약 요청을 받고 관리할 수 있어요.':'필요한 물품을 둘러보고 날짜를 골라 예약을 요청해 보세요.'} action={role==='lender'?'물품 등록':'물품 둘러보기'} onAction={()=>router.push(role==='lender'?'/items/new':'/')}/>}
 renderItem={({item:r})=>{
 const next=rentalNextStep(r,session.user.id);
 return <Pressable accessibilityRole="button" accessibilityLabel={`${rentalTitle(r)}, ${next.title}, ${next.actionLabel}`} onPress={()=>router.push(`/rentals/${r.id}`)} style={s.card}>
 <View style={[s.row,{justifyContent:'space-between'}]}><Text style={s.muted}>{r.borrower_id===session.user.id?'빌리는 물품':'빌려주는 물품'}</Text><Text style={{color:next.tone==='warning'?colors.error:colors.primary,fontWeight:'600'}}>{rentalStatusLabels[r.status??'']??'상태 확인 필요'}</Text></View><Text style={s.heading}>{rentalTitle(r)}</Text>
 <Text style={s.muted}>{r.starts_at?formatKoreaTime(r.starts_at):r.rental_date}{'\n'}→ {r.ends_at?formatKoreaTime(r.ends_at):r.return_date}</Text>
 <View style={{padding:14,borderRadius:14,backgroundColor:colors.soft,gap:5}}><Text style={[s.label,{color:colors.primary}]}>{next.title}</Text><Text style={s.muted}>{next.body}</Text></View><View style={[s.row,{justifyContent:'space-between'}]}><Text style={s.body}>결제 합계 {formatWon(r.total_paid)}</Text><Text style={{color:colors.primary,fontWeight:'600'}}>{next.actionLabel} →</Text></View>
 </Pressable>;
 }}/>;
}
