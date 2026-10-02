import {ScrollView,Text,View} from 'react-native';
import {useState} from 'react';
import {router,usePathname} from 'expo-router';
import {useInfiniteQuery,useMutation,useQueryClient} from '@tanstack/react-query';
import {api} from '../src/client';
import {useSession} from '../src/session';
import {Button,Field,ErrorText,s} from '../src/ui';

const labels:Record<string,string>={pending:'접수 · 확인 중',resolved:'답변 완료',dismissed:'검토 종료'};
export default function Support(){
 const {session}=useSession();return <SupportContents key={session?.user.id??'signed-out'}/>;
}
function SupportContents(){
 const {session,ready}=useSession();const active=usePathname()==='/support';
 const queries=useQueryClient();const [description,setDescription]=useState('');
 const send=useMutation({mutationFn:()=>api.report({reason:'other',description:description.trim()}),onSuccess:()=>{setDescription('');void queries.invalidateQueries({queryKey:['reports']});}});
 const reports=useInfiniteQuery({queryKey:['reports',session?.user.id],queryFn:({pageParam})=>api.reports(pageParam),initialPageParam:0,getNextPageParam:(rows,_pages,offset)=>rows.length===50?offset+50:undefined,enabled:!!session&&active,refetchInterval:active?30000:false});
 return <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled"><Text style={s.title}>고객 문의</Text>{!ready?<Text style={s.body}>계정을 확인하고 있습니다.</Text>:!session?<Button label="로그인하고 문의 내역 보기" onPress={()=>router.push('/account')}/>:<><Text style={s.body}>거래 문제는 거래 상세의 ‘운영 검토 요청’으로 접수해 주세요. 환불과 분쟁 결과는 해당 거래에서 확인할 수 있습니다.</Text><Button label="내 거래에서 문의하기" secondary onPress={()=>router.push('/rentals')}/>
 <Field label="일반 문의 (10자 이상)" multiline value={description} maxLength={2000} editable={!send.isPending} onChangeText={setDescription}/><Text style={s.muted}>비밀번호나 카드번호는 입력하지 마세요.</Text><Button label="문의 접수" disabled={send.isPending||description.trim().length<10} onPress={()=>send.mutate()}/>{send.isSuccess?<Text style={s.body}>문의를 접수했습니다. 아래에서 답변을 확인할 수 있습니다.</Text>:null}<ErrorText error={send.error}/>
 {reports.hasNextPage?<Button label="이전 문의 더 보기" secondary disabled={reports.isFetchingNextPage} onPress={()=>void reports.fetchNextPage()}/>:null}
 <Text style={s.heading}>내 문의·신고</Text>{reports.isPending?<Text style={s.body}>문의 내역을 불러오고 있습니다.</Text>:null}{reports.data?.pages[0].length===0?<Text style={s.body}>접수한 문의·신고가 없습니다.</Text>:null}{reports.data?.pages.flat().map(report=><View key={report.id} style={s.card}><Text style={s.heading}>{labels[report.status??'']??'확인 중'}</Text><Text style={s.body}>{report.description||'접수한 신고'}</Text><Text style={s.muted}>접수일 {report.created_at?new Date(report.created_at).toLocaleString('ko-KR'):''}</Text>{report.resolution_note?<View style={{gap:8}}><Text style={s.heading}>운영팀 답변</Text><Text style={s.body}>{report.resolution_note}</Text>{report.resolved_at?<Text style={s.muted}>{new Date(report.resolved_at).toLocaleString('ko-KR')}</Text>:null}</View>:null}{report.reservation_id?<Button label="관련 거래 보기" secondary onPress={()=>router.push(`/rentals/${report.reservation_id}`)}/>:null}</View>)}<ErrorText error={reports.error} onRetry={()=>void reports.refetch()} retrying={reports.isFetching}/></>}</ScrollView>;
}
