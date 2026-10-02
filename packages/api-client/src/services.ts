import type {SupabaseClient} from '@supabase/supabase-js';
import {itemInput, type Database, type ItemInput} from '@dolpin/contracts';
import {ApiRequestError} from './errors.ts';
import {withProductPhotos} from './photos.ts';

type Json = Database['public']['Tables']['rental_items']['Row']['pickup_location'];
export type OwnedItem = Database['public']['Tables']['rental_items']['Row'] & {moderated_at:string|null};
export type OperationItem = Pick<OwnedItem,'id'|'title'|'description'|'photos'|'daily_price'|'deposit'|'status'|'moderated_at'>;
export type ServiceMessage = Database['public']['Tables']['chat_messages']['Row'] & {client_request_id:string|null};
export type ServiceNotification = {id:string;user_id:string;event_key:string;kind:string;title:string;body:string;reservation_id:string|null;read_at:string|null;created_at:string};
export type ServiceCursor = {createdAt:string;id:string};
export type ConsentStatus = {termsVersion:string;privacyVersion:string;accepted:boolean};
export type ServiceReport = Database['public']['Tables']['reports']['Row'] & {reservation_id:string|null;resolution_note:string|null};
export type ServiceOperations = {
 reports: {id:string;reporter_id:string;reported_user_id:string|null;reported_item_id:string|null;reservation_id:string|null;reason:string;description:string|null;status:string;created_at:string}[];
 users: {id:string;nickname:string;suspended_at:string|null;deleted_at:string|null}[];
 items: {id:string;title:string;lender_id:string;moderated_at:string;status:string}[];
 notifications: {id:string;status:string;last_code:string|null;attempt_count:number;canRetry:boolean}[];
 closures: {user_id:string;requested_at:string;attempts:number}[];
 hasMore:boolean;
 health: {configured:boolean;scheduled:boolean;pushNeedsReview:number;pendingClosures:number;pendingReports:number;rentalReviews:number;payoutNeedsReview:number;paymentRecoveryStalled:number;photoCleanupNeedsReview:number;lastDispatch:unknown;payments:unknown};
};
type Rpc<Args,Returns> = {Args:Args;Returns:Returns};
type ServiceDatabase = Omit<Database,'public'> & {public: Omit<Database['public'],'Functions'|'Tables'> & {
 Tables: Omit<Database['public']['Tables'],'chat_messages'|'reports'> & {
  chat_messages: Omit<Database['public']['Tables']['chat_messages'],'Row'> & {Row:ServiceMessage};
  reports: Omit<Database['public']['Tables']['reports'],'Row'> & {Row:ServiceReport};
  notifications: {Row:ServiceNotification;Insert:never;Update:never;Relationships:[]};
 };
 Functions: Database['public']['Functions'] & {
  update_my_profile: Rpc<{p_nickname:string;p_region?:string|null;p_locale?:string;p_update_region?:boolean},Database['public']['Tables']['users']['Row']>;
  consent_status: Rpc<Record<string,never>,ConsentStatus>;
  record_consent: Rpc<{p_terms_version:string;p_privacy_version:string},undefined>;
  my_items: Rpc<{p_offset?:number},OwnedItem[]>;
  update_my_item: Rpc<{p_item_id:string;p_input:Json},OwnedItem>;
  set_my_item_status: Rpc<{p_item_id:string;p_status:string},OwnedItem>;
  item_availability: Rpc<{p_item_id:string},{starts_at:string;ends_at:string}[]>;
  send_rental_message: Rpc<{p_reservation_id:string;p_message:string;p_request_id:string},ServiceMessage>;
  mark_rental_messages_read: Rpc<{p_reservation_id:string},undefined>;
  mark_notification_read: Rpc<{p_id:string},undefined>;
  set_user_block: Rpc<{p_user_id:string;p_blocked:boolean},undefined>;
  my_blocked_users: Rpc<{p_offset?:number},{id:string;nickname:string}[]>;
  submit_report: Rpc<{p_user_id:string|null;p_item_id:string|null;p_reason:string;p_description?:string|null;p_reservation_id?:string|null},undefined>;
  register_push_token: Rpc<{p_token:string;p_enabled:boolean},undefined>;
 };
}};
function checked<T>(result:{data:T;error:{message:string;code?:string}|null}):T {
 if(result.error) {
  const code = result.error.code === 'P4290' ? 'RATE_LIMITED' : result.error.code;
  throw Object.assign(new Error('요청을 처리하지 못했습니다.'),{code});
 }
 return result.data;
}
function present<T>(value:T|null):T {
 if(value===null)throw new ApiRequestError({code:'SERVICE_UNAVAILABLE'});
 return value;
}
function validateCursor(cursor:ServiceCursor) {
 if(!/^\d{4}-\d{2}-\d{2}T[\d:.]+(?:Z|[+-]\d{2}:?\d{2})$/.test(cursor.createdAt)||!Number.isFinite(Date.parse(cursor.createdAt))||!/^[a-f0-9-]{36}$/i.test(cursor.id))
  throw new ApiRequestError({code:'INVALID_REQUEST'});
}

export function createServiceApi(base:SupabaseClient<Database>) {
 const client=base as unknown as SupabaseClient<ServiceDatabase>;
 async function invoke<T>(name:string,body:Record<string,unknown>):Promise<T> {
  const {data,error}=await client.functions.invoke(name,{body});
  if(error||data?.error) {
   const context=(error as {context?:Response}|null)?.context;
   throw new ApiRequestError(data?.error?data:context?await context.json().catch(()=>({})):{});
  }
  return data as T;
 }
 return {
  async updateProfile(input:{nickname:string;region?:string|null;locale?:string}) {
   return present(checked(await client.rpc('update_my_profile',{
    p_nickname:input.nickname,
    ...(input.region!==undefined?{p_region:input.region,p_update_region:true}:{}),
    ...(input.locale!==undefined?{p_locale:input.locale}:{}),
   })));
  },
  async closeAccount(){return invoke<{status:'closed'|'pending'}>('account-lifecycle',{action:'close'});},
  async consentStatus(){return present(checked(await client.rpc('consent_status')));},
  async recordConsent(input:{termsVersion:string;privacyVersion:string}) {
   checked(await client.rpc('record_consent',{p_terms_version:input.termsVersion,p_privacy_version:input.privacyVersion}));
  },
  async myItems(offset=0){return (checked(await client.rpc('my_items',{p_offset:offset}))??[]).map(item=>withProductPhotos(base,item));},
  async updateItem(id:string,input:ItemInput) {
   return withProductPhotos(base,present(checked(await client.rpc('update_my_item',{p_item_id:id,p_input:itemInput.parse(input)}))));
  },
  async setItemStatus(id:string,status:'active'|'hidden') {return withProductPhotos(base,present(checked(await client.rpc('set_my_item_status',{p_item_id:id,p_status:status}))));},
  async itemAvailability(id:string){return checked(await client.rpc('item_availability',{p_item_id:id}))??[];},
  async messages(reservationId:string,before?:ServiceCursor) {
   let query=client.from('chat_messages').select('*').eq('reservation_id',reservationId).order('created_at',{ascending:false}).order('id',{ascending:false});
   if(before){validateCursor(before);query=query.or(`created_at.lt.${before.createdAt},and(created_at.eq.${before.createdAt},id.lt.${before.id})`);}
   return checked(await query.limit(50))??[];
  },
  async sendMessage(reservationId:string,message:string,requestId:string){return present(checked(await client.rpc('send_rental_message',{p_reservation_id:reservationId,p_message:message,p_request_id:requestId})));},
  async markMessagesRead(reservationId:string){checked(await client.rpc('mark_rental_messages_read',{p_reservation_id:reservationId}));},
  async notifications(before?:ServiceCursor) {
   let query=client.from('notifications').select('*').order('created_at',{ascending:false}).order('id',{ascending:false});
   if(before){validateCursor(before);query=query.or(`created_at.lt.${before.createdAt},and(created_at.eq.${before.createdAt},id.lt.${before.id})`);}
   return checked(await query.limit(50))??[];
  },
  async markNotificationRead(id:string){checked(await client.rpc('mark_notification_read',{p_id:id}));},
  async blockUser(id:string,blocked:boolean){checked(await client.rpc('set_user_block',{p_user_id:id,p_blocked:blocked}));},
  async blockedUsers(offset=0){return checked(await client.rpc('my_blocked_users',{p_offset:offset}))??[];},
  async report(input:{userId?:string;itemId?:string;reservationId?:string;reason:'fraud'|'abuse'|'unsafe'|'prohibited'|'other';description?:string}) {
   checked(await client.rpc('submit_report',{p_user_id:input.userId??null,p_item_id:input.itemId??null,p_reason:input.reason,p_description:input.description??null,p_reservation_id:input.reservationId??null}));
  },
  async reports(offset=0){
   if(!Number.isSafeInteger(offset)||offset<0)throw new ApiRequestError({code:'INVALID_REQUEST'});
   return checked(await client.from('reports').select('id,reason,description,status,created_at,resolved_at,resolution_note,reservation_id').order('created_at',{ascending:false}).order('id',{ascending:false}).range(offset,offset+49))??[];
  },
  async registerPushToken(token:string){checked(await client.rpc('register_push_token',{p_token:token,p_enabled:true}));},
  async unregisterPushToken(token:string){checked(await client.rpc('register_push_token',{p_token:token,p_enabled:false}));},
  async operations(offset=0){return invoke<ServiceOperations>('service-ops',{action:'list',offset});},
  async operationItem(id:string){return withProductPhotos(base,await invoke<OperationItem>('service-ops',{action:'itemDetail',targetId:id}));},
  async moderateReport(id:string,status:'resolved'|'dismissed',reason:string){return invoke<{ok:true}>('service-ops',{action:status,targetId:id,reason});},
  async setUserSuspended(id:string,suspended:boolean,reason:string){return invoke<{ok:true}>('service-ops',{action:'suspend',targetId:id,value:suspended,reason});},
  async moderateItem(id:string,hidden:boolean,reason:string){return invoke<{ok:true}>('service-ops',{action:'item',targetId:id,value:hidden,reason});},
  async retryNotification(id:string){return invoke<{ok:true}>('service-ops',{action:'retry_notification',targetId:id});},
  async dismissNotification(id:string){return invoke<{ok:true}>('service-ops',{action:'dismiss_notification',targetId:id});},
 };
}
