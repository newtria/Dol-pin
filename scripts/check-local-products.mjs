import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {createClient} from '@supabase/supabase-js';
const env = Object.fromEntries(readFileSync('apps/mobile/.env.local', 'utf8').trim().split('\n').map(line => {
  const i = line.indexOf('='); return [line.slice(0, i), line.slice(i + 1)];
}));
const url = env.EXPO_PUBLIC_SUPABASE_URL;
assert.match(url, /^http:\/\/127\.0\.0\.1:/);
const options = {auth: {persistSession: false, autoRefreshToken: false}};
async function actor(phone, nickname) {
  const client = createClient(url, env.EXPO_PUBLIC_SUPABASE_ANON_KEY, options);
  assert.ifError((await client.auth.signInWithOtp({phone})).error);
  const login = await client.auth.verifyOtp({phone, token: '123456', type: 'sms'});
  assert.ifError(login.error);
  assert.ifError((await client.rpc('ensure_profile', {p_nickname: nickname})).error);
  return {client, id: login.data.user.id};
}
const lender = await actor('+821055501001', '대여자 테스트');
const outsider = await actor('+821055501003', '비참여자 테스트');
const filename = `${lender.id}/${randomUUID()}.png`;
const bytes = readFileSync('assets/demo/lightstick.png');
assert.ifError((await lender.client.storage.from('product-photos').upload(filename, bytes, {contentType: 'image/png'})).error);
assert.ok((await outsider.client.storage.from('product-photos').upload(`${lender.id}/${randomUUID()}.png`, bytes, {contentType: 'image/png'})).error);
const photo = lender.client.storage.from('product-photos').getPublicUrl(filename).data.publicUrl;
const item = {lender_id: lender.id, title: '[로컬 데모] 콘서트 응원봉', description: '합성 사진을 사용한 검증용 가상 상품입니다.', category: 'lightstick', photos: [photo], daily_price: 5000, currency: 'KRW', deposit: 30000, pickup_method: 'direct'};
const created = await lender.client.from('rental_items').insert(item).select().single();
assert.ifError(created.error);
const anon = createClient(url, env.EXPO_PUBLIC_SUPABASE_ANON_KEY, options);
assert.ifError((await anon.from('rental_items').select('id').eq('id', created.data.id).single()).error);
const attack = await outsider.client.from('rental_items').update({daily_price: 100}).eq('id', created.data.id).select('id');
assert.ok(attack.error || attack.data.length === 0);
assert.ok((await lender.client.from('rental_items').update({bt_verified: true}).eq('id', created.data.id)).error);
assert.ok((await lender.client.from('rental_items').insert({...item, daily_price: -1})).error);
assert.ifError((await lender.client.from('rental_items').update({description: item.description + ' 소유자 수정 검증.'}).eq('id', created.data.id)).error);
await Promise.all([lender.client.auth.signOut(), outsider.client.auth.signOut()]);
console.log('Product upload/create/public read/owner edit passed; foreign upload/edit, trust flag, invalid price rejected.');
console.log(`Local demo item: ${created.data.id}`);
