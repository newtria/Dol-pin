import type {Database} from '@dolpin/contracts';

export type RentalRequest = Database['public']['Functions']['request_rental']['Args'];
export type RequestStorage = {
  getItem(key:string): string|null|Promise<string|null>;
  setItem(key:string,value:string): void|Promise<void>;
  removeItem(key:string): void|Promise<void>;
};
// Only a confirmed server rejection permits a new request identity.
export class RentalRequestRejected extends Error {}

export function createPendingRentals(storage:RequestStorage) {
  const key=(owner:string,item:string)=>`dolpin-rental-request-v1.${owner}.${item}`;
  async function read(owner:string,item:string):Promise<RentalRequest|null> {
    const raw=await storage.getItem(key(owner,item));
    if(!raw)return null;
    const request=JSON.parse(raw) as RentalRequest;
    if(request.p_item_id!==item || !['p_request_id','p_starts_at','p_ends_at','p_item_version'].every(k=>typeof request[k as keyof RentalRequest]==='string'))
      throw new Error('저장된 예약 요청을 확인할 수 없습니다.');
    return request;
  }
  return {
    read,
    async submit<T>(owner:string,input:RentalRequest,send:(input:RentalRequest)=>Promise<T>):Promise<T> {
      const request=await read(owner,input.p_item_id)??input;
      // Await durable storage before any network request. Storage failure must
      // never leave a server-created reservation without a recovery identity.
      await storage.setItem(key(owner,input.p_item_id),JSON.stringify(request));
      let result:T;
      try {result=await send(request);} catch(error) {
        if(error instanceof RentalRequestRejected)await storage.removeItem(key(owner,input.p_item_id));
        throw error;
      }
      await storage.removeItem(key(owner,input.p_item_id));
      return result;
    },
  };
}
