import {Platform} from 'react-native';
import * as SecureStore from 'expo-secure-store';
import {createPendingRentals} from '@dolpin/api-client';

export const pendingRentals=createPendingRentals({
  getItem:key=>Platform.OS==='web'?localStorage.getItem(key):SecureStore.getItemAsync(key),
  setItem:(key,value)=>Platform.OS==='web'?localStorage.setItem(key,value):SecureStore.setItemAsync(key,value),
  removeItem:key=>Platform.OS==='web'?localStorage.removeItem(key):SecureStore.deleteItemAsync(key),
});
