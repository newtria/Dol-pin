import {createPendingRentals} from '@dolpin/api-client';

export const pendingRentals=createPendingRentals({
  getItem:key=>localStorage.getItem(key),
  setItem:(key,value)=>localStorage.setItem(key,value),
  removeItem:key=>localStorage.removeItem(key),
});
