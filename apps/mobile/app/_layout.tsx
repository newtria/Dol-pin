import {useState} from 'react';
import {Stack} from 'expo-router';
import {QueryClient, QueryClientProvider} from '@tanstack/react-query';
import {SessionProvider} from '../src/session';
import {colors} from '../src/ui';
export default function Layout() {
  const [queries] = useState(() => new QueryClient({defaultOptions: {queries: {staleTime: 15000, retry: 1}, mutations: {retry: false}}}));
  return <QueryClientProvider client={queries}><SessionProvider><Stack screenOptions={{headerStyle: {backgroundColor: colors.background}, headerTintColor: colors.text, contentStyle: {backgroundColor: colors.background}}}>
    <Stack.Screen name="index" options={{headerShown: false}}/>
    <Stack.Screen name="account" options={{title: '계정', headerBackTitle: '탐색'}}/>
    <Stack.Screen name="items/[id]" options={{title: '물품 상세', headerBackTitle: '탐색'}}/>
  </Stack></SessionProvider></QueryClientProvider>;
}
