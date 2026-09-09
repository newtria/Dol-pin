import {router,useLocalSearchParams} from 'expo-router';
import {useQuery} from '@tanstack/react-query';
import {ScrollView, Image, Text, ActivityIndicator} from 'react-native';
import {formatWon} from '@dolpin/contracts';
import {api} from '../../src/client';
import {Button,ErrorText, s, colors} from '../../src/ui';
export default function ItemDetail() {
  const {id} = useLocalSearchParams<{id: string}>();
  const item = useQuery({queryKey: ['item', id], queryFn: () => api.item(id)});
  return <ScrollView contentContainerStyle={s.content}>
    {item.isPending ? <ActivityIndicator color={colors.primary}/> : null}
    <ErrorText error={item.error}/>
    {item.data ? <>
      {item.data.photos[0] ? <Image source={{uri: item.data.photos[0]}} style={{width: '100%', aspectRatio: 1.2, borderRadius: 12}} accessibilityLabel={item.data.title}/> : null}
      <Text style={s.title}>{item.data.title}</Text><Text style={s.price}>{formatWon(item.data.daily_price)} / 일</Text>
      <Button label="대여 기간 선택" onPress={()=>router.push(`/rentals/new?itemId=${id}`)}/>
      <Text style={s.muted}>보증금 {formatWon(item.data.deposit)}</Text><Text style={s.body}>{item.data.description}</Text>
    </> : null}
  </ScrollView>;
}
