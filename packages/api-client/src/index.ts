import {ApiRequestError} from './errors.ts';
import {createFinanceApi} from './finance.ts';
import {createServiceApi} from './services.ts';
import {withProductPhotos} from './photos.ts';
export type * from './finance.ts';
export type * from './services.ts';
export {ApiRequestError} from './errors.ts';
import {RentalRequestRejected} from './pending-rentals.ts';
export {createPendingRentals, RentalRequestRejected, type RentalRequest} from './pending-rentals.ts';
import type { SupabaseClient } from '@supabase/supabase-js';
import {itemInput, type ItemInput, type Database, type RentalRecoveryStatus} from '@dolpin/contracts';

export type Client = SupabaseClient<Database>;
export type Item = Omit<Database['public']['Tables']['rental_items']['Row'], 'pickup_note' | 'pickup_location' | 'imei'>;
// Explicit projection matches the database's public column grant. A wildcard
// would request private address/device columns and must be rejected by the DB.
const itemColumns = 'id,lender_id,concert_id,category,title,description,photos,daily_price,currency,deposit,condition_grade,vlm_tag,bt_verified,imei_verified,pickup_method,pickup_area,available_from,available_to,status,created_at,updated_at' as const;
export type RentalCursor = {createdAt:string;id:string};
export type ConcertCursor = {date:string;id:string};
export type Concert = Database['public']['Tables']['concerts']['Row'];
export type ItemFilter = {concertId?:string;category?:string;search?:string;pickupArea?:string;startsAt?:string;endsAt?:string};

function value<T>(result: {data: T; error: {message: string; code?:string} | null}): T {
  if (result.error) throw Object.assign(new Error(result.error.code==='23P01' ? '같은 기간에 이미 수락된 예약이 있습니다.' : result.error.message), {code: result.error.code});
  return result.data;
}

export function createApi(client: Client) {
  async function invoke(name:string,body:Record<string,unknown>):Promise<{status:string}> {
    const {data,error}=await client.functions.invoke(name,{body});
    if(error) {
      const context=(error as {context?:Response}).context;
      const detail=context?await context.json().catch(()=>null):null;
      throw new ApiRequestError(detail??{});
    }
    if(data?.error)throw new ApiRequestError(data);
    return data;
  }
  return {
    ...createFinanceApi(client),
    ...createServiceApi(client),
    async preparePayment(reservationId: string, mobile = false): Promise<{checkoutUrl: string}> {
      const {data,error} = await client.functions.invoke('toss-payment', {body: {action:'prepare',reservationId,mobile}});
      if(error || data?.error) {
        const context=(error as {context?:Response}|null)?.context;
        const detail=data?.error?data:context?await context.json().catch(()=>null):null;
        throw new ApiRequestError(detail??{error:'결제창을 준비하지 못했습니다. 잠시 후 다시 시도해 주세요.'});
      }
      return data;
    },
    async rentals({cursor,activeOnly=false}: {cursor?:RentalCursor;activeOnly?:boolean} = {}) {
      const size=50;
      let query=client.from('reservations').select('*, item:rental_items!reservations_item_id_fkey(title)')
        .order('created_at',{ascending:false}).order('id',{ascending:false});
      if(activeOnly)query=query.in('status',['requested','accepted','pending','paid','picked_up','returned','disputed']);
      if(cursor)query=query.or(`created_at.lt.${cursor.createdAt},and(created_at.eq.${cursor.createdAt},id.lt.${cursor.id})`);
      const rows=value(await query.limit(size+1))??[];
      const last=rows[size-1];
      return {rows:rows.slice(0,size),nextCursor:rows.length>size&&last?.created_at?{createdAt:last.created_at,id:last.id}:undefined};
    },
    async rental(id:string) {
      return value(await client.from('reservations').select('*, item:rental_items!reservations_item_id_fkey(title)').eq('id',id).single());
    },
    async requestRental(input:Database['public']['Functions']['request_rental']['Args'],expectedOwner?:string) {
      let accessToken:string|undefined;
      if(expectedOwner!==undefined) {
        const {data,error}=await client.auth.getSession();
        if(error||data.session?.user.id!==expectedOwner||!data.session.access_token)
          throw new ApiRequestError({code:'AUTH_REQUIRED'});
        accessToken=data.session.access_token;
      }
      const command=client.rpc('request_rental',input);
      // Supabase resolves auth again while sending. Pin the journal owner's token
      // so an account change during that await cannot create another user's rental.
      if(accessToken)command.setHeader('Authorization',`Bearer ${accessToken}`);
      const result=await command;
      if(result.error) {
        // PostgreSQL errors are definitive transaction failures; transport,
        // gateway and ambiguous responses retain the recovery request.
        const rejected=result.status>=400 && result.status<500 && /^[0-9A-Z]{5}$/.test(result.error.code??'');
        throw rejected?new RentalRequestRejected(result.error.message,result.error.code)
          :Object.assign(new Error(result.error.message),{code:result.error.code});
      }
      const rental=result.data;
      if (!rental) throw new Error('예약 결과를 확인하지 못했습니다. 같은 요청으로 재시도해 주세요.');
      return rental;
    },
    async respondToRental(id:string, action:'accept'|'reject'|'cancel') {
      return value(await client.rpc('respond_to_rental',{p_reservation_id:id,p_action:action}));
    },
    async concerts(cursor?:ConcertCursor) {
      const today=new Date(Date.now()+9*3600000).toISOString().slice(0,10);
      let query=client.from('concerts').select('*').gte('concert_date',today).order('concert_date').order('id');
      if(cursor)query=query.or(`concert_date.gt.${cursor.date},and(concert_date.eq.${cursor.date},id.gt.${cursor.id})`);
      const rows=value(await query.limit(51))??[];const last=rows[49];
      return {rows:rows.slice(0,50),nextCursor:rows.length>50?{date:last.concert_date,id:last.id}:undefined};
    },
    async items(filter:ItemFilter,cursor?:RentalCursor) {
      // A single database query applies the public visibility, period and area
      // conditions before LIMIT. Filtering a fetched page would hide matches.
      const result=await client.rpc('search_rental_items',{
        p_concert_id:filter.concertId||null,p_category:filter.category?.trim()||null,
        p_search:filter.search?.trim()||null,p_pickup_area:filter.pickupArea?.trim()||null,
        p_starts_at:filter.startsAt||null,p_ends_at:filter.endsAt||null,
        p_before_created_at:cursor?.createdAt??null,p_before_id:cursor?.id??null,
      });
      // Table RLS also permits owners to inspect moderated items. It cannot
      // substitute for the public catalogue's visibility rules when the RPC
      // is missing. Require the migrated schema for every catalogue request.
      if(result.error?.code==='PGRST202')throw new ApiRequestError({code:'SERVICE_UNAVAILABLE'});
      const rows=value(result)??[];
      const last=rows[49];
      return {rows:rows.slice(0,50).map(item=>withProductPhotos(client,item)),
        nextCursor:rows.length>50&&last?{createdAt:last.created_at??'-infinity',id:last.id}:undefined};
    },
    async recoverPayment(reservationId:string) {
      return invoke('toss-payment',{action:'recover',reservationId});
    },
    async recoveryStatus(reservationId:string):Promise<RentalRecoveryStatus> {
      const rows=value(await client.rpc('rental_recovery_status',{p_reservation_id:reservationId}));
      const result=rows?.[0];
      if(!result||!['idle','processing','retry_scheduled','needs_review'].includes(result.state))throw new Error('결제 처리 상태를 확인하지 못했습니다.');
      return result as RentalRecoveryStatus;
    },
    async moneyAction(reservationId:string,action:'refund'|'settle') {
      return invoke('rental-payment',{action,reservationId});
    },
    async pickupRental(reservationId:string) {
      return createFinanceApi(client).pickup(reservationId);
    },
    async returnRental(reservationId:string,path:string) {
      return value(await client.rpc('return_rental',{p_reservation_id:reservationId,p_photo_path:path}));
    },
    async item(id: string) {
      const result=value(await client.from('rental_items').select(itemColumns).eq('id', id).single());
      return result?withProductPhotos(client,result):result;
    },
    async ownItemPickupNote(id: string) {
      return value(await client.rpc('own_item_pickup_note', {p_item_id: id}));
    },
    async createItem(input: ItemInput) {
      const parsed = itemInput.parse(input);
      const auth = await client.auth.getUser();
      if (auth.error || !auth.data.user) throw new Error('로그인이 필요합니다.');
      const item = value(await client.from('rental_items').insert({...parsed, lender_id: auth.data.user.id, currency: 'KRW'}).select(itemColumns).single());
      if (!item) throw new Error('등록한 물품을 확인하지 못했습니다.');
      return withProductPhotos(client,item);
    },
    async profile(id: string) {
      return value(await client.from('users').select('*').eq('id', id).maybeSingle());
    },
    async ensureProfile(nickname: string) {
      return value(await client.rpc('ensure_profile', {p_nickname: nickname}));
    },
  };
}
