import {useState} from 'react';
import {Stack, type ErrorBoundaryProps} from 'expo-router';
import {Alert, View, Text} from 'react-native';
import {errorMessage} from '../src/error-message';
import {MutationCache, QueryClient, QueryClientProvider} from '@tanstack/react-query';
import {SessionProvider} from '../src/session';
import {PushObserver} from '../src/push';
import {colors, Button, s} from '../src/ui';
export default function Layout() {
  const [queries] = useState(() => new QueryClient({mutationCache: new MutationCache({onError: (error,_variables,_context,mutation) => {if(!mutation.options.meta?.silent)Alert.alert('처리하지 못했습니다', errorMessage(error), [{text: '확인'}]);}}), defaultOptions: {queries: {staleTime: 15000, retry: 1}, mutations: {retry: false}}}));
  return <QueryClientProvider client={queries}><SessionProvider><Stack screenOptions={{headerStyle: {backgroundColor: colors.background}, headerTintColor: colors.text, contentStyle: {backgroundColor: colors.background}}}>
    <Stack.Screen name="index" options={{headerShown: false}}/>
    <Stack.Screen name="account" options={{title: '계정', headerBackTitle: '탐색'}}/>
    <Stack.Screen name="notifications" options={{title:'메시지·알림'}}/>
    <Stack.Screen name="support" options={{title:'고객 문의'}}/>
    <Stack.Screen name="payouts" options={{title:'대여료 지급'}}/>
    <Stack.Screen name="auth/password" options={{title:'비밀번호 관리'}}/>
    <Stack.Screen name="items/mine" options={{title:'내 물품 관리'}}/>
    <Stack.Screen name="items/[id]" options={{title: '물품 상세', headerBackTitle: '탐색'}}/>
    <Stack.Screen name="items/new" options={{title: '물품 등록', headerBackTitle: '탐색'}}/>
    <Stack.Screen name="rentals/index" options={{title:'내 거래'}}/>
    <Stack.Screen name="rentals/new" options={{title:'예약 요청'}}/>
    <Stack.Screen name="rentals/[id]" options={{title:'거래 상세'}}/>
  </Stack><PushObserver/></SessionProvider></QueryClientProvider>;
}

export function ErrorBoundary({retry}: ErrorBoundaryProps) {
  return <View style={[s.page,s.content,{justifyContent:'center'}]}><Text style={s.heading}>화면을 불러오지 못했습니다.</Text><Text style={s.body}>잠시 후 다시 시도해 주세요.</Text><Button label="다시 시도" onPress={()=>{void retry();}}/></View>;
}
