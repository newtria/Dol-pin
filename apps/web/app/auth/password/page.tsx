'use client';
import {useState} from 'react';
import Link from 'next/link';
import {useMutation} from '@tanstack/react-query';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
export default function Password() {
 const {session}=useApi();return <PasswordContents key={session?.user.id??'signed-out'}/>;
}
function PasswordContents(){
 const {client,session,ready}=useApi();const [email,setEmail]=useState('');const [password,setPassword]=useState('');const [confirmation,setConfirmation]=useState('');const [notice,setNotice]=useState('');const [sentAt,setSentAt]=useState(0);
 const send=useMutation({mutationFn:async()=>{if(Date.now()-sentAt<60000)return;const {error}=await client.auth.resetPasswordForEmail(email.trim(),{redirectTo:`${window.location.origin}/auth/callback?recovery=1`});if(error)throw error;setSentAt(Date.now());setNotice('가입된 이메일이라면 비밀번호 재설정 메일을 보냈습니다. 메일 링크를 이 브라우저에서 열어 주세요.');}});
 const save=useMutation({mutationFn:async()=>{if(password.length<8||password.length>72||password!==confirmation)throw new Error('비밀번호를 확인해 주세요.');const {error}=await client.auth.updateUser({password});if(error)throw error;setPassword('');setConfirmation('');setNotice('비밀번호를 변경했습니다.');}});
 if(!ready)return <p>계정을 확인하고 있습니다.</p>;
 return <section className="mx-auto flex max-w-md flex-col gap-5"><h1 className="text-2xl font-bold">비밀번호 {session?'변경':'재설정'}</h1>{session?<form className="flex flex-col gap-4" onSubmit={e=>{e.preventDefault();if(!save.isPending)save.mutate();}}><label>새 비밀번호<Input type="password" value={password} minLength={8} maxLength={72} required autoComplete="new-password" onChange={e=>setPassword(e.target.value)}/></label><label>새 비밀번호 확인<Input type="password" value={confirmation} required autoComplete="new-password" onChange={e=>setConfirmation(e.target.value)}/></label><Button disabled={save.isPending||password.length<8||password!==confirmation}>비밀번호 저장</Button></form>:<form className="flex flex-col gap-4" onSubmit={e=>{e.preventDefault();if(!send.isPending)send.mutate();}}><label>가입한 이메일<Input type="email" value={email} required autoComplete="email" onChange={e=>setEmail(e.target.value)}/></label><Button disabled={send.isPending}>재설정 메일 보내기</Button></form>}<Failure error={send.error??save.error}/>{notice?<p role="status">{notice}</p>:null}<Link href="/account">계정으로 돌아가기</Link></section>;
}
