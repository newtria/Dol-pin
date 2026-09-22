import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {setTimeout as delay} from 'node:timers/promises';
import {randomUUID} from 'node:crypto';
import {createClient} from '@supabase/supabase-js';
const env = Object.fromEntries(readFileSync('apps/mobile/.env.local', 'utf8').trim().split('\n').map(line => {
  const i = line.indexOf('='); return [line.slice(0,i), line.slice(i+1)];
}));
const url = env.EXPO_PUBLIC_SUPABASE_URL;
assert.match(url, /^http:\/\/127\.0\.0\.1:/);
async function actor(phone) {
  const client = createClient(url, env.EXPO_PUBLIC_SUPABASE_ANON_KEY, {auth: {persistSession:false, autoRefreshToken:false}});
  let sent=await client.auth.signInWithOtp({phone});
  if(sent.error?.code==='over_sms_send_rate_limit'){await delay(6000);sent=await client.auth.signInWithOtp({phone});}
  assert.ifError(sent.error);
  const login = await client.auth.verifyOtp({phone, token:'123456', type:'sms'});
  assert.ifError(login.error);
  assert.ifError((await client.rpc('ensure_profile',{p_nickname:'거래 검증'})).error);
  return {client, id:login.data.user.id};
}
const lender = await actor('+821055501001');
const borrower = await actor('+821055501002');
const outsider = await actor('+821055501003');
const created = await lender.client.from('rental_items').insert({lender_id:lender.id,
 title:'[검증] 예약 경합 응원봉', category:'lightstick', photos:['https://example.invalid/fixture.png'],
 daily_price:5000, deposit:30000, currency:'KRW', pickup_method:'direct'}).select('id,updated_at').single();
assert.ifError(created.error);
const item=created.data;
const day = new Date(Date.now()+86400000*7).toISOString().slice(0,10);
const input={p_item_id:item.id,p_starts_at:`${day}T10:00:00+09:00`,p_ends_at:`${day}T20:00:00+09:00`,p_item_version:item.updated_at,p_request_id:randomUUID()};
const first=await borrower.client.rpc('request_rental',input); assert.ifError(first.error);
assert.equal(first.data.rental_fee,5000); assert.equal(first.data.total_paid,35000);
assert.equal(first.data.rental_date,first.data.return_date);
assert.equal((await borrower.client.rpc('request_rental',input)).data.id,first.data.id);
assert.ok((await borrower.client.rpc('request_rental',{...input,p_ends_at:`${day}T21:00:00+09:00`})).error);
assert.ok((await borrower.client.rpc('respond_to_rental',{p_reservation_id:first.data.id,p_action:'accept'})).error);
assert.ok((await outsider.client.rpc('respond_to_rental',{p_reservation_id:first.data.id,p_action:'reject'})).error);
assert.equal((await outsider.client.from('reservations').select('id').eq('id',first.data.id)).data.length,0);
assert.ok((await borrower.client.from('reservations').update({status:'accepted'}).eq('id',first.data.id)).error);
assert.ok((await borrower.client.rpc('create_reservation_intent',{p_item_id:item.id,p_rental_date:day,p_return_date:day})).error);
const second=await outsider.client.rpc('request_rental',{...input,p_request_id:randomUUID()}); assert.ifError(second.error);
const results=await Promise.all([first.data.id,second.data.id].map(id=>lender.client.rpc('respond_to_rental',{p_reservation_id:id,p_action:'accept'})));
assert.equal(results.filter(r=>!r.error).length,1);
assert.equal(results.filter(r=>r.error?.code==='23P01').length,1);
const winner=results.find(r=>!r.error).data;
assert.equal(winner.terms_snapshot.total,35000);
assert.equal((await lender.client.rpc('respond_to_rental',{p_reservation_id:winner.id,p_action:'accept'})).data.id,winner.id);
const before=await lender.client.from('rental_events').select('id').eq('reservation_id',winner.id);
assert.equal(before.data.length,2);
assert.ifError((await lender.client.from('rental_items').update({daily_price:9000}).eq('id',item.id)).error);
const stored=await lender.client.from('reservations').select('*').eq('id',winner.id).single();
assert.equal(stored.data.terms_snapshot.daily_price,5000); assert.equal(stored.data.total_paid,35000);
const loser=winner.id===first.data.id?second.data:first.data;
assert.ok((await lender.client.rpc('respond_to_rental',{p_reservation_id:loser.id,p_action:'accept'})).error);
assert.ifError((await lender.client.rpc('respond_to_rental',{p_reservation_id:loser.id,p_action:'reject'})).error);
assert.ok((await borrower.client.rpc('expire_unpaid_rentals')).error);
await Promise.all([lender.client.auth.signOut(),borrower.client.auth.signOut(),outsider.client.auth.signOut()]);
console.log('Same-day quote, request idempotency, acceptance concurrency, frozen terms, events and authorization passed.');
