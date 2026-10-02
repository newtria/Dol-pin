import {useEffect,useRef} from 'react';
import {AppState,Platform} from 'react-native';
import {router} from 'expo-router';
import Constants from 'expo-constants';
import * as Notifications from 'expo-notifications';
import {useQueryClient} from '@tanstack/react-query';
import {api,client} from './client';
import {useSession} from './session';
import {sessionStorage} from './session-storage';

const tokenKey=(owner:string)=>`dolpin.push-token.${owner}`;
const enabledKey=(owner:string)=>`dolpin.push-enabled.${owner}`;
let work:Promise<unknown>=Promise.resolve();
// Token refresh and logout must not race to register the same device again.
function exclusive<T>(action:()=>Promise<T>):Promise<T>{
 const next=work.catch(()=>{}).then(action);work=next;return next;
}
Notifications.setNotificationHandler({handleNotification:async notification=>{
 const {data}=await client.auth.getSession();
 const belongsToAccount=!!data.session&&notification.request.content.data?.userId===data.session.user.id;
 return {shouldShowBanner:belongsToAccount,shouldShowList:belongsToAccount,shouldPlaySound:false,shouldSetBadge:false};
}});
export function enablePush(requestPermission=true) {
 return exclusive(async()=>{
  if(Platform.OS==='web')throw {code:'PUSH_UNAVAILABLE'};
  const {data}=await client.auth.getUser();if(!data.user)throw {code:'AUTH_REQUIRED'};
  const owner=data.user.id;
  if(!requestPermission&&await sessionStorage.getItem(enabledKey(owner))!=='yes')return;
  const projectId=process.env.EXPO_PUBLIC_EAS_PROJECT_ID??Constants.easConfig?.projectId;
  if(!projectId)throw {code:'PUSH_UNAVAILABLE'};
  if(Platform.OS==='android')await Notifications.setNotificationChannelAsync('transactions',{name:'거래 알림',importance:Notifications.AndroidImportance.DEFAULT});
  let permission=await Notifications.getPermissionsAsync();
  if(!permission.granted&&requestPermission)permission=await Notifications.requestPermissionsAsync();
  if(!permission.granted)throw {code:'PUSH_PERMISSION_REQUIRED'};
  const token=(await Notifications.getExpoPushTokenAsync({projectId})).data;
  const current=await client.auth.getSession();if(current.data.session?.user.id!==owner)throw {code:'AUTH_REQUIRED'};
  await api.registerPushToken(token);
  await sessionStorage.setItem(tokenKey(owner),token);
  await sessionStorage.setItem(enabledKey(owner),'yes');
 });
}
export function disablePush() {
 return exclusive(async()=>{
  if(Platform.OS==='web')return;
  const {data}=await client.auth.getSession();const owner=data.session?.user.id;
  if(!owner)return;
  // Prevent foreground/token listeners from re-enabling after a failed disable.
  await sessionStorage.removeItem(enabledKey(owner));
  const token=await sessionStorage.getItem(tokenKey(owner))??await sessionStorage.getItem('dolpin.push-token');
  if(token)await api.unregisterPushToken(token);
  await sessionStorage.removeItem(tokenKey(owner));
  await sessionStorage.removeItem('dolpin.push-token');
  await sessionStorage.removeItem('dolpin.push-enabled');
  await Notifications.dismissAllNotificationsAsync();
 });
}
export function PushObserver(){
 const {session}=useSession();const queries=useQueryClient();const last=useRef('');
 useEffect(()=>{
  if(!session||Platform.OS==='web')return;
  const owner=session.user.id;let active=true;
  const refresh=async()=>{if(await sessionStorage.getItem(enabledKey(owner))==='yes'&&active)await enablePush(false);};
  void refresh().catch(()=>{});
  const appState=AppState.addEventListener('change',state=>{if(state==='active')void refresh().catch(()=>{});});
  const tokenListener=Notifications.addPushTokenListener(()=>{void refresh().catch(()=>{});});
  function open(response:Notifications.NotificationResponse|null){
   if(!active||!response||last.current===response.notification.request.identifier)return;
   const data=response.notification.request.content.data;
   last.current=response.notification.request.identifier;
   if(data?.userId!==owner||data?.kind==='operations')router.push('/notifications');
   else if(data?.kind==='support'){void queries.invalidateQueries({queryKey:['reports']});router.push('/support');}
   else if(typeof data?.reservationId==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(data.reservationId))router.push(`/rentals/${data.reservationId}`);
   else router.push('/notifications');
   void Notifications.clearLastNotificationResponseAsync().catch(()=>{});
  }
  open(Notifications.getLastNotificationResponse());
  const received=Notifications.addNotificationReceivedListener(()=>{void queries.invalidateQueries({queryKey:['notifications']});void queries.invalidateQueries({queryKey:['rentals']});});
  const response=Notifications.addNotificationResponseReceivedListener(open);
  return()=>{active=false;appState.remove();tokenListener.remove();received.remove();response.remove();};
 },[session?.user.id,queries]);
 return null;
}
