import {Pressable, StyleSheet, Text, TextInput, View, type TextInputProps, type ViewStyle} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import type {ReactNode} from 'react';
export const colors = {background: '#0D0D0D', surface: '#1A1A2E', primary: '#6C5CE7', text: '#F5F5F5', muted: '#B0B0C3', border: '#2D2D44', error: '#E17055'};
export const s = StyleSheet.create({
  page: {flex: 1, backgroundColor: colors.background}, content: {padding: 20, gap: 20},
  title: {color: colors.text, fontSize: 28, fontWeight: '700'}, heading: {color: colors.text, fontSize: 20, fontWeight: '600'},
  body: {color: colors.text, fontSize: 16, lineHeight: 24}, muted: {color: colors.muted, fontSize: 14, lineHeight: 22},
  row: {flexDirection: 'row', alignItems: 'center', gap: 16}, card: {padding: 16, gap: 12, borderRadius: 12, backgroundColor: colors.surface},
  price: {color: colors.primary, fontSize: 20, fontWeight: '700'},
  input: {backgroundColor: colors.surface, borderColor: colors.border, borderWidth: 1, borderRadius: 12, padding: 16, color: colors.text, fontSize: 16},
});
export function Page({children}: {children: ReactNode}) {return <SafeAreaView edges={['top']} style={s.page}>{children}</SafeAreaView>;}
export function Field({label, ...props}: TextInputProps & {label: string}) {return <View style={{gap: 8}}><Text style={s.muted}>{label}</Text><TextInput accessibilityLabel={label} placeholderTextColor={colors.muted} style={s.input} {...props}/></View>;}
export function Button({label, onPress, disabled, secondary}: {label: string; onPress: () => void; disabled?: boolean; secondary?: boolean}) {
  return <Pressable accessibilityRole="button" accessibilityLabel={label} disabled={disabled} onPress={onPress} style={({pressed}) => ({padding: 16, borderRadius: 12, borderWidth: 1, borderColor: colors.primary, backgroundColor: secondary ? 'transparent' : colors.primary, opacity: disabled ? 0.4 : pressed ? 0.75 : 1})}>
    <Text style={{color: colors.text, fontSize: 16, fontWeight: '600', textAlign: 'center'}}>{label}</Text>
  </Pressable>;
}
export function ErrorText({error}: {error: unknown}) {return error ? <Text accessibilityRole="alert" style={{color: colors.error, lineHeight: 22}}>{error instanceof Error ? error.message : String(error)}</Text> : null;}
