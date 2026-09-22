'use client';
import {useEffect, useState} from 'react';
import {useRouter} from 'next/navigation';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import Link from 'next/link';
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
    void exchanges.get(code)!.then(() => router.replace('/account')).catch(setError);
  }, [client,router]);
  return <section><h1>로그인 확인</h1><Failure error={error}/>{error ? <Link href="/account">다시 로그인</Link> : <p>로그인을 확인하고 있습니다.</p>}</section>;
}
