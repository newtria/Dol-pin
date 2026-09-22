'use client';
import {createContext, useContext, useEffect, useState, type ReactNode} from 'react';
import {createClient, type Session} from '@supabase/supabase-js';
import {QueryClient, QueryClientProvider} from '@tanstack/react-query';
import {createApi, type Client} from '@dolpin/api-client';
import type {Database} from '@dolpin/contracts';
import {useRentalDrafts} from './rental-drafts';

const Context = createContext<{client: Client; api: ReturnType<typeof createApi>; session: Session | null; ready: boolean} | null>(null);
export function Providers({children}: {children: ReactNode}) {
  const [query] = useState(() => new QueryClient({defaultOptions: {queries: {staleTime: 15000, retry: 1}, mutations: {retry: false}}}));
  const [client] = useState(() => createClient<Database>(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!, {auth: {flowType: 'pkce', detectSessionInUrl: false}}));
  const [api] = useState(() => createApi(client));
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  useEffect(() => {
    let previous: string | undefined;
    const {data} = client.auth.onAuthStateChange((_event, next) => {
      if (previous !== next?.user.id) {query.clear(); useRentalDrafts.getState().ensureOwner(next?.user.id??null);}
      previous = next?.user.id; setSession(next); setReady(true);
    });
    return () => data.subscription.unsubscribe();
  }, [client, query]);
  return <QueryClientProvider client={query}><Context.Provider value={{client, api, session, ready}}>{children}</Context.Provider></QueryClientProvider>;
}
export function useApi() { const value = useContext(Context); if (!value) throw new Error('Missing app provider'); return value; }
