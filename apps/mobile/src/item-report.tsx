import {useState} from 'react';
import {Text,View} from 'react-native';
import {router} from 'expo-router';
import {useMutation,useQueryClient} from '@tanstack/react-query';
import {api} from './client';
import {useSession} from './session';
import {Button,ErrorText,Field,s} from './ui';
export function ItemReport({id}:{id:string}){
 const {session}=useSession();const queries=useQueryClient();const [open,setOpen]=useState(false);const [reason,setReason]=useState('');
 const report=useMutation({mutationFn:()=>api.report({itemId:id,reason:'other',description:reason.trim()}),onSuccess:()=>{setReason('');void queries.invalidateQueries({queryKey:['reports']});}});
 return <View style={{gap:12}}><Button label="이 물품 신고" secondary onPress={()=>session?setOpen(!open):router.push('/account')}/>{open?<><Field label="신고 사유 (10자 이상)" multiline value={reason} maxLength={2000} onChangeText={setReason} editable={!report.isPending}/><Button label="신고 접수" disabled={report.isPending||reason.trim().length<10} onPress={()=>report.mutate()}/>{report.isSuccess?<Text style={s.body}>신고를 접수했습니다. 고객 문의에서 처리 결과를 확인할 수 있습니다.</Text>:null}<ErrorText error={report.error}/></>:null}</View>;
}
