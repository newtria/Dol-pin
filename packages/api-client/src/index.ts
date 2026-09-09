import {RentalRequestRejected} from './pending-rentals.ts';
export {createPendingRentals, RentalRequestRejected, type RentalRequest} from './pending-rentals.ts';
import type { SupabaseClient } from '@supabase/supabase-js';
import {itemInput, type ItemInput, type Database} from '@dolpin/contracts';

export type Client = SupabaseClient<Database>;
export type Item = Database['public']['Tables']['rental_items']['Row'];
export type RentalCursor = {createdAt:string;id:string};
export type Concert = Database['public']['Tables']['concerts']['Row'];

function value<T>(result: {data: T; error: {message: string; code?:string} | null}): T {
  if (result.error) throw new Error(result.error.code==='23P01' ? '같은 기간에 이미 수락된 예약이 있습니다.' : result.error.message);
  return result.data;
}

export function createApi(client: Client) {
  return {
    async preparePayment(reservationId: string, mobile = false): Promise<{checkoutUrl: string}> {
      const {data,error} = await client.functions.invoke('toss-payment', {body: {action:'prepare',reservationId,mobile}});
      if(error || data?.error) throw new Error(data?.error ?? '결제창을 준비하지 못했습니다. 설정과 예약 상태를 확인해 주세요.');
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
    async concerts() {
      return value(await client.from('concerts').select('*').order('concert_date').limit(50));
    },
    async items(filter: {concertId?: string; category?: string; search?: string}) {
      let query = client.from('rental_items').select('*').eq('status', 'active').order('created_at', {ascending: false}).limit(50);
      if (filter.concertId) query = query.eq('concert_id', filter.concertId);
      if (filter.category) query = query.eq('category', filter.category);
      if (filter.search?.trim()) query = query.ilike('title', `%${filter.search.trim().replace(/[\\%_]/g, '\\$&')}%`);
      return value(await query);
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
