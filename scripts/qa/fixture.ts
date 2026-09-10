import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import type {Payment,PaymentProvider,ProviderFactory} from '../../supabase/functions/_shared/payment-provider.ts';

export const png=Uint8Array.from(atob('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aF9sAAAAASUVORK5CYII='),c=>c.charCodeAt(0));
export function localAdmin() {
 const url=Deno.env.get('SUPABASE_URL')!;
 if(!/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(url))throw new Error('QA only runs against local Supabase');
 return createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
}
export function checked<R extends {data:unknown;error:unknown}>(r:R):NonNullable<R['data']> {if(r.error)throw r.error;return r.data as NonNullable<R['data']>;}
export function fakeProvider() {
 const payments=new Map<string,Payment>();const cancelIds:string[]=[];
 let loseApproval=false,loseCancel=false;
 const provider:PaymentProvider={
  async lookupOrder(id){return structuredClone(payments.get(id)??null);},
  async lookup(id){const p=[...payments.values()].find(p=>p.id===id);if(!p)throw new Error('fixture payment missing');return structuredClone(p);},
  async confirm(id,orderId,total){const p:Payment={id,orderId,total,refunded:0,currency:'KRW',status:'paid'};payments.set(orderId,p);if(loseApproval){loseApproval=false;throw new Error('QA: approval response lost');}return structuredClone(p);},
  async cancel(id,amount,_total,operationId){cancelIds.push(operationId);const p=[...payments.values()].find(p=>p.id===id)!;p.refunded=amount;p.status=p.refunded===p.total?'cancelled':'paid';if(loseCancel){loseCancel=false;throw new Error('QA: refund response lost');}return structuredClone(p);},
 };
 return {factory:((_name:string)=>provider) as ProviderFactory,payments,cancelIds,loseNextApproval(){loseApproval=true;},loseNextCancel(){loseCancel=true;}};
}
export async function fixture() {
 const admin=localAdmin();const concertIds:string[]=[];const tag=`qa-${crypto.randomUUID()}`;
 async function actor(role:string) {
  const email=`${tag}-${role}@example.invalid`;const password=crypto.randomUUID();
  const created=checked(await admin.auth.admin.createUser({email,password,email_confirm:true}));
  if(!created.user)throw new Error('fixture auth missing');
  const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
  const {session}=checked(await client.auth.signInWithPassword({email,password}));
  checked(await client.rpc('ensure_profile',{p_nickname:`QA ${role}`}));
  return {id:created.user.id,client,session:session!};
 }
 const lender=await actor('lender');const borrower=await actor('borrower');const outsider=await actor('outsider');
 const path=`${lender.id}/${tag}.png`;
 checked(await lender.client.storage.from('product-photos').upload(path,png,{contentType:'image/png'}));
 const photo=lender.client.storage.from('product-photos').getPublicUrl(path).data.publicUrl;
 const item=checked(await lender.client.from('rental_items').insert({lender_id:lender.id,title:`${tag} 응원봉`,description:'수락 당시 설명',pickup_note:'공연장 2번 출구',category:'lightstick',photos:[photo],daily_price:5000,deposit:30000,currency:'KRW',pickup_method:'direct'}).select().single());
 async function rental(offset=0) {
  const current=checked(await lender.client.from('rental_items').select('*').eq('id',item.id).single());
  const r=checked(await borrower.client.rpc('request_rental',{p_item_id:item.id,p_starts_at:new Date(Date.now()+(7+offset)*86400000).toISOString(),p_ends_at:new Date(Date.now()+(7+offset)*86400000+4*3600000).toISOString(),p_item_version:current.updated_at,p_request_id:crypto.randomUUID()}));
  checked(await lender.client.rpc('respond_to_rental',{p_reservation_id:r.id,p_action:'accept'}));return r;
 }
 async function cleanup() {
  const rentals=checked(await admin.from('reservations').select('id').eq('item_id',item.id))??[];
  for(const r of rentals) {
   const evidence=checked(await admin.storage.from('rental-evidence').list(`${r.id}/${borrower.id}`))??[];
   if(evidence.length)checked(await admin.storage.from('rental-evidence').remove(evidence.map(f=>`${r.id}/${borrower.id}/${f.name}`)));
  }
  const photos=checked(await admin.storage.from('product-photos').list(lender.id));
  if(photos.length)checked(await admin.storage.from('product-photos').remove(photos.map(p=>`${lender.id}/${p.name}`)));
  // Event history is intentionally append-only to service_role. Fixture
  // teardown uses local postgres, never expands production table privileges.
  const ids=[lender.id,borrower.id,outsider.id];
  if(ids.some(id=>!/^[0-9a-f-]{36}$/.test(id)))throw new Error('Invalid fixture id');
  const sql=`BEGIN;
   DELETE FROM public.toss_checkout_sessions WHERE order_id IN (SELECT order_id FROM public.toss_checkouts WHERE reservation_id IN (SELECT id FROM public.reservations WHERE lender_id='${lender.id}'));
   DELETE FROM public.toss_checkouts WHERE reservation_id IN (SELECT id FROM public.reservations WHERE lender_id='${lender.id}');
   DELETE FROM public.rental_money_operations WHERE reservation_id IN (SELECT id FROM public.reservations WHERE lender_id='${lender.id}');
   DELETE FROM public.rental_events WHERE reservation_id IN (SELECT id FROM public.reservations WHERE lender_id='${lender.id}');
   DELETE FROM public.reservations WHERE lender_id='${lender.id}';
   DELETE FROM public.rental_items WHERE lender_id='${lender.id}';
   ${concertIds.length?`DELETE FROM public.concerts WHERE id IN (${concertIds.map(id=>`'${id}'`).join(',')});`:''}
   DELETE FROM public.users WHERE id IN (${ids.map(id=>`'${id}'`).join(',')});
   COMMIT;`;
  await localSql(sql);
  for(const a of [lender,borrower,outsider])checked(await admin.auth.admin.deleteUser(a.id));

 }
 return {admin,tag,lender,borrower,outsider,item,rental,cleanup,concertIds};
}

export async function localSql(sql:string) {
 localAdmin();
 const child=new Deno.Command('docker',{args:['exec','-i',Deno.env.get('DOLPIN_QA_DB_CONTAINER')??'supabase_db_dol-pin','psql','-X','-q','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],stdin:'piped',stdout:'piped',stderr:'piped'}).spawn();
 const writer=child.stdin.getWriter();await writer.write(new TextEncoder().encode(sql));await writer.close();
 const result=await child.output();if(!result.success)throw new Error(new TextDecoder().decode(result.stderr));
}
