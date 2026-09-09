import type { SupabaseClient } from '@supabase/supabase-js';
import {itemInput, type ItemInput, type Database} from '@dolpin/contracts';

export type Client = SupabaseClient<Database>;
export type Item = Database['public']['Tables']['rental_items']['Row'];
export type Concert = Database['public']['Tables']['concerts']['Row'];

function value<T>(result: {data: T; error: {message: string; code?:string} | null}): T {
  if (result.error) throw new Error(result.error.code==='23P01' ? '같은 기간에 이미 수락된 예약이 있습니다.' : result.error.message);
  return result.data;
}

export function createApi(client: Client) {
  return {
    async rentals() {
      return value(await client.from('reservations').select('*, item:rental_items!reservations_item_id_fkey(title)').order('created_at', {ascending:false}).limit(50));
    },
    async rental(id:string) {
      return value(await client.from('reservations').select('*, item:rental_items!reservations_item_id_fkey(title)').eq('id',id).single());
    },
    async requestRental(input:Database['public']['Functions']['request_rental']['Args']) {
      const rental=value(await client.rpc('request_rental',input));
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
