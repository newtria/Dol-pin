import {router,useLocalSearchParams} from 'expo-router';
import {useQuery} from '@tanstack/react-query';
import {ScrollView, Image, Text, ActivityIndicator} from 'react-native';
import {formatWon} from '@dolpin/contracts';
import {useSession} from '../../src/session';
import {api} from '../../src/client';
import {Button,ErrorText, s, colors} from '../../src/ui';
export default function ItemDetail() {
  const {session} = useSession();
  const {id} = useLocalSearchParams<{id: string}>();
  const item = useQuery({queryKey: ['item', id], queryFn: () => api.item(id)});
  const ownNote = useQuery({queryKey: ['item-private', id, session?.user.id], queryFn: () => api.ownItemPickupNote(id), enabled: !!session && item.data?.lender_id === session.user.id});
  return <ScrollView contentContainerStyle={s.content}>
    {item.isPending ? <ActivityIndicator color={colors.primary}/> : null}
    <ErrorText error={item.error} retrying={item.isFetching} onRetry={()=>{void item.refetch();}}/>
    {item.data ? <>
      {item.data.photos[0] ? <Image source={{uri: item.data.photos[0]}} style={{width: '100%', aspectRatio: 1.2, borderRadius: 12}} accessibilityLabel={item.data.title}/> : null}
      <Text style={s.title}>{item.data.title}</Text><Text style={s.price}>{formatWon(item.data.daily_price)} / 일</Text>
      {item.data.lender_id===session?.user.id?<Text style={s.muted}>내가 등록한 물품입니다.</Text>:<Button label="대여 기간 선택" onPress={()=>router.push(`/rentals/new?itemId=${id}`)}/>}
      <Text style={s.muted}>보증금 {formatWon(item.data.deposit)}</Text><Text style={s.body}>{item.data.description}</Text><Text style={s.body}>만남 지역: {item.data.pickup_area??'등록된 공개 지역이 없습니다.'}</Text>
      <Text style={s.muted}>상세 인수·반납 장소는 예약 수락 후 거래 상세에서 확인할 수 있습니다.</Text>
      {item.data.lender_id===session?.user.id?<>{ownNote.data?<Text style={s.body}>상대에게 안내할 상세 장소: {ownNote.data}</Text>:null}<ErrorText error={ownNote.error}/></>:null}
    </> : null}
  </ScrollView>;
}
