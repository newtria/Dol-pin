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
 return <section className="flex flex-col items-start gap-3"><Button variant="ghost" aria-expanded={open} onClick={()=>setOpen(!open)}>물품에 문제가 있나요? 신고하기</Button>{open&&!session?<p className="text-sm text-muted-foreground">신고 처리 결과를 안내하려면 로그인이 필요해요. <Link className="font-semibold text-primary underline underline-offset-4" href={`/account?returnTo=${encodeURIComponent(`/items/${id}`)}`}>로그인하고 신고하기</Link></p>:null}{open&&session?<form className="surface flex w-full flex-col gap-3" onSubmit={e=>{e.preventDefault();if(!report.isPending&&reason.trim().length>=10)report.mutate();}}><label>신고 사유 (10자 이상)<textarea className="mt-2 min-h-28 w-full rounded-lg border p-3" value={reason} maxLength={2000} disabled={report.isPending} onChange={e=>setReason(e.target.value)} placeholder="문제가 되는 내용과 확인한 사실을 적어 주세요."/></label><Button disabled={report.isPending||reason.trim().length<10}>{report.isPending?'신고를 접수하는 중…':'신고 접수'}</Button>{report.isSuccess?<p role="status">신고를 접수했어요. <Link href="/support" className="underline underline-offset-4">고객 문의에서 처리 결과 확인</Link></p>:null}<Failure error={report.error}/></form>:null}</section>;
}
