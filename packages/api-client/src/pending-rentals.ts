import type {Database} from '@dolpin/contracts';

export type RentalRequest = Database['public']['Functions']['request_rental']['Args'];
export type RequestStorage = {
  getItem(key:string): string|null|Promise<string|null>;
  setItem(key:string,value:string): void|Promise<void>;
  removeItem(key:string): void|Promise<void>;
  runExclusive?<T>(key:string,work:()=>Promise<T>):Promise<T>;
};
// Only a confirmed server rejection permits a new request identity.
export class RentalRequestRejected extends Error {}

const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const timestampMillis=(value:string)=>Date.parse(value.replace(/\.(\d{1,6})(?=Z|[+-])/,(_match,fraction:string)=>`.${fraction.slice(0,3).padEnd(3,'0')}`));
function timestamp(value:unknown):value is string {
  // Normalize precision for JS engines while preserving PostgreSQL's original
  // microsecond version string in the journal and the command sent to the DB.
  if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/.test(value)||!Number.isFinite(timestampMillis(value)))return false;
  // Date.parse normalizes some impossible dates (for example February 30).
  const date=value.slice(0,10),midnight=Date.parse(`${date}T00:00:00Z`);
  return Number.isFinite(midnight)&&new Date(midnight).toISOString().slice(0,10)===date;
}
function validRequest(value:unknown,item:string):value is RentalRequest {
  if(!value||typeof value!=='object'||Array.isArray(value))return false;
  const request=value as Record<string,unknown>;
  return typeof request.p_item_id==='string'&&uuid.test(request.p_item_id)&&request.p_item_id===item
    &&typeof request.p_request_id==='string'&&uuid.test(request.p_request_id)
    &&timestamp(request.p_starts_at)&&timestamp(request.p_ends_at)&&timestamp(request.p_item_version)
    &&timestampMillis(request.p_ends_at)>timestampMillis(request.p_starts_at);
}

export function createPendingRentals(storage:RequestStorage) {
  const key=(owner:string,item:string)=>`dolpin-rental-request-v1.${owner}.${item}`;
  const inFlight=new Map<string,Promise<unknown>>();
  const corrupt=()=>Object.assign(new Error('저장된 예약 요청을 확인하지 못했습니다. 내 거래에서 이전 요청 결과를 확인해 주세요.'),{code:'RENTAL_REQUEST_STORAGE_CORRUPT'});
  async function read(owner:string,item:string):Promise<RentalRequest|null> {
    const raw=await storage.getItem(key(owner,item));
    if(raw===null)return null;
    let request:unknown;
    try {request=JSON.parse(raw);} catch {throw corrupt();}
    if(!validRequest(request,item))throw corrupt();
    return request;
  }
  async function removeOwnRequest(storageKey:string,request:RentalRequest) {
    const raw=await storage.getItem(storageKey);
    if(raw===null)return;
    let current:Partial<RentalRequest>|null;
    try {current=JSON.parse(raw) as Partial<RentalRequest>|null;} catch {return;}
    // An older app/tab may not take the lock. Never erase its different request
    // or an unreadable record whose server outcome is unknown.
    if(current?.p_request_id===request.p_request_id&&current.p_item_id===request.p_item_id)
      await storage.removeItem(storageKey);
  }
  return {
    read,
    submit<T>(owner:string,input:RentalRequest,send:(input:RentalRequest)=>Promise<T>):Promise<T> {
      const storageKey=key(owner,input.p_item_id);
      // Joining the same operation prevents a queued click from creating a new
      // request after the first successful operation has removed its journal.
      const pending=inFlight.get(storageKey);
      if(pending)return pending as Promise<T>;
      const work=async()=>{
        const request=await read(owner,input.p_item_id)??input;
        if(!validRequest(request,input.p_item_id))throw corrupt();
        // Await durable storage before any network request. Storage failure must
        // never leave a server-created reservation without a recovery identity.
        await storage.setItem(storageKey,JSON.stringify(request));
        let result:T;
        try {result=await send(request);} catch(error) {
          if(error instanceof RentalRequestRejected)await removeOwnRequest(storageKey,request);
          throw error;
        }
        await removeOwnRequest(storageKey,request);
        return result;
      };
      const task=storage.runExclusive?storage.runExclusive(storageKey,work):work();
      inFlight.set(storageKey,task);
      const clear=()=>{if(inFlight.get(storageKey)===task)inFlight.delete(storageKey);};
      void task.then(clear,clear);
      return task;
    },
  };
}
