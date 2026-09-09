import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@dolpin/contracts';

export type Client = SupabaseClient<Database>;
export type Item = Database['public']['Tables']['rental_items']['Row'];
export type Concert = Database['public']['Tables']['concerts']['Row'];

function value<T>(result: {data: T; error: {message: string} | null}): T {
  if (result.error) throw new Error(result.error.message);
  return result.data;
}

export function createApi(client: Client) {
  return {
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
    async profile(id: string) {
      return value(await client.from('users').select('*').eq('id', id).maybeSingle());
    },
    async ensureProfile(nickname: string) {
      return value(await client.rpc('ensure_profile', {p_nickname: nickname}));
    },
  };
}
