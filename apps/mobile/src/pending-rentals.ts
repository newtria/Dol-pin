import {Platform} from 'react-native';
import * as SecureStore from 'expo-secure-store';
import {createPendingRentals} from '@dolpin/api-client';

export const pendingRentals=createPendingRentals({
  getItem:key=>Platform.OS==='web'?localStorage.getItem(key):SecureStore.getItemAsync(key),
  setItem:(key,value)=>Platform.OS==='web'?localStorage.setItem(key,value):SecureStore.setItemAsync(key,value),
  removeItem:key=>Platform.OS==='web'?localStorage.removeItem(key):SecureStore.deleteItemAsync(key),
  runExclusive:async(key,work)=>{
    if(Platform.OS!=='web')return work();
    if(!navigator.locks)throw Object.assign(new Error('이 브라우저에서 예약 요청을 안전하게 저장할 수 없습니다. 최신 브라우저를 이용해 주세요.'),{code:'RENTAL_REQUEST_LOCK_UNAVAILABLE'});
    return navigator.locks.request(key,{ifAvailable:true},lock=>{
      if(!lock)throw Object.assign(new Error('다른 탭에서 예약을 요청하고 있습니다. 잠시 후 내 거래에서 확인해 주세요.'),{code:'RENTAL_REQUEST_IN_PROGRESS'});
      return work();
    });
  },
});
