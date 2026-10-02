'use client';
import {useState} from 'react';
import Link from 'next/link';
import {useMutation,useQueryClient} from '@tanstack/react-query';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from './ui/button';
export function ItemReport({id}:{id:string}){
 const {api,session}=useApi();const queries=useQueryClient();const [open,setOpen]=useState(false);const [reason,setReason]=useState('');
 const report=useMutation({mutationFn:()=>api.report({itemId:id,reason:'other',description:reason.trim()}),onSuccess:()=>{setReason('');void queries.invalidateQueries({queryKey:['reports']});}});
 if(!session)return <Link href="/account">로그인하고 이 물품 신고</Link>;
 return <section className="flex flex-col gap-3"><Button variant="outline" aria-expanded={open} onClick={()=>setOpen(!open)}>이 물품 신고</Button>{open?<form className="flex flex-col gap-3" onSubmit={e=>{e.preventDefault();if(!report.isPending&&reason.trim().length>=10)report.mutate();}}><label>신고 사유 (10자 이상)<textarea className="mt-2 min-h-24 w-full rounded border p-3" value={reason} maxLength={2000} disabled={report.isPending} onChange={e=>setReason(e.target.value)}/></label><Button disabled={report.isPending||reason.trim().length<10}>신고 접수</Button>{report.isSuccess?<p role="status">신고를 접수했습니다. 고객 문의에서 처리 결과를 확인할 수 있습니다.</p>:null}<Failure error={report.error}/></form>:null}</section>;
}
