import {createContext, useContext, useEffect, useState, type ReactNode} from 'react';
import {AppState} from 'react-native';
import type {Session} from '@supabase/supabase-js';
import {focusManager, useQueryClient} from '@tanstack/react-query';
import {client} from './client';
import {useRentalDrafts} from './rental-drafts';
import {useExploreState} from './state';

const Context = createContext<{session: Session | null; ready: boolean}>({session: null, ready: false});
export const useSession = () => useContext(Context);
export function SessionProvider({children}: {children: ReactNode}) {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const queries = useQueryClient();
  useEffect(() => {
    let active = true;
    let lastId: string | undefined;
    const {data: {subscription}} = client.auth.onAuthStateChange((_event, next) => {
      if (!active) return;
      if (lastId !== next?.user.id) {queries.clear(); useExploreState.getState().clear(); useRentalDrafts.getState().clear();}
      lastId = next?.user.id; setSession(next); setReady(true);
    });
    focusManager.setFocused(AppState.currentState === 'active');
    const appState = AppState.addEventListener('change', state => {
      focusManager.setFocused(state === 'active');
      if (state === 'active') client.auth.startAutoRefresh(); else client.auth.stopAutoRefresh();
    });
    return () => {active = false; subscription.unsubscribe(); appState.remove(); client.auth.stopAutoRefresh();};
  }, [queries]);
  return <Context.Provider value={{session, ready}}>{children}</Context.Provider>;
}
