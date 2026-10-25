import {itemInput,type ItemInput} from '@dolpin/contracts';
import type {RequestStorage} from './pending-rentals.ts';
import {ApiRequestError} from './errors.ts';

export type ItemCreationRequest={requestId:string;input:ItemInput;completedItemId?:string};
export class ItemRequestRejected extends Error {
 readonly code?:string;
 constructor(message:string,code?:string){super(message);this.name='ItemRequestRejected';this.code=code;}
}
export class ItemRequestRetired extends ApiRequestError {
 readonly completedItemId?:string;
 constructor(completedItemId?:string){super({code:'STATE_CONFLICT'});this.name='ItemRequestRetired';this.completedItemId=completedItemId;}
}
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function parseRequest(value:unknown):ItemCreationRequest {
 if(!value||typeof value!=='object')throw new ApiRequestError({code:'STATE_CONFLICT'});
 const request=value as ItemCreationRequest;
 if(typeof request.requestId!=='string'||!uuid.test(request.requestId)||request.completedItemId!==undefined&&(typeof request.completedItemId!=='string'||!uuid.test(request.completedItemId)))throw new ApiRequestError({code:'STATE_CONFLICT'});
 return {requestId:request.requestId,input:itemInput.parse(request.input),...(request.completedItemId?{completedItemId:request.completedItemId}:{})};
}

/** A single unresolved creation per account survives reloads and lost responses. */
export function createPendingItems(storage:RequestStorage){
 const key=(owner:string)=>`dolpin-item-request-v1.${owner}`;
 const retiredKey=(owner:string,requestId:string)=>`${key(owner)}.retired.${requestId}`;
 const inFlight=new Map<string,Promise<unknown>>();
 async function assertCurrent(owner:string,requestId:string){
  const retired=await storage.getItem(retiredKey(owner,requestId));
  if(retired!==null)throw new ItemRequestRetired(uuid.test(retired)?retired:undefined);
 }
 async function read(owner:string):Promise<ItemCreationRequest|null>{
  const raw=await storage.getItem(key(owner));if(raw===null)return null;
  let request:ItemCreationRequest;
  try{request=parseRequest(JSON.parse(raw));}catch{throw new ApiRequestError({code:'STATE_CONFLICT'});}
  // A failed removal after startNew must not revive a retired registration.
  return await storage.getItem(retiredKey(owner,request.requestId))===null?request:null;
 }
 async function exclusive<T>(owner:string,work:()=>Promise<T>):Promise<T>{return storage.runExclusive?storage.runExclusive(key(owner),work):work();}
 return {
  read,
  submit<T extends {id:string}>(owner:string,input:ItemCreationRequest,send:(request:ItemCreationRequest)=>Promise<T>):Promise<T>{
   const pending=inFlight.get(owner);
   if(pending)return assertCurrent(owner,input.requestId).then(()=>pending as Promise<T>);
   const task=exclusive(owner,async()=>{
    await assertCurrent(owner,input.requestId);
    const request=await read(owner)??parseRequest(input);
    await assertCurrent(owner,request.requestId);
    await storage.setItem(key(owner),JSON.stringify(request));
    let result:T;
    try{result=await send(request);}catch(error){
     // A committed request may be temporarily unreadable (for example during
     // an auth change). A confirmed receipt must never become a new creation.
     if(error instanceof ItemRequestRejected&&!request.completedItemId){
      const current=await read(owner);
      if(current?.requestId===request.requestId){
       await storage.setItem(retiredKey(owner,request.requestId),'1');
       await storage.removeItem(key(owner));
      }
     }
     throw error;
    }
    if(!uuid.test(result.id))throw new ApiRequestError({});
    await assertCurrent(owner,request.requestId);
    if((await read(owner))?.requestId!==request.requestId)throw new ApiRequestError({code:'STATE_CONFLICT'});
    // Keep the receipt until the user explicitly starts a different listing.
    // An old tab submitting later will still replay this creation identity.
    await storage.setItem(key(owner),JSON.stringify({...request,completedItemId:result.id}));
    return result;
   });
   inFlight.set(owner,task);
   const clear=()=>{if(inFlight.get(owner)===task)inFlight.delete(owner);};
   void task.then(clear,clear);return task;
  },
  async startNew(owner:string,completedRequestId:string){
   if(inFlight.has(owner))throw new ApiRequestError({code:'STATE_CONFLICT'});
   await exclusive(owner,async()=>{
    const request=await read(owner);
    if(!request&&await storage.getItem(retiredKey(owner,completedRequestId))!==null)return;
    if(!request?.completedItemId||request.requestId!==completedRequestId)throw new ApiRequestError({code:'STATE_CONFLICT'});
    // Persist the fence before clearing the active slot. A suspended tab may
    // still hold this ID and must never republish its receipt over a new draft.
    await storage.setItem(retiredKey(owner,request.requestId),request.completedItemId);
    await storage.removeItem(key(owner));
   });
  },
 };
}
