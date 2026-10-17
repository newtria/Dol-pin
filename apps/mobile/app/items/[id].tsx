import {useState} from 'react';
import {router,useLocalSearchParams} from 'expo-router';
import {useQuery} from '@tanstack/react-query';
import {ScrollView,Image,Text,View,Pressable} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {categoryLabels,formatWon,rentalEstimate} from '@dolpin/contracts';
import {useSession} from '../../src/session';
import {useExploreState} from '../../src/state';
import {api} from '../../src/client';
import {Button,ErrorText,LoadingState,EmptyState,Section,s,colors} from '../../src/ui';
import {ItemReport} from '../../src/item-report';
export default function ItemDetail() {
  const {session} = useSession();
  const {id} = useLocalSearchParams<{id: string}>();
  const [selected,setSelected]=useState(0);
  const item = useQuery({queryKey: ['item', id], queryFn: () => api.item(id)});
  const ownNote = useQuery({queryKey: ['item-private', id, session?.user.id], queryFn: () => api.ownItemPickupNote(id), enabled: !!session && item.data?.lender_id === session.user.id});
  const own=!!session&&item.data?.lender_id===session.user.id;
  const filter=useExploreState();
  const estimate=item.data?rentalEstimate(filter.startsAt,filter.endsAt,item.data.daily_price,item.data.deposit):null;
  const unavailable=!!item.data&&item.data.status!=='active';
  return <View style={s.page}><ScrollView contentContainerStyle={s.content}>
    {item.isPending ? <LoadingState label="물품 정보를 불러오고 있어요"/> : null}
    <ErrorText error={item.error} retrying={item.isFetching} onRetry={()=>{void item.refetch();}}/>
    {item.isSuccess&&!item.data?<EmptyState title="지금 볼 수 없는 물품이에요" body="물품이 숨겨졌거나 더 이상 제공되지 않을 수 있어요. 다른 물품을 찾아보세요." action="물품 둘러보기" onAction={()=>router.replace('/')}/>:null}
    {item.data ? <>
      <View style={{gap:8}}><Text style={s.muted}>{categoryLabels[item.data.category as keyof typeof categoryLabels]??'콘서트 물품'} · 직접 만나서 전달</Text><Text style={s.title}>{item.data.title}</Text><Text style={s.price}>{formatWon(estimate?.fee??item.data.daily_price)}<Text style={s.muted}> / {estimate?`${estimate.days}일`:'24시간'}</Text></Text><Text style={s.muted}>보증금 {formatWon(item.data.deposit)} · 반납 확인 후 반환</Text>{estimate?<Text style={s.label}>선택한 기간 결제 예상액 {formatWon(estimate.total)}</Text>:null}</View>
      {item.data.photos.length?<View style={{gap:10}}><Image source={{uri:item.data.photos[Math.min(selected,item.data.photos.length-1)]}} style={{width:'100%',aspectRatio:1.4,borderRadius:20,backgroundColor:colors.soft}} resizeMode="contain" accessibilityLabel={`${item.data.title} 사진 ${selected+1}`}/>{item.data.photos.length>1?<ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{gap:10}}>{item.data.photos.map((uri,index)=><Pressable key={uri} accessibilityRole="button" accessibilityLabel={`상품 사진 ${index+1} 보기`} accessibilityState={{selected:index===selected}} onPress={()=>setSelected(index)} style={{borderWidth:2,borderColor:index===selected?colors.primary:'transparent',borderRadius:12,padding:2}}><Image source={{uri}} style={{width:56,height:56,borderRadius:8}}/></Pressable>)}</ScrollView>:null}</View>:null}

      {unavailable&&!own?<EmptyState title="지금은 예약을 받지 않아요" body="공개 상태가 변경된 물품입니다. 다른 물품을 찾아보세요." action="다른 물품 찾기" onAction={()=>router.push('/')}/>:null}
      <Section title="어디서 만나나요?"><Text style={s.body}>{item.data.pickup_area||'만남 지역이 등록되지 않았어요.'}</Text><Text style={s.muted}>상세 인수·반납 장소는 예약 수락 후 거래 상세에서 확인할 수 있어요.</Text>{own?<>{ownNote.data?<Text style={s.body}>상대에게 안내할 장소: {ownNote.data}</Text>:null}<ErrorText error={ownNote.error}/></>:null}</Section>
      <Section title="물품 소개"><Text style={s.body}>{item.data.description||'등록된 설명이 없습니다.'}</Text>{item.data.available_from||item.data.available_to?<Text style={s.muted}>대여 가능일: {item.data.available_from||'시작일 제한 없음'} ~ {item.data.available_to||'종료일 제한 없음'}</Text>:null}</Section>
      <Section title="이렇게 빌려요"><Text style={s.body}>1. 날짜를 고르고 예상 금액 확인{ '\n'}2. 예약 수락 후 결제{ '\n'}3. 만나서 물품 인수{ '\n'}4. 반납 확인 후 보증금 반환</Text><Text style={s.muted}>로그인 전에도 날짜와 예상 금액을 확인할 수 있어요. 예약 요청만으로 물품이 확보되지는 않습니다.</Text></Section>
      {!own?<ItemReport key={`${id}:${session?.user.id}`} id={id}/>:null}
    </> : null}
  </ScrollView>{item.data&&(own||!unavailable)?<SafeAreaView edges={['bottom']} style={{paddingHorizontal:20,paddingTop:12,paddingBottom:12,borderTopWidth:1,borderColor:colors.border,backgroundColor:colors.surface}}><Button label={own?'내 물품 수정':estimate?`${formatWon(estimate.total)} 예상 · 날짜 확인`:'날짜 선택 · 예상 금액 확인'} onPress={()=>router.push(own?`/items/new?edit=${id}`:`/rentals/new?itemId=${id}`)}/></SafeAreaView>:null}</View>;
}
