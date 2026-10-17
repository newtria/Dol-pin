import {useState} from 'react';
import {Alert,ScrollView,Text,View} from 'react-native';
import {router} from 'expo-router';
import {useInfiniteQuery,useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {formatWon} from '@dolpin/contracts';
import type {PayoutCursor} from '@dolpin/api-client';
import {api} from '../src/client';
import {useSession} from '../src/session';
import {beginSignIn} from '../src/auth-return';
import {Button,Field,Section,EmptyState,LoadingState,ErrorText,s} from '../src/ui';
const labels={pending:'지급 대기',processing:'송금 확인 중',paid:'지급 완료',failed:'운영 확인 중'};
export default function Payouts(){
 const {session}=useSession();return <PayoutContents key={session?.user.id??'signed-out'}/>;
}
function PayoutContents(){
 const {session,ready}=useSession();const queries=useQueryClient();const [bankName,setBank]=useState(''),[accountNumber,setNumber]=useState(''),[holderName,setHolder]=useState(''),[editing,setEditing]=useState(false);
 const account=useQuery({queryKey:['payout-account',session?.user.id],queryFn:api.payoutAccount,enabled:!!session,gcTime:0});
 const list=useInfiniteQuery({queryKey:['payouts',session?.user.id],queryFn:({pageParam})=>api.payouts(pageParam),initialPageParam:undefined as PayoutCursor|undefined,getNextPageParam:rows=>{const last=rows.at(-1);return rows.length===100&&last?{createdAt:last.created_at,id:last.id}:undefined;},enabled:!!session});
 const save=useMutation({mutationFn:()=>api.savePayoutAccount({bankName,accountNumber,holderName}),onSuccess:()=>{setBank('');setNumber('');setHolder('');setEditing(false);void queries.invalidateQueries({queryKey:['payout-account']});Alert.alert('저장했습니다','지급 계좌를 저장했습니다.');}});
 return <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled" automaticallyAdjustKeyboardInsets><Text style={s.title}>대여료 지급</Text>{!ready?<LoadingState label="계정을 확인하고 있어요"/>:!session?<EmptyState title="빌려준 물품의 수익을 확인하세요" body="거래 완료 후 지급될 대여료와 등록한 계좌를 확인할 수 있어요." action="로그인" onAction={()=>void beginSignIn('/payouts')}/>:<><Text style={s.muted}>거래가 끝나면 대여료를 등록한 계좌로 지급합니다. 빌리는 분의 보증금 반환과는 별도입니다.</Text>
 <Section title="대여료를 받을 계좌">{account.isPending?<LoadingState label="계좌를 확인하고 있어요"/>:account.data?<><Text style={s.heading}>{account.data.bankName} · 끝 {account.data.accountNumber.slice(-4)}</Text><Text style={s.muted}>예금주 {account.data.holderName}</Text><Button label={editing?'계좌 변경 취소':'계좌 변경'} secondary onPress={()=>{setEditing(!editing);setNumber('');}}/></>:<Text style={s.body}>아직 등록된 계좌가 없습니다. 본인 명의 계좌를 등록해 주세요.</Text>}
 {(!account.isPending&&!account.data||editing)?<><Field label="은행" placeholder="은행 이름" value={bankName} maxLength={60} onChangeText={setBank} editable={!save.isPending}/><Field label="계좌번호" placeholder="숫자만 입력" value={accountNumber} maxLength={40} keyboardType="number-pad" onChangeText={value=>setNumber(value.replace(/\D/g,''))} editable={!save.isPending}/><Field label="예금주" placeholder="본인 이름" value={holderName} maxLength={60} onChangeText={setHolder} editable={!save.isPending}/><Button label={save.isPending?'저장 중…':'이 계좌로 지급받기'} disabled={save.isPending||!bankName.trim()||!accountNumber.trim()||!holderName.trim()} onPress={()=>Alert.alert('본인 명의 계좌가 맞습니까?',`${bankName} · 끝 ${accountNumber.slice(-4)} · ${holderName}\n이미 송금 확인 중인 건은 기존 계좌로 처리됩니다.`,[{text:'다시 확인',style:'cancel'},{text:'저장',onPress:()=>save.mutate()}])}/></>:null}
 <ErrorText error={account.error??save.error} onRetry={account.isError?()=>void account.refetch():undefined}/></Section>
 <Text style={s.heading}>지급 내역</Text>{list.isPending?<LoadingState label="지급 내역을 불러오고 있어요"/>:null}{list.data?.pages.flat().map(p=><View key={p.id} style={s.card}><Text style={s.heading}>{labels[p.status]}</Text><Text style={s.body}>대여료 {formatWon(p.amount)} · 수수료 {formatWon(p.fee_amount)}</Text><Text style={s.price}>지급액 {formatWon(p.net_amount)}</Text>{p.paid_at?<Text style={s.muted}>지급일 {new Date(p.paid_at).toLocaleDateString('ko-KR')}</Text>:null}<Button label="관련 거래 보기" secondary onPress={()=>router.push(`/rentals/${p.reservation_id}`)}/></View>)}{list.data?.pages[0].length===0?<EmptyState title="아직 지급 내역이 없어요" body="빌려준 물품의 거래가 완료되면 이곳에서 지급 상태를 확인할 수 있어요."/>:null}{list.hasNextPage?<Button label="이전 지급 내역" secondary disabled={list.isFetchingNextPage} onPress={()=>void list.fetchNextPage()}/>:null}</>}<ErrorText error={list.error} onRetry={list.isError?()=>void list.refetch():undefined}/></ScrollView>;
}
