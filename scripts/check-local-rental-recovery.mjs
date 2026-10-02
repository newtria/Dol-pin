import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {mkdtemp,readFile,writeFile,unlink,rm} from 'node:fs/promises';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {randomUUID} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {createClient} from '@supabase/supabase-js';
import {createApi,createPendingRentals} from '../packages/api-client/src/index.ts';
const env=Object.fromEntries(readFileSync('apps/mobile/.env.local','utf8').trim().split('\n').map(l=>{const i=l.indexOf('=');return [l.slice(0,i),l.slice(i+1)];}));
assert.match(env.EXPO_PUBLIC_SUPABASE_URL,/^http:\/\/127\.0\.0\.1:/,'Local fixtures only');
async function actor(phone){
 const client=createClient(env.EXPO_PUBLIC_SUPABASE_URL,env.EXPO_PUBLIC_SUPABASE_ANON_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
 assert.ifError((await client.auth.signInWithOtp({phone})).error);
 const login=await client.auth.verifyOtp({phone,token:'123456',type:'sms'});assert.ifError(login.error);
 assert.ifError((await client.rpc('ensure_profile',{p_nickname:'예약 복구 QA'})).error);
 assert.ifError((await client.rpc('record_consent',{p_terms_version:'2026-09-22',p_privacy_version:'2026-09-22'})).error);
 return {client,api:createApi(client),id:login.data.user.id};
}
const lender=await actor('+821055501001'),borrower=await actor('+821055501002');
const dir=await mkdtemp(join(tmpdir(),'dolpin-api-recovery-'));
const storage={getItem:key=>readFile(join(dir,key),'utf8').catch(e=>{if(e.code==='ENOENT')return null;throw e;}),setItem:(key,value)=>writeFile(join(dir,key),value),removeItem:key=>unlink(join(dir,key))};
try {
 const photo=await lender.client.from('rental_items').select('photos').eq('lender_id',lender.id).like('title','%로컬 데모%').limit(1).single();assert.ifError(photo.error);
 const created=await lender.client.from('rental_items').insert({lender_id:lender.id,title:'[QA] 예약 복구 '+randomUUID().slice(0,8),category:'lightstick',photos:photo.data.photos,daily_price:5000,deposit:30000,currency:'KRW',pickup_method:'direct'}).select('id,updated_at').single();assert.ifError(created.error);
 const item=created.data;
 const input={p_item_id:item.id,p_starts_at:new Date(Date.now()+86400000*10).toISOString(),p_ends_at:new Date(Date.now()+86400000*10+3600000).toISOString(),p_item_version:item.updated_at,p_request_id:randomUUID()};
 let original;
 await assert.rejects(createPendingRentals(storage).submit(borrower.id,input,async request=>{original=await borrower.api.requestRental(request);throw new Error('response lost after DB commit');}));
 const updated=await lender.client.rpc('update_my_item',{p_item_id:item.id,p_input:{daily_price:9000}});assert.ifError(updated.error);
 const resumed=await createPendingRentals(storage).submit(borrower.id,{...input,p_item_version:updated.data.updated_at,p_request_id:randomUUID()},borrower.api.requestRental);
 assert.equal(resumed.id,original.id);assert.equal(resumed.rental_fee,5000);
 const count=await borrower.client.from('reservations').select('id').eq('item_id',item.id);assert.ifError(count.error);assert.equal(count.data.length,1);
 assert.equal(await createPendingRentals(storage).read(borrower.id,item.id),null);
 const fixtureIds=[original.id];
 // Pagination history is batch fixture data, not 52 real reservation commands.
 // Keep the production quota intact and backfill only this local fixture item.
 const historyIds=Array.from({length:52},()=>randomUUID());
 for(const id of [...historyIds,item.id,borrower.id,lender.id])assert.match(id,/^[a-f0-9-]{36}$/i);
 const values=historyIds.map((id,index)=>`('${id}','${item.id}','${borrower.id}','${lender.id}',CURRENT_DATE+10,CURRENT_DATE+11,9000,30000,39000,'KRW','cancelled',now()-interval '${index+1} seconds')`).join(',');
 execFileSync('docker',['exec','-i',process.env.DOLPIN_QA_DB_CONTAINER??'supabase_db_dol-pin','psql','-X','-q','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{
  input:`INSERT INTO public.reservations(id,item_id,borrower_id,lender_id,rental_date,return_date,rental_fee,deposit,total_paid,currency,status,created_at) VALUES ${values};`,
 });
 fixtureIds.push(...historyIds);
 let page=await borrower.api.rentals();const all=[...page.rows];assert.equal(page.rows.length,50);assert.ok(page.nextCursor);
 // Insert while paging: cursor must not duplicate an existing row or skip the old active request.
 const inserted=await borrower.api.requestRental({...input,p_item_version:updated.data.updated_at,p_request_id:randomUUID()});await borrower.api.respondToRental(inserted.id,'cancel');
 while(page.nextCursor){page=await borrower.api.rentals({cursor:page.nextCursor});all.push(...page.rows);}
 assert.equal(new Set(all.map(r=>r.id)).size,all.length);
 for(const id of fixtureIds)assert.ok(all.some(r=>r.id===id));
 let activePage=await borrower.api.rentals({activeOnly:true});const active=[...activePage.rows];
 while(activePage.nextCursor){activePage=await borrower.api.rentals({activeOnly:true,cursor:activePage.nextCursor});active.push(...activePage.rows);}
 assert.ok(active.some(r=>r.id===original.id));assert.ok(active.every(r=>!['cancelled','rejected','expired','settled','resolved'].includes(r.status)));
 assert.ok(!all.some(r=>r.id===inserted.id));
 console.log(JSON.stringify({passed:true,recoveredId:original.id,itemId:item.id,fixtureCount:fixtureIds.length,historyRows:all.length,activeRows:active.length}));
} finally {await Promise.all([lender.client.auth.signOut(),borrower.client.auth.signOut()]);await rm(dir,{recursive:true,force:true});}
