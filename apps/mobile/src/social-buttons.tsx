import {Image, Pressable, View} from 'react-native';
const buttons = [
  {provider:'kakao',label:'카카오 로그인',source:require('../assets/auth/kakao.png'),ratio:600/90},
  {provider:'custom:naver',label:'네이버 로그인',source:require('../assets/auth/naver.png'),ratio:1472/224},
  {provider:'google',label:'Google로 로그인',source:require('../assets/auth/google.png'),ratio:564/132},
  {provider:'apple',label:'Apple로 로그인',source:require('../assets/auth/apple.png'),ratio:960/156},
] as const;
export function SocialButtons({onPress,disabled}:{onPress:(provider:typeof buttons[number]['provider'])=>void;disabled:boolean}) {
 return <View style={{gap:12}}>{buttons.map(button=><Pressable key={button.provider} accessibilityRole="button" accessibilityLabel={button.label} accessibilityState={{disabled}} disabled={disabled} onPress={()=>onPress(button.provider)} style={{height:52,width:'100%',justifyContent:'center',alignItems:'center',borderRadius:8,overflow:'hidden',backgroundColor:button.provider==='kakao'?'#FEE500':button.provider==='custom:naver'?'#03A94D':'#FFFFFF',borderWidth:button.provider==='google'?1:0,borderColor:'#747775'}}>
   {button.provider==='google' ? <View style={{width:180,height:42,overflow:'hidden'}}><Image source={button.source} accessible={false} style={{position:'absolute',left:-4,top:-1,width:188,height:44}} resizeMode="contain"/></View> : <Image source={button.source} accessible={false} style={{width:'100%',height:52}} resizeMode="contain"/>}
 </Pressable>)}</View>;
}
