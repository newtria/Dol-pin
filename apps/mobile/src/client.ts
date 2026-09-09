import {Platform} from 'react-native';
import * as SecureStore from 'expo-secure-store';
import {createClient} from '@supabase/supabase-js';
import {createApi} from '@dolpin/api-client';
import type {Database} from '@dolpin/contracts';

const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const key = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
if (!url || !key) throw new Error('Local client configuration is missing. Run scripts/setup-local-env.mjs.');

const storage = {
  getItem: (name: string) => Platform.OS === 'web' ? Promise.resolve(localStorage.getItem(name)) : SecureStore.getItemAsync(name),
  setItem: (name: string, value: string) => Platform.OS === 'web' ? Promise.resolve(localStorage.setItem(name, value)) : SecureStore.setItemAsync(name, value),
  removeItem: (name: string) => Platform.OS === 'web' ? Promise.resolve(localStorage.removeItem(name)) : SecureStore.deleteItemAsync(name),
};
export const client = createClient<Database>(url, key, {
  auth: {storage, persistSession: true, autoRefreshToken: true, detectSessionInUrl: false, flowType: 'pkce'},
});
export const api = createApi(client);
