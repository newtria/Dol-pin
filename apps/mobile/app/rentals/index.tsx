import {FlatList,Text,Pressable,ActivityIndicator} from 'react-native';
import {router} from 'expo-router';
import {useQuery} from '@tanstack/react-query';
import {formatKoreaTime,formatWon,rentalStatusLabels,rentalTitle} from '@dolpin/contracts';
import {api} from '../../src/client';
import {useSession} from '../../src/session';
import {Button,ErrorText,s,colors} from '../../src/ui';
export default function Rentals(){
 const {session}=useSession(); const rentals=useQuery({queryKey:['rentals'],queryFn:api.rentals,enabled:!!session});
 if(!session)return <Button label="로그인하고 내 거래 보기" onPress={()=>router.push('/account')}/>;
 return <FlatList contentContainerStyle={s.content} data={rentals.data??[]} keyExtractor={r=>r.id} refreshing={rentals.isRefetching} onRefresh={()=>{void rentals.refetch();}}
 ListHeaderComponent={<><Text style={s.title}>내 거래</Text><ErrorText error={rentals.error}/></>}
 ListEmptyComponent={rentals.isPending?<ActivityIndicator color={colors.primary}/>:<Text style={s.muted}>아직 거래가 없습니다.</Text>}
 renderItem={({item:r})=><Pressable accessibilityRole="button" onPress={()=>router.push(`/rentals/${r.id}`)} style={s.card}>
 <Text style={s.heading}>{rentalTitle(r)}</Text><Text style={s.body}>{rentalStatusLabels[r.status??'']??'상태 확인 필요'}</Text><Text style={s.muted}>{r.borrower_id===session.user.id?'빌리는 거래':'빌려주는 거래'}</Text>
 <Text style={s.body}>{r.starts_at?formatKoreaTime(r.starts_at):r.rental_date}</Text><Text style={s.price}>{formatWon(r.total_paid)}</Text>
 </Pressable>}/>;
}
