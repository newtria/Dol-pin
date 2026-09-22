import {Platform} from 'react-native';
import * as WebBrowser from 'expo-web-browser';
import {client} from './client';
WebBrowser.maybeCompleteAuthSession();
const exchanges = new Map<string, Promise<void>>();
export function completeOAuth(url: string) {
  const params = new URL(url).searchParams;
  if (params.has('error_description') || params.has('error')) return Promise.reject({code: 'AUTH_CALLBACK_INVALID'});
  const code = params.get('code');
  if (!code) return Promise.reject({code: 'AUTH_CALLBACK_INVALID'});
  if (!exchanges.has(code)) exchanges.set(code, (async () => {
    const {error} = await client.auth.exchangeCodeForSession(code);
    if (error) throw error;
  })());
  return exchanges.get(code)!;
}
export async function signInWithSocial(provider: 'google' | 'apple' | 'kakao' | 'custom:naver') {
  const redirectTo = Platform.OS === 'web' ? `${window.location.origin}/auth/callback` : 'dolpin://auth/callback';
  const {data, error} = await client.auth.signInWithOAuth({provider, options: {redirectTo, skipBrowserRedirect: true}});
  if (error) throw error;
  if (Platform.OS === 'web') {window.location.assign(data.url); return;}
  const result = await WebBrowser.openAuthSessionAsync(data.url, redirectTo);
  if (result.type === 'success') await completeOAuth(result.url);
}
