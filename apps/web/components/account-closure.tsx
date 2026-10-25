'use client';
import {useMutation,useQueryClient} from '@tanstack/react-query';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from './ui/button';

/** Account cleanup remains available before a trading profile exists. */
export function AccountClosure(){
 const {api,client,session}=useApi();const queries=useQueryClient();
 const close=useMutation({mutationFn:(owner:string)=>api.closeAccount(owner),onSuccess:async(result,owner)=>{
  const {data,error}=await client.auth.getSession();
  if(error)throw error;
  if(data.session?.user.id!==owner)return;
  const signedOut=await client.auth.signOut({scope:'local'});
  if(signedOut.error)throw signedOut.error;
  queries.clear();window.location.assign(`/account?closure=${result.status}`);
 }});
 return <details className="rounded-2xl border p-5"><summary className="cursor-pointer text-sm text-muted-foreground">회원 탈퇴</summary><p className="my-4 text-sm leading-6 text-muted-foreground">프로필을 만들지 않았어도 탈퇴할 수 있습니다. 진행 중 거래와 미지급 대여료는 먼저 처리해야 합니다. 탈퇴 후 계정은 복구할 수 없으며 필요한 거래·문의 기록은 보존됩니다.</p><Button variant="destructive" disabled={!session||close.isPending} onClick={()=>{if(session&&!close.isPending&&window.confirm('회원 탈퇴를 진행할까요? 탈퇴 후 계정은 복구할 수 없습니다.'))close.mutate(session.user.id);}}>{close.isPending?'처리 중…':'회원 탈퇴'}</Button><Failure error={close.error}/></details>;
}
