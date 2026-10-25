import {Platform} from 'react-native';
import * as SecureStore from 'expo-secure-store';
import {createPendingItems,ApiRequestError} from '@dolpin/api-client';

export const pendingItems=createPendingItems({
 getItem:key=>Platform.OS==='web'?localStorage.getItem(key):SecureStore.getItemAsync(key),
 setItem:(key,value)=>Platform.OS==='web'?localStorage.setItem(key,value):SecureStore.setItemAsync(key,value),
 removeItem:key=>Platform.OS==='web'?localStorage.removeItem(key):SecureStore.deleteItemAsync(key),
 runExclusive:async(key,work)=>{
  if(Platform.OS!=='web')return work();
  if(!navigator.locks)throw new ApiRequestError({code:'SERVICE_UNAVAILABLE'});
  return navigator.locks.request(key,{ifAvailable:true},lock=>{
   if(!lock)throw new ApiRequestError({code:'STATE_CONFLICT'});
   return work();
  });
 },
});
