import {useInfiniteQuery} from '@tanstack/react-query';
import {type ConcertCursor} from '@dolpin/api-client';
import {Text,ScrollView,View} from 'react-native';
import {api} from './client';
import {Button,ErrorText,s} from './ui';
export function ConcertSelect({value,onChange}:{value:string|null;onChange:(id:string|null)=>void}) {
 const concerts=useInfiniteQuery({queryKey:['concert-options'],queryFn:({pageParam})=>api.concerts(pageParam),initialPageParam:undefined as ConcertCursor|undefined,getNextPageParam:page=>page.nextCursor});
 return <View style={{gap:8}}><Text style={s.muted}>연결할 공연</Text><ScrollView horizontal contentContainerStyle={{gap:8}}><Button label="공연 지정 없음" secondary={value!==null} onPress={()=>onChange(null)}/>{concerts.data?.pages.flatMap(p=>p.rows).map(c=><Button key={c.id} label={`${c.title} · ${c.concert_date}`} secondary={c.id!==value} onPress={()=>onChange(c.id)}/>)}</ScrollView>{concerts.hasNextPage?<Button label="공연 더 보기" secondary disabled={concerts.isFetchingNextPage} onPress={()=>void concerts.fetchNextPage()}/>:null}<ErrorText error={concerts.error}/></View>;
}
