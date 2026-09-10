import {FlatList, Image, Pressable, ScrollView, Text, View, ActivityIndicator} from 'react-native';
import {router} from 'expo-router';
import {useInfiniteQuery} from '@tanstack/react-query';
import type {RentalCursor,ConcertCursor} from '@dolpin/api-client';
import {categories, categoryLabels, formatWon} from '@dolpin/contracts';
import {api} from '../src/client';
import {useExploreState} from '../src/state';
import {Page, Field, ErrorText, Button, s, colors} from '../src/ui';

export default function Explore() {
  const filter = useExploreState();
  const concerts=useInfiniteQuery({queryKey:['concerts'],queryFn:({pageParam})=>api.concerts(pageParam),initialPageParam:undefined as ConcertCursor|undefined,getNextPageParam:page=>page.nextCursor});
  const items=useInfiniteQuery({queryKey:['items',filter.concertId,filter.category,filter.search],queryFn:({pageParam})=>api.items(filter,pageParam),initialPageParam:undefined as RentalCursor|undefined,getNextPageParam:page=>page.nextCursor});
  return <Page><FlatList data={items.data?.pages.flatMap(page=>page.rows) ?? []} keyExtractor={item => item.id} contentContainerStyle={s.content}
    onRefresh={() => {void items.refetch();}} refreshing={items.isRefetching}
    ListHeaderComponent={<View style={{gap: 20}}>
      <View style={[s.row, {justifyContent: 'space-between'}]}><Text style={[s.title, {fontSize: 32}]}>dol-pin</Text><Pressable accessibilityRole="button" onPress={() => router.push('/account')}><Text style={s.body}>계정</Text></Pressable></View>
      <View style={{gap: 8}}><Text style={s.title}>콘서트 준비물</Text><Text style={s.muted}>필요한 순간에 빌려 쓰세요</Text></View>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{gap: 8}}>
        <Chip label="전체 콘서트" selected={!filter.concertId} onPress={() => filter.set({concertId: undefined})}/>
        {concerts.data?.pages.flatMap(page=>page.rows).map(c => <Chip key={c.id} label={c.title} selected={filter.concertId === c.id} onPress={() => filter.set({concertId: c.id})}/>)}</ScrollView>
      {concerts.hasNextPage?<Button label="공연 더 보기" secondary disabled={concerts.isFetching} onPress={()=>{void concerts.fetchNextPage();}}/>:null}
      <Field label="상품 검색" placeholder="어떤 물품을 찾으세요?" value={filter.search} onChangeText={search => filter.set({search})}/>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{gap: 8}}>
        <Chip label="전체" selected={!filter.category} onPress={() => filter.set({category: undefined})}/>
        {categories.map(c => <Chip key={c} label={categoryLabels[c]} selected={filter.category === c} onPress={() => filter.set({category: c})}/>)}</ScrollView>
      <ErrorText error={items.error ?? concerts.error}/>
      <Button label="내 거래" secondary onPress={()=>router.push('/rentals')}/>
      <Button label="내 물품 등록" secondary onPress={() => router.push('/items/new')}/>
    </View>}
    ListFooterComponent={items.hasNextPage?<Button label="물품 더 보기" disabled={items.isFetching} onPress={()=>{void items.fetchNextPage();}}/>:null}
    ItemSeparatorComponent={() => <View style={{height: 12}}/>}
    ListEmptyComponent={items.isPending ? <ActivityIndicator color={colors.primary}/> : <View style={{paddingVertical: 32}}><Text style={s.muted}>조건에 맞는 물품이 아직 없습니다.</Text></View>}
    renderItem={({item}) => <Pressable accessibilityRole="button" accessibilityLabel={item.title} onPress={() => router.push(`/items/${item.id}`)} style={[s.card, s.row]}>
      {item.photos[0] ? <Image source={{uri: item.photos[0]}} style={{width: 100, height: 112, borderRadius: 10}} accessibilityLabel={item.title}/> : null}
      <View style={{flex: 1, gap: 10}}><Text style={s.heading}>{item.title}</Text><Text style={s.price}>{formatWon(item.daily_price)} / 일</Text><Text style={s.muted}>보증금 {formatWon(item.deposit)}</Text></View>
    </Pressable>}/></Page>;
}
function Chip({label, selected, onPress}: {label: string; selected: boolean; onPress: () => void}) {
  return <Pressable accessibilityRole="button" accessibilityState={{selected}} onPress={onPress} style={{padding: 12, borderRadius: 12, backgroundColor: selected ? colors.primary : colors.surface}}><Text style={s.muted}>{label}</Text></Pressable>;
}
