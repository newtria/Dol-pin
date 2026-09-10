import {ApiRequestError} from './errors.ts';
export {ApiRequestError} from './errors.ts';
import {RentalRequestRejected} from './pending-rentals.ts';
export {createPendingRentals, RentalRequestRejected, type RentalRequest} from './pending-rentals.ts';
import type { SupabaseClient } from '@supabase/supabase-js';
import {itemInput, type ItemInput, type Database} from '@dolpin/contracts';

export type Client = SupabaseClient<Database>;
export type Item = Database['public']['Tables']['rental_items']['Row'];
export type RentalCursor = {createdAt:string;id:string};
export type ConcertCursor = {date:string;id:string};
export type Concert = Database['public']['Tables']['concerts']['Row'];

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
    async requestRental(input:Database['public']['Functions']['request_rental']['Args']) {
      const result=await client.rpc('request_rental',input);
      if(result.error) {
        // PostgreSQL errors are definitive transaction failures; transport,
        // gateway and ambiguous responses retain the recovery request.
        const rejected=result.status>=400 && result.status<500 && /^[0-9A-Z]{5}$/.test(result.error.code??'');
        throw rejected?new RentalRequestRejected(result.error.message):new Error(result.error.message);
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
    async items(filter: {concertId?: string; category?: string; search?: string},cursor?:RentalCursor) {
      let query = client.from('rental_items').select('*').eq('status', 'active').order('created_at', {ascending: false}).order('id',{ascending:false});
      if (filter.concertId) query = query.eq('concert_id', filter.concertId);
      if (filter.category) query = query.eq('category', filter.category);
      if (filter.search?.trim()) query = query.ilike('title', `%${filter.search.trim().replace(/[\\%_]/g, '\\$&')}%`);
      if(cursor)query=query.or(`created_at.lt.${cursor.createdAt},and(created_at.eq.${cursor.createdAt},id.lt.${cursor.id})`);
      const rows=value(await query.limit(51))??[];const last=rows[49];
      return {rows:rows.slice(0,50),nextCursor:rows.length>50&&last.created_at?{createdAt:last.created_at,id:last.id}:undefined};
    },
    async recoverPayment(reservationId:string) {
      return invoke('toss-payment',{action:'recover',reservationId});
    },
    async moneyAction(reservationId:string,action:'refund'|'settle') {
      return invoke('rental-payment',{action,reservationId});
    },
    async pickupRental(reservationId:string) {
      const result=value(await client.rpc('transition_reservation_status',{p_reservation_id:reservationId,p_target:'picked_up'})) as {ok?:boolean;error?:string};
      if(!result.ok)throw new Error(result.error??'인수를 확인하지 못했습니다.');
      return result;
    },
    async returnRental(reservationId:string,path:string) {
      return value(await client.rpc('return_rental',{p_reservation_id:reservationId,p_photo_path:path}));
    },
    async evidenceUrl(path:string) {
      const result=value(await client.storage.from('rental-evidence').createSignedUrl(path,300));
      if(!result)throw new Error('반납 사진을 불러오지 못했습니다.');
      return result.signedUrl;
    },
    async item(id: string) {
      return value(await client.from('rental_items').select('*').eq('id', id).single());
    },
    async createItem(input: ItemInput) {
      const parsed = itemInput.parse(input);
      const auth = await client.auth.getUser();
      if (auth.error || !auth.data.user) throw new Error('로그인이 필요합니다.');
      const item = value(await client.from('rental_items').insert({...parsed, lender_id: auth.data.user.id, currency: 'KRW'}).select().single());
      if (!item) throw new Error('등록한 물품을 확인하지 못했습니다.');
      return item;
    },
    async profile(id: string) {
      return value(await client.from('users').select('*').eq('id', id).maybeSingle());
    },
    async ensureProfile(nickname: string) {
      return value(await client.rpc('ensure_profile', {p_nickname: nickname}));
    },
  };
}
