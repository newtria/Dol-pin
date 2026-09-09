import * as WebBrowser from 'expo-web-browser';
import {useFocusEffect} from 'expo-router';
import {useCallback} from 'react';
import {ScrollView,Text} from 'react-native';
import {useLocalSearchParams} from 'expo-router';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {formatKoreaTime,formatWon,rentalStatusLabels,rentalTitle} from '@dolpin/contracts';
import {api} from '../../src/client';
import {useSession} from '../../src/session';
import {Button,ErrorText,s} from '../../src/ui';
export default function Rental(){
 const {id}=useLocalSearchParams<{id:string}>(); const {session}=useSession(); const queries=useQueryClient();
 const rental=useQuery({queryKey:['rental',id],queryFn:()=>api.rental(id),enabled:!!session});
 const action=useMutation({mutationFn:(kind:'accept'|'reject'|'cancel')=>api.respondToRental(id,kind),onSuccess:()=>{void queries.invalidateQueries({queryKey:['rental',id]});void queries.invalidateQueries({queryKey:['rentals']});}});
 const payment=useMutation({mutationFn:async()=>{const {checkoutUrl}=await api.preparePayment(id,true);await WebBrowser.openBrowserAsync(checkoutUrl);await queries.invalidateQueries({queryKey:['rental',id]});}});
 useFocusEffect(useCallback(()=>{void queries.invalidateQueries({queryKey:['rental',id]});},[id,queries]));
 const r=rental.data;
 return <ScrollView contentContainerStyle={s.content}><Text style={s.title}>거래 상세</Text><ErrorText error={rental.error??action.error??payment.error}/>
 {r?<><Text style={s.heading}>{rentalTitle(r)}</Text><Text style={s.body}>{rentalStatusLabels[r.status??'']??'상태 확인 필요'}</Text>
 <Text style={s.body}>{r.starts_at?formatKoreaTime(r.starts_at):r.rental_date} → {r.ends_at?formatKoreaTime(r.ends_at):r.return_date}</Text>
 <Text style={s.body}>대여료 {formatWon(r.rental_fee)}</Text><Text style={s.body}>보증금 {formatWon(r.deposit)}</Text><Text style={s.price}>합계 {formatWon(r.total_paid)}</Text>
 {r.status==='requested'&&r.lender_id===session?.user.id?<><Button label="예약 수락" onPress={()=>action.mutate('accept')} disabled={action.isPending}/><Button label="예약 거절" secondary onPress={()=>action.mutate('reject')} disabled={action.isPending}/></>:null}
 {r.status==='requested'&&r.borrower_id===session?.user.id?<Button label="요청 취소" secondary onPress={()=>action.mutate('cancel')} disabled={action.isPending}/>:null}
 {r.status==='accepted'&&r.borrower_id===session?.user.id?<Button label="결제하기" onPress={()=>payment.mutate()} disabled={payment.isPending}/>:null}
 {r.status==='accepted'&&r.payment_due_at?<Text style={s.muted}>결제 기한 {formatKoreaTime(r.payment_due_at)}</Text>:null}
 </>:null}</ScrollView>;
}
