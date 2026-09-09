import assert from 'node:assert/strict';
import {test} from 'node:test';
import {mkdtemp,readFile,writeFile,unlink,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createPendingRentals,RentalRequestRejected} from '../packages/api-client/src/pending-rentals.ts';

const input={p_item_id:'item',p_request_id:'original-id',p_starts_at:'2026-10-01T01:00:00Z',p_ends_at:'2026-10-01T09:00:00Z',p_item_version:'original-version'};

test('lost response survives a fresh journal and replays the original version and identity',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'dolpin-recovery-'));
 const storage={getItem:async key=>readFile(join(dir,key),'utf8').catch(e=>{if(e.code==='ENOENT')return null;throw e;}),setItem:(key,value)=>writeFile(join(dir,key),value),removeItem:key=>unlink(join(dir,key))};
 try {
  const first=createPendingRentals(storage);
  let serverRequests=0;
  await assert.rejects(first.submit('alice',input,async request=>{
   assert.deepEqual(await first.read('alice','item'),request,'must persist before sending');
   serverRequests++;throw new Error('response lost after commit');
  }));
  const restarted=createPendingRentals(storage);
  assert.deepEqual(await restarted.read('alice','item'),input);
  assert.equal(await restarted.read('bob','item'),null,'accounts must not share recovery requests');
  const result=await restarted.submit('alice',{...input,p_request_id:'new-id',p_item_version:'updated-version'},async request=>{
   assert.deepEqual(request,input);return {id:'same-server-reservation'};
  });
  assert.equal(result.id,'same-server-reservation');assert.equal(serverRequests,1);
  assert.equal(await restarted.read('alice','item'),null);
 } finally {await rm(dir,{recursive:true,force:true});}
});

test('storage failure prevents server submission',async()=>{
 let calls=0;
 const journal=createPendingRentals({getItem:()=>null,setItem:()=>{throw new Error('disk unavailable');},removeItem:()=>{}});
 await assert.rejects(journal.submit('alice',input,async()=>{calls++;}),/disk unavailable/);
 assert.equal(calls,0);
});

test('definitive rejection unlocks editing; ambiguous failures retain recovery',async()=>{
 const data=new Map();
 const journal=createPendingRentals({getItem:key=>data.get(key)??null,setItem:(key,value)=>{data.set(key,value);},removeItem:key=>{data.delete(key);}});
 await assert.rejects(journal.submit('alice',input,async()=>{throw new Error('gateway timeout');}));
 assert.deepEqual(await journal.read('alice','item'),input);
 await assert.rejects(journal.submit('alice',input,async()=>{throw new RentalRequestRejected('changed item');}));
 assert.equal(await journal.read('alice','item'),null);
});
