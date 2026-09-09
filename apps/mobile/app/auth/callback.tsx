import {useEffect, useState} from 'react';
import {Text, View} from 'react-native';
import {useLocalSearchParams, router} from 'expo-router';
import {completeOAuth} from '../../src/oauth';
import {Button, ErrorText, s} from '../../src/ui';
export default function Callback() {
  const params = useLocalSearchParams<{code?: string; error?: string; error_description?: string}>();
  const [error, setError] = useState<unknown>();
  useEffect(() => {
    const query = new URLSearchParams();
    for (const [key,value] of Object.entries(params)) if (typeof value === 'string') query.set(key,value);
    void completeOAuth(`dolpin://auth/callback?${query}`).then(() => router.replace('/account')).catch(setError);
  }, [params.code, params.error, params.error_description]);
  return <View style={s.content}><Text style={s.body}>로그인을 확인하고 있습니다.</Text><ErrorText error={error}/>{error ? <Button label="다시 로그인" onPress={() => router.replace('/account')}/> : null}</View>;
}
