'use client';
import {useEffect, useState} from 'react';
import {useRouter} from 'next/navigation';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import Link from 'next/link';
import {accountHref,safeReturnTo} from '@/components/auth-return';
const exchanges = new Map<string, Promise<void>>();
export default function Callback() {
  const {client} = useApi(); const router = useRouter(); const [error,setError] = useState<unknown>();
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const code = params.get('code');
    if (params.has('error_description') || params.has('error') || !code) {setError({code: 'AUTH_CALLBACK_INVALID'}); return;}
    if (!exchanges.has(code)) exchanges.set(code, (async () => {
      const {error} = await client.auth.exchangeCodeForSession(code); if (error) throw error;
    })());
    void exchanges.get(code)!.then(() => router.replace(params.get('recovery')==='1'?`/auth/password?returnTo=${encodeURIComponent(safeReturnTo(params.get('returnTo')))}`:accountHref(safeReturnTo(params.get('returnTo'))))).catch(setError);
  }, [client,router]);
  return <section className="mx-auto max-w-md rounded-2xl border bg-card p-8"><h1 className="mb-4 text-2xl font-bold">로그인 확인</h1><Failure error={error}/>{error ? <Link className="font-semibold text-primary underline underline-offset-4" href={typeof window!=='undefined'?accountHref(safeReturnTo(new URLSearchParams(window.location.search).get('returnTo'))):'/account'}>다시 로그인</Link> : <p>로그인을 확인하고 있습니다.</p>}</section>;
}
