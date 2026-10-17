import {Pressable, StyleSheet, Text, TextInput, View, ActivityIndicator, type TextInputProps} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {Ionicons} from '@expo/vector-icons';
import {router, usePathname} from 'expo-router';
import type {ReactNode} from 'react';
import {errorMessage} from './error-message';
import {errorRequestId} from '@dolpin/api-client/errors';

export const colors = {background: '#F6F7F3', surface: '#FFFFFF', primary: '#087F73', text: '#182D2A', muted: '#596D67', border: '#DCE5DF', error: '#B13838', soft: '#E5F3ED', onPrimary: '#FFFFFF'};
export const s = StyleSheet.create({
  page: {flex: 1, backgroundColor: colors.background}, content: {padding: 20, paddingBottom: 32, gap: 20},
  title: {color: colors.text, fontSize: 28, lineHeight: 36, fontWeight: '700', letterSpacing: -0.8}, heading: {color: colors.text, fontSize: 19, lineHeight: 27, fontWeight: '600', letterSpacing: -0.3},
  body: {color: colors.text, fontSize: 16, lineHeight: 25}, muted: {color: colors.muted, fontSize: 14, lineHeight: 22},
  row: {flexDirection: 'row', alignItems: 'center', gap: 12}, card: {padding: 18, gap: 12, borderRadius: 20, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border},
  price: {color: colors.primary, fontSize: 23, lineHeight: 30, fontWeight: '700'},
  input: {minHeight: 52, backgroundColor: colors.surface, borderColor: colors.border, borderWidth: 1, borderRadius: 14, padding: 15, color: colors.text, fontSize: 16},
  label: {color: colors.text, fontSize: 14, lineHeight: 22, fontWeight: '600'},
});
export function Page({children}: {children: ReactNode}) {return <SafeAreaView edges={['top']} style={s.page}>{children}</SafeAreaView>;}
export function Field({label, style, ...props}: TextInputProps & {label: string}) {return <View style={{gap: 8}}><Text style={s.label}>{label}</Text><TextInput accessibilityLabel={label} placeholderTextColor={colors.muted} style={[s.input, props.multiline ? {minHeight: 120, textAlignVertical: 'top'} : null, props.editable === false ? {opacity: 0.6} : null, style]} {...props}/></View>;}
export function Button({label, onPress, disabled, secondary}: {label: string; onPress: () => void; disabled?: boolean; secondary?: boolean}) {
  return <Pressable accessibilityRole="button" accessibilityLabel={label} accessibilityState={{disabled: !!disabled}} disabled={disabled} onPress={onPress} style={({pressed}) => ({minHeight: 50, justifyContent: 'center', paddingHorizontal: 16, paddingVertical: 13, borderRadius: 14, borderWidth: 1, borderColor: secondary ? colors.border : colors.primary, backgroundColor: secondary ? colors.surface : colors.primary, opacity: disabled ? 0.45 : pressed ? 0.75 : 1})}>
    <Text style={{color: secondary ? colors.text : colors.onPrimary, fontSize: 15, lineHeight: 22, fontWeight: '600', textAlign: 'center'}}>{label}</Text>
  </Pressable>;
}
export function Chip({label, selected, onPress}: {label: string; selected: boolean; onPress: () => void}) {
  return <Pressable accessibilityRole="button" accessibilityState={{selected}} onPress={onPress} style={{minHeight: 44, justifyContent: 'center', paddingHorizontal: 16, paddingVertical: 10, borderRadius: 24, borderWidth: 1, borderColor: selected ? colors.primary : colors.border, backgroundColor: selected ? colors.primary : colors.surface}}><Text style={{color: selected ? colors.onPrimary : colors.text, fontWeight: selected ? '600' : '400', fontSize: 14}}>{label}</Text></Pressable>;
}
export function Section({title, children, description}: {title: string; children: ReactNode; description?: string}) {
  return <View style={s.card}><Text accessibilityRole="header" style={s.heading}>{title}</Text>{description ? <Text style={s.muted}>{description}</Text> : null}{children}</View>;
}
export function EmptyState({title, body, action, onAction}: {title: string; body: string; action?: string; onAction?: () => void}) {
  return <View style={[s.card, {paddingVertical: 28}]}><Text accessibilityRole="header" style={s.heading}>{title}</Text><Text style={s.muted}>{body}</Text>{action && onAction ? <Button label={action} onPress={onAction}/> : null}</View>;
}
export function LoadingState({label='불러오는 중입니다'}: {label?: string}) {return <View accessibilityRole="progressbar" accessibilityLabel={label} style={[s.row,{paddingVertical:24,justifyContent:'center'}]}><ActivityIndicator color={colors.primary}/><Text style={s.muted}>{label}</Text></View>;}
export function ErrorText({error, onRetry, retrying}: {error: unknown; onRetry?: () => void; retrying?: boolean}) {
  const requestId=errorRequestId(error);
  return error ? <View style={{gap: 12, backgroundColor:'#FFF0EC',borderRadius:14,padding:16}}><Text accessibilityRole="alert" style={{color: colors.error, lineHeight: 22}}>{errorMessage(error)}</Text>{requestId?<Text selectable style={s.muted}>문의 코드: {requestId}</Text>:null}{onRetry ? <Button label={retrying ? '다시 불러오는 중' : '다시 시도'} disabled={retrying} secondary onPress={onRetry}/> : null}</View> : null;
}
/** Validation copy is authored locally by the form schema, never by an API. */
export function ValidationText({error}: {error?: string}) {return error ? <Text accessibilityRole="alert" style={{color: colors.error, lineHeight: 22}}>{error}</Text> : null;}
const destinations = [
  {path: '/', label: '둘러보기', icon: 'search-outline'},
  {path: '/rentals', label: '내 거래', icon: 'swap-horizontal-outline'},
  {path: '/notifications', label: '알림', icon: 'notifications-outline'},
  {path: '/account', label: '내 정보', icon: 'person-outline'},
] as const;
export function MainNavigation() {
  const pathname=usePathname();
  if(!['/','/rentals','/notifications','/account','/items/mine'].includes(pathname))return null;
  return <SafeAreaView edges={['bottom']} style={{backgroundColor: colors.surface,borderTopWidth:1,borderTopColor:colors.border}}><View style={{flexDirection:'row'}}>{destinations.map(destination=>{
    const selected=destination.path===pathname||(destination.path==='/account'&&pathname==='/items/mine');
    return <Pressable key={destination.path} accessibilityRole="tab" accessibilityLabel={destination.label} accessibilityState={{selected}} onPress={()=>{if(destination.path!==pathname)router.navigate(destination.path);}} style={{flex:1,minHeight:64,alignItems:'center',justifyContent:'center',gap:4}}><Ionicons name={destination.icon} size={22} color={selected?colors.primary:colors.muted}/><Text style={{fontSize:12,fontWeight:selected?'700':'400',color:selected?colors.primary:colors.muted}}>{destination.label}</Text></Pressable>;
  })}</View></SafeAreaView>;
}
