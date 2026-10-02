import type {SupabaseClient} from '@supabase/supabase-js';
import type {Database} from '@dolpin/contracts';

/** New uploads render from our Storage origin even if an API caller supplied a
 * different origin followed by the same validated object path. */
export function withProductPhotos<T extends {photos:string[]}>(client:Pick<SupabaseClient<Database>,'storage'>,item:T):T {
 const marker='/storage/v1/object/public/product-photos/';
 return {...item,photos:item.photos.map(photo=>{
  const index=photo.indexOf(marker);
  if(index<0)return photo;
  const path=photo.slice(index+marker.length);
  return client.storage.from('product-photos').getPublicUrl(path).data.publicUrl;
 })};
}
