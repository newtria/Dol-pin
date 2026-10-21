import {useEffect,useState} from 'react';
import {FlatList, Image, Pressable, ScrollView, Text, View} from 'react-native';
import {router} from 'expo-router';
import {useInfiniteQuery} from '@tanstack/react-query';
import type {RentalCursor,ConcertCursor} from '@dolpin/api-client';
import {categories, categoryLabels, formatWon, koreaTime, rentalPeriodInput, rentalPeriodConflict, rentalEstimate} from '@dolpin/contracts';
import {api} from '../src/client';
import {useExploreState} from '../src/state';
import {DateField} from '../src/date-field';
import {Page, Field, ErrorText, Button, Chip, EmptyState, LoadingState, ValidationText, s, colors} from '../src/ui';

export default function Explore() {
  const resetVersion = useExploreState(state => state.resetVersion);
  return <ExploreCatalogue key={resetVersion}/>;
}

function ExploreCatalogue() {
  const filter = useExploreState();
  const [filtersOpen,setFiltersOpen]=useState(false);
  const [search,setSearch]=useState(filter.search);
  const [pickupArea,setPickupArea]=useState(filter.pickupArea);
  const [period,setPeriod]=useState({startsAt:filter.startsAt,endsAt:filter.endsAt});
  const [periodError,setPeriodError]=useState<string>();
  useEffect(()=>{const timer=setTimeout(()=>filter.set({search},filter.resetVersion),300);return()=>clearTimeout(timer);},[search,filter.set,filter.resetVersion]);
  const concerts=useInfiniteQuery({queryKey:['concerts'],queryFn:({pageParam})=>api.concerts(pageParam),initialPageParam:undefined as ConcertCursor|undefined,getNextPageParam:page=>page.nextCursor});
  const stalePeriod=filter.startsAt||filter.endsAt?rentalPeriodConflict(filter.startsAt,filter.endsAt,[]):null;
  const items=useInfiniteQuery({queryKey:['items',filter.concertId,filter.category,filter.search,filter.pickupArea,filter.startsAt,filter.endsAt],queryFn:({pageParam})=>api.items({concertId:filter.concertId,category:filter.category,search:filter.search,pickupArea:filter.pickupArea,startsAt:filter.startsAt?koreaTime(filter.startsAt):undefined,endsAt:filter.endsAt?koreaTime(filter.endsAt):undefined},pageParam),initialPageParam:undefined as RentalCursor|undefined,getNextPageParam:page=>page.nextCursor,enabled:!stalePeriod});
  const rows=stalePeriod?[]:items.data?.pages.flatMap(page=>page.rows)??[];
  const hasFilters=!!(filter.concertId||filter.category||filter.search||filter.pickupArea||filter.startsAt||filter.endsAt);
  function reset(){filter.clear();}
  function apply(){if(period.startsAt||period.endsAt){const parsed=rentalPeriodInput.safeParse(period);if(!parsed.success){setPeriodError(parsed.error.issues[0]?.message??'빌릴 날짜와 반납 날짜를 확인해 주세요.');return;}const conflict=rentalPeriodConflict(period.startsAt,period.endsAt,[]);if(conflict){setPeriodError(conflict);return;}}filter.set({...period,pickupArea:pickupArea.trim()});setPeriodError(undefined);setFiltersOpen(false);}
  return <Page><FlatList data={rows} keyExtractor={item => item.id} contentContainerStyle={s.content}
    onRefresh={() => {if(!stalePeriod)void items.refetch();}} refreshing={items.isRefetching}
    ListHeaderComponent={<View style={{gap: 20, marginBottom: 16}}>
      <View style={[s.row, {justifyContent: 'space-between'}]}><Text style={[s.title, {fontSize: 27,color:colors.primary}]}>dol-pin</Text><Pressable accessibilityRole="button" onPress={() => router.push('/items/new')} style={{paddingVertical:10,paddingHorizontal:14,borderRadius:24,backgroundColor:colors.soft}}><Text style={{color:colors.primary,fontWeight:'600'}}>+ 물품 등록</Text></Pressable></View>
      <Text style={[s.heading,{fontSize:22}]}>공연 준비물, 가볍게.</Text>
      <Field label="어떤 준비물이 필요하세요?" placeholder="물품 이름으로 검색" value={search} onChangeText={setSearch} returnKeyType="search"/>
      <Button secondary label={filter.startsAt||filter.pickupArea||filter.concertId?`${filter.pickupArea||'모든 지역'} · ${filter.startsAt?`${filter.startsAt.slice(5,10)} ~ ${filter.endsAt.slice(5,10)}`:'날짜 무관'}${filter.concertId?' · 공연 선택됨':''}  · 조건 변경`:'날짜·지역·공연 선택'} onPress={()=>setFiltersOpen(!filtersOpen)}/>
      {filtersOpen?<View style={s.card}><Text style={s.heading}>언제, 어디에서 빌릴까요?</Text><Field label="만남 지역" placeholder="예: KSPO DOME, 홍대입구역" value={pickupArea} onChangeText={setPickupArea}/><View style={{gap:10}}><Text style={s.label}>공연</Text><ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{gap: 8}}>
        <Chip label="전체 공연" selected={!filter.concertId} onPress={() => filter.set({concertId: undefined})}/>
        {concerts.data?.pages.flatMap(page=>page.rows).map(c => <Chip key={c.id} label={c.title} selected={filter.concertId === c.id} onPress={() => filter.set({concertId: c.id})}/>)}</ScrollView>
      {concerts.hasNextPage?<Button label="공연 더 보기" secondary disabled={concerts.isFetching} onPress={()=>{void concerts.fetchNextPage();}}/>:null}</View><DateField label="빌릴 날짜·시간" value={period.startsAt} onChange={startsAt=>setPeriod({...period,startsAt})} minDate={new Date(Date.now()+9*3600000).toISOString().slice(0,10)} clearable/><DateField label="반납 날짜·시간" value={period.endsAt} onChange={endsAt=>setPeriod({...period,endsAt})} minDate={period.startsAt||new Date(Date.now()+9*3600000).toISOString().slice(0,10)} clearable/><Text style={s.muted}>선택한 기간 전체에 대여 가능한 물품을 찾습니다. 최종 가능 여부는 예약 요청 시 다시 확인합니다.</Text><ValidationText error={periodError}/><Button label="이 조건으로 찾기" onPress={apply}/><Button label="지역·날짜 해제" secondary onPress={()=>{setPickupArea('');setPeriod({startsAt:'',endsAt:''});filter.set({pickupArea:'',startsAt:'',endsAt:''});setPeriodError(undefined);setFiltersOpen(false);}}/></View>:null}
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{gap: 8}}>
        <Chip label="전체 물품" selected={!filter.category} onPress={() => filter.set({category: undefined})}/>
        {categories.map(c => <Chip key={c} label={categoryLabels[c]} selected={filter.category === c} onPress={() => filter.set({category: c})}/>)}</ScrollView>
      {stalePeriod?<View style={s.card}><ValidationText error={stalePeriod}/><Button label="날짜 다시 선택" secondary onPress={()=>setFiltersOpen(true)}/></View>:null}
      <ErrorText error={items.error ?? concerts.error} retrying={items.isFetching || concerts.isFetching} onRetry={()=>{if(!stalePeriod)void items.refetch();void concerts.refetch();}}/>
      <View style={[s.row,{justifyContent:'space-between'}]}><Text style={s.heading}>{hasFilters?'조건에 맞는 물품':'빌릴 수 있는 물품'}</Text>{hasFilters?<Pressable accessibilityRole="button" onPress={reset} style={{paddingVertical:10}}><Text style={{color:colors.primary}}>조건 초기화</Text></Pressable>:null}</View>
    </View>}
    ListFooterComponent={!stalePeriod&&items.hasNextPage?<Button label={items.isFetchingNextPage?'불러오는 중':'물품 더 보기'} secondary disabled={items.isFetching} onPress={()=>{void items.fetchNextPage();}}/>:null}
    ItemSeparatorComponent={() => <View style={{height: 12}}/>}
    ListEmptyComponent={stalePeriod ? null : items.isPending ? <LoadingState label="빌릴 수 있는 물품을 찾고 있어요"/> : items.isError ? null : <EmptyState title={hasFilters?'이 조건의 물품이 없어요':'첫 물품을 기다리고 있어요'} body={hasFilters?'지역을 넓히거나 날짜·공연 조건을 바꾸면 다른 물품을 찾을 수 있어요.':'공연에 가져갈 물품을 등록하고 필요한 사람에게 빌려주세요.'} action={hasFilters?'조건 초기화':'내 물품 등록'} onAction={hasFilters?reset:()=>router.push('/items/new')}/>}
    renderItem={({item}) => {const estimate=filter.startsAt&&filter.endsAt?rentalEstimate(filter.startsAt,filter.endsAt,item.daily_price,item.deposit):null;return <Pressable accessibilityRole="button" accessibilityLabel={`${item.title}, ${estimate?`${estimate.days}일 대여료 ${formatWon(estimate.fee)}, 보증금 포함 ${formatWon(estimate.total)}`:`하루 ${formatWon(item.daily_price)}`}, ${item.pickup_area||'만남 지역 미등록'}`} onPress={() => router.push(`/items/${item.id}`)} style={[s.card, s.row,{padding:12}]}>
      {item.photos[0] ? <Image source={{uri: item.photos[0]}} style={{width: 104, height: 126, borderRadius: 14}} accessibilityLabel={item.title}/> : <View style={{width:104,height:126,borderRadius:14,backgroundColor:colors.soft,alignItems:'center',justifyContent:'center'}}><Text style={s.muted}>사진 없음</Text></View>}
      <View style={{flex: 1, gap: 5}}><Text style={s.muted}>{categoryLabels[item.category as keyof typeof categoryLabels]??'콘서트 물품'}</Text><Text style={[s.heading,{fontSize:17}]} numberOfLines={2}>{item.title}</Text><Text style={[s.price,{fontSize:19}]}>{formatWon(estimate?.fee??item.daily_price)}<Text style={s.muted}> / {estimate?`${estimate.days}일`:'일'}</Text></Text><Text style={s.muted}>보증금 {formatWon(item.deposit)}</Text>{estimate?<Text style={s.label}>결제 예상 {formatWon(estimate.total)}</Text>:null}<Text style={s.muted} numberOfLines={1}>{item.pickup_area||'만남 지역 미등록'}</Text></View>
    </Pressable>;}}/></Page>;
}
