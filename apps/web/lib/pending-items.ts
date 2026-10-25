import {createPendingItems,ApiRequestError} from '@dolpin/api-client';

export const pendingItems=createPendingItems({
 getItem:key=>localStorage.getItem(key),
 setItem:(key,value)=>localStorage.setItem(key,value),
 removeItem:key=>localStorage.removeItem(key),
 runExclusive:async(key,work)=>{
  if(!navigator.locks)throw new ApiRequestError({code:'SERVICE_UNAVAILABLE'});
  return navigator.locks.request(key,{ifAvailable:true},lock=>{
   if(!lock)throw new ApiRequestError({code:'STATE_CONFLICT'});
   return work();
  });
 },
});
