import assert from 'node:assert/strict';
import {test} from 'node:test';
import {createClient} from '@supabase/supabase-js';
import {reservationInitialPeriod,reservationContextKey,reservationRouteValue} from '../packages/contracts/src/reservation-context.ts';
import {rentalPeriodInput} from '../packages/contracts/src/index.ts';
import {createApi} from '../packages/api-client/src/index.ts';
import {createPendingRentals} from '../packages/api-client/src/pending-rentals.ts';

const draft={startsAt:'2099-10-18T10:00',endsAt:'2099-10-18T14:00'};
test('an explicit route period replaces the draft as a whole, including missing or invalid dates',()=>{
 assert.deepEqual(reservationInitialPeriod({startsAt:'2099-10-20T10:00'},draft),{startsAt:'2099-10-20T10:00',endsAt:''});
 const invalid=reservationInitialPeriod({startsAt:'2099-02-30T10:00:00Z',endsAt:'2099-03-01T10:00:00Z'},draft);
 assert.equal(invalid.startsAt,'');
 assert.equal(rentalPeriodInput.safeParse(invalid).success,false);
 assert.deepEqual(reservationInitialPeriod({startsAt:'not-a-date'},draft),{startsAt:'',endsAt:''});
});
test('empty route dates use the draft; an incomplete draft never borrows an exploration date',()=>{
 assert.deepEqual(reservationInitialPeriod({startsAt:' ',endsAt:null},draft),draft);
 assert.deepEqual(reservationInitialPeriod({},undefined,draft),draft);
 assert.deepEqual(reservationInitialPeriod({}, {endsAt:draft.endsAt},draft),{startsAt:'',endsAt:draft.endsAt});
 assert.deepEqual(reservationInitialPeriod(),{startsAt:'',endsAt:''});
});
test('web and mobile restore timezone links as the same Korean local period',()=>{
 for(const startsAt of ['2099-10-18T10:00:00+09:00','2099-10-18T10:00:00+0900','2099-10-18T01:00:00Z',' 2099-10-18 10:00 ']){
  const period=reservationInitialPeriod({startsAt,endsAt:'2099-10-18T05:00:00Z'});
  assert.deepEqual(period,draft);
  assert.equal(rentalPeriodInput.safeParse(period).success,true);
 }
});
test('repeated mobile route parameters use the same first value as web links',()=>{
 const repeated={startsAt:[draft.startsAt,'2099-10-19T10:00'],endsAt:[draft.endsAt,'2099-10-20T14:00']};
 assert.deepEqual(reservationInitialPeriod(repeated),draft);
 assert.equal(reservationContextKey('alice','item',repeated),reservationContextKey('alice','item',draft));
 assert.equal(reservationRouteValue(['item','another-item']),'item');
 for(const value of [undefined,null,{},123,[],[null],[[draft.startsAt]]]){
  assert.equal(reservationRouteValue(value),'');
  assert.deepEqual(reservationInitialPeriod({startsAt:value,endsAt:value}),{startsAt:'',endsAt:''});
 }
});
test('changing a date link, account or item resets the reservation form context',()=>{
 const original=reservationContextKey('alice','item',draft);
 for(const key of [
  reservationContextKey('alice','item',{...draft,endsAt:'2099-10-18T15:00'}),
  reservationContextKey('alice','other-item',draft),
  reservationContextKey('bob','item',draft),
  reservationContextKey(null,'item',draft),
 ])assert.notEqual(key,original);
 assert.equal(reservationContextKey(undefined,'item',{}),reservationContextKey(null,'item',{startsAt:null,endsAt:''}));
});

const input={p_item_id:'26000000-0000-4000-8000-000000000001',p_request_id:'36000000-0000-4000-8000-000000000001',p_starts_at:'2099-10-18T01:00:00Z',p_ends_at:'2099-10-18T05:00:00Z',p_item_version:'2026-09-22T01:00:00.123456+00:00'};
test('an account change after saving never sends the old journal as the new borrower',async()=>{
 const storage=new Map();let calls=0;
 const journal=createPendingRentals({getItem:key=>storage.get(key)??null,setItem:(key,value)=>{storage.set(key,value);},removeItem:key=>{storage.delete(key);}});
 const api=createApi({auth:{getSession:async()=>({data:{session:{user:{id:'bob'},access_token:'bob-token'}},error:null})},rpc:()=>{calls++;throw new Error('must not send');}});
 await assert.rejects(journal.submit('alice',input,request=>api.requestRental(request,'alice')),error=>error.code==='AUTH_REQUIRED');
 assert.equal(calls,0);
 assert.deepEqual(await journal.read('alice',input.p_item_id),input);
 assert.equal(await journal.read('bob',input.p_item_id),null);
});
test('missing and failed auth snapshots never send a reservation RPC',async()=>{
 for(const result of [{data:{session:null},error:null},{data:{session:{user:{id:'alice'},access_token:'alice-token'}},error:new Error('session unavailable')}]){
  let calls=0;
  const api=createApi({auth:{getSession:async()=>result},rpc:()=>{calls++;throw new Error('must not send');}});
  await assert.rejects(api.requestRental(input,'alice'),error=>error.code==='AUTH_REQUIRED');
  assert.equal(calls,0);
 }
});
test('the Supabase transport keeps the journal owner token if auth changes during its async lookup',async()=>{
 let sessionReads=0,requests=0;
 const client=createClient('https://reservation-test.invalid','test-anon-key',{
  auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},
  global:{fetch:async(_url,init)=>{
   requests++;
   assert.equal(new Headers(init.headers).get('Authorization'),'Bearer alice-token');
   assert.deepEqual(JSON.parse(init.body),input);
   return new Response(JSON.stringify({id:'confirmed-rental',borrower_id:'alice'}),{status:200,headers:{'Content-Type':'application/json'}});
  }},
 });
 client.auth.getSession=async()=>{
  sessionReads++;
  const owner=sessionReads===1?'alice':'bob';
  return {data:{session:{user:{id:owner},access_token:`${owner}-token`}},error:null};
 };
 assert.equal((await createApi(client).requestRental(input,'alice')).id,'confirmed-rental');
 assert.equal(requests,1);
 assert.ok(sessionReads>=2,'the SDK looked up the changed session while sending');
});
