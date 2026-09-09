import type {RentalCursor} from '@dolpin/api-client';
import {useState} from 'react';
import {FlatList,Text,Pressable,ActivityIndicator,View} from 'react-native';
import {router,usePathname} from 'expo-router';
import {useInfiniteQuery} from '@tanstack/react-query';
import {formatKoreaTime,formatWon,rentalStatusLabels,rentalTitle} from '@dolpin/contracts';
import {api} from '../../src/client';
import {useSession} from '../../src/session';
import {Button,ErrorText,s,colors} from '../../src/ui';
export default function Rentals(){
 const [activeOnly,setActiveOnly]=useState(true);
 const [refreshing,setRefreshing]=useState(false); const pathname=usePathname(); const {session}=useSession(); const rentals=useInfiniteQuery({queryKey:['rentals',session?.user.id,activeOnly],
 queryFn:({pageParam})=>api.rentals({cursor:pageParam,activeOnly}),initialPageParam:undefined as RentalCursor|undefined,
 getNextPageParam:page=>page.nextCursor,enabled:!!session&&pathname==='/rentals',refetchInterval:5000});
 const rows=rentals.data?.pages.flatMap(page=>page.rows)??[];
 if(!session)return <Button label="로그인하고 내 거래 보기" onPress={()=>router.push('/account')}/>;
 return <FlatList contentContainerStyle={s.content} data={rows} keyExtractor={r=>r.id} refreshing={refreshing} onRefresh={()=>{setRefreshing(true);void rentals.refetch().finally(()=>setRefreshing(false));}}
 ListHeaderComponent={<><Text style={s.title}>내 거래</Text><View style={{flexDirection:'row',gap:12}}><Button label="진행 중" secondary={!activeOnly} onPress={()=>setActiveOnly(true)}/><Button label="전체 이력" secondary={activeOnly} onPress={()=>setActiveOnly(false)}/></View><ErrorText error={rentals.error}/></>}
 ListFooterComponent={rentals.hasNextPage?<Button label={rentals.isFetchingNextPage?'불러오는 중':'거래 더 보기'} disabled={rentals.isFetching} onPress={()=>{void rentals.fetchNextPage();}}/>:null}
 ListEmptyComponent={rentals.isPending?<ActivityIndicator color={colors.primary}/>:<Text style={s.muted}>아직 거래가 없습니다.</Text>}
 renderItem={({item:r})=><Pressable accessibilityRole="button" onPress={()=>router.push(`/rentals/${r.id}`)} style={s.card}>
 <Text style={s.heading}>{rentalTitle(r)}</Text><Text style={s.body}>{rentalStatusLabels[r.status??'']??'상태 확인 필요'}</Text><Text style={s.muted}>{r.borrower_id===session.user.id?'빌리는 거래':'빌려주는 거래'}</Text>
 <Text style={s.body}>{r.starts_at?formatKoreaTime(r.starts_at):r.rental_date}</Text><Text style={s.price}>{formatWon(r.total_paid)}</Text>
 </Pressable>}/>;
}
