import {createClient} from '@supabase/supabase-js';
import {createApi} from '@dolpin/api-client';
import type {Database} from '@dolpin/contracts';
import {sessionStorage} from './session-storage';

const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const key = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
if (!url || !key) throw new Error('서비스 연결 설정을 확인하지 못했습니다. 앱을 업데이트한 뒤 다시 시도해 주세요.');

export const client = createClient<Database>(url, key, {
  auth: {storage: sessionStorage, persistSession: true, autoRefreshToken: true, detectSessionInUrl: false, flowType: 'pkce'},
});
export const api = createApi(client);
