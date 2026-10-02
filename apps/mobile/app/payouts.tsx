import {useState} from 'react';
import {Alert,ScrollView,Text,View} from 'react-native';
import {router} from 'expo-router';
import {useInfiniteQuery,useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {formatWon} from '@dolpin/contracts';
import type {PayoutCursor} from '@dolpin/api-client';
import {api} from '../src/client';
import {useSession} from '../src/session';
import {Button,Field,ErrorText,s} from '../src/ui';
const labels={pending:'지급 대기',processing:'송금 확인 중',paid:'지급 완료',failed:'운영 확인 중'};
export default function Payouts(){
 const {session}=useSession();return <PayoutContents key={session?.user.id??'signed-out'}/>;
}
function PayoutContents(){
 const {session}=useSession();const queries=useQueryClient();const [bankName,setBank]=useState(''),[accountNumber,setNumber]=useState(''),[holderName,setHolder]=useState('');
 const account=useQuery({queryKey:['payout-account',session?.user.id],queryFn:api.payoutAccount,enabled:!!session,gcTime:0});
 const list=useInfiniteQuery({queryKey:['payouts',session?.user.id],queryFn:({pageParam})=>api.payouts(pageParam),initialPageParam:undefined as PayoutCursor|undefined,getNextPageParam:rows=>{const last=rows.at(-1);return rows.length===100&&last?{createdAt:last.created_at,id:last.id}:undefined;},enabled:!!session});
 const save=useMutation({mutationFn:()=>api.savePayoutAccount({bankName,accountNumber,holderName}),onSuccess:()=>{setBank('');setNumber('');setHolder('');void queries.invalidateQueries({queryKey:['payout-account']});Alert.alert('저장했습니다','지급 계좌를 저장했습니다.');}});
 return <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled"><Text style={s.title}>대여료 지급</Text>{!session?<Button label="로그인" onPress={()=>router.push('/account')}/>:<><Text style={s.body}>거래가 끝나면 대여료를 등록한 계좌로 지급합니다. 보증금 반환과 별도로 표시됩니다.</Text>{account.data?<Text style={s.body}>등록 계좌: {account.data.bankName} · 끝 {account.data.accountNumber.slice(-4)} · {account.data.holderName}</Text>:null}<Field label="은행" value={bankName} maxLength={60} onChangeText={setBank}/><Field label="계좌번호" value={accountNumber} maxLength={40} keyboardType="number-pad" onChangeText={setNumber}/><Field label="예금주" value={holderName} maxLength={60} onChangeText={setHolder}/><Button label="지급 계좌 저장" disabled={save.isPending||!bankName.trim()||!accountNumber.trim()||!holderName.trim()} onPress={()=>Alert.alert('본인 명의 계좌가 맞습니까?','이미 송금 확인 중인 건은 기존 계좌로 처리됩니다.',[{text:'취소',style:'cancel'},{text:'저장',onPress:()=>save.mutate()}])}/><Text style={s.heading}>지급 내역</Text>{list.data?.pages.flat().map(p=><View key={p.id} style={s.card}><Text style={s.heading}>{labels[p.status]}</Text><Text style={s.body}>대여료 {formatWon(p.amount)} · 수수료 {formatWon(p.fee_amount)}</Text><Text style={s.price}>지급액 {formatWon(p.net_amount)}</Text>{p.paid_at?<Text style={s.muted}>지급일 {new Date(p.paid_at).toLocaleDateString('ko-KR')}</Text>:null}<Button label="거래 보기" secondary onPress={()=>router.push(`/rentals/${p.reservation_id}`)}/></View>)}{list.data?.pages[0].length===0?<Text style={s.body}>지급 내역이 없습니다.</Text>:null}{list.hasNextPage?<Button label="이전 지급 내역" secondary onPress={()=>void list.fetchNextPage()}/>:null}</>}<ErrorText error={account.error??list.error??save.error}/></ScrollView>;
}
