import assert from 'node:assert/strict';
import {test} from 'node:test';
import {mkdtemp,readFile,writeFile,unlink,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createPendingRentals,RentalRequestRejected} from '../packages/api-client/src/pending-rentals.ts';
import {errorMessage} from '../packages/api-client/src/errors.ts';
import {recoverCheckout} from '../apps/web/lib/checkout-recovery.ts';

const itemId='26000000-0000-4000-8000-000000000001';
const nextRequestId='36000000-0000-4000-8000-000000000002';
const journalKey=`dolpin-rental-request-v1.alice.${itemId}`;
const input={p_item_id:itemId,p_request_id:'36000000-0000-4000-8000-000000000001',p_starts_at:'2026-10-01T01:00:00Z',p_ends_at:'2026-10-01T09:00:00Z',p_item_version:'2026-09-22T01:00:00.123456+00:00'};

test('lost response survives a fresh journal and replays the original version and identity',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'dolpin-recovery-'));
 const storage={getItem:async key=>readFile(join(dir,key),'utf8').catch(e=>{if(e.code==='ENOENT')return null;throw e;}),setItem:(key,value)=>writeFile(join(dir,key),value),removeItem:key=>unlink(join(dir,key))};
 try {
  const first=createPendingRentals(storage);
  let serverRequests=0;
  await assert.rejects(first.submit('alice',input,async request=>{
   assert.deepEqual(await first.read('alice',itemId),request,'must persist before sending');
   serverRequests++;throw new Error('response lost after commit');
  }));
  const restarted=createPendingRentals(storage);
  assert.deepEqual(await restarted.read('alice',itemId),input);
  assert.equal(await restarted.read('bob',itemId),null,'accounts must not share recovery requests');
  const result=await restarted.submit('alice',{...input,p_request_id:nextRequestId,p_item_version:'2026-09-23T01:00:00.654321+00:00'},async request=>{
   assert.deepEqual(request,input);return {id:'same-server-reservation'};
  });
  assert.equal(result.id,'same-server-reservation');assert.equal(serverRequests,1);
  assert.equal(await restarted.read('alice',itemId),null);
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
 assert.deepEqual(await journal.read('alice',itemId),input);
 await assert.rejects(journal.submit('alice',input,async()=>{throw new RentalRequestRejected('changed item');}));
 assert.equal(await journal.read('alice',itemId),null);
});

test('definitive reservation errors retain actionable codes after journal cleanup',async()=>{
 for(const code of ['PCN01','P4290','23P01']) {
  const storage=memoryStorage(),journal=createPendingRentals(storage);
  const failure=new RentalRequestRejected('private SQL details',code);
  await assert.rejects(journal.submit('alice',input,async()=>{throw failure;}),error=>{
   assert.equal(error.code,code);
   assert.equal(errorMessage(error),errorMessage({code}));
   assert.doesNotMatch(errorMessage(error),/private|SQL/);
   return true;
  });
  assert.equal(await journal.read('alice',itemId),null);
 }
});

test('checkout retries confirmation after an occupied lease, transient failure and lost response',async()=>{
 const confirmation={paymentKey:'payment-key',amount:35000},commands=[];
 let attempts=0,paid=false;
 const call=async command=>{
  commands.push(command);
  if(command.action==='status')return {status:paid?'paid':'processing',recoveryState:'processing',nextRetryAt:null};
  assert.deepEqual(command,{action:'confirm',...confirmation});
  attempts++;
  if(attempts===1)return {status:'processing'}; // A worker still owns the lease.
  if(attempts===2)throw new Error('provider lookup unavailable');
  paid=true;throw new Error('confirmation response lost');
 };
 assert.equal((await recoverCheckout(call,confirmation)).status,'processing');
 await assert.rejects(recoverCheckout(call,confirmation),/lookup unavailable/);
 await assert.rejects(recoverCheckout(call,confirmation),/response lost/);
 assert.equal((await recoverCheckout(call,confirmation)).status,'paid');
 assert.deepEqual(commands.map(command=>command.action),['status','confirm','status','confirm','status','confirm','status']);
});

test('checkout leaves retry eligibility to the server and stops at review or a terminal state',async()=>{
 const confirmation={paymentKey:'payment-key',amount:35000};
 const nextRetryAt='2099-10-01T01:01:00Z';
 let confirms=0,serverAllowsApproval=false,result={status:'processing',recoveryState:'retry_scheduled',nextRetryAt};
 const call=async command=>{if(command.action==='status')return result;confirms++;return {status:serverAllowsApproval?'paid':'processing'};};
 assert.equal((await recoverCheckout(call,confirmation)).nextRetryAt,nextRetryAt);
 assert.equal(confirms,1);
 serverAllowsApproval=true;
 assert.equal((await recoverCheckout(call,confirmation)).status,'paid');
 assert.equal(confirms,2,'the same future lookup interval must not starve an eligible approval');
 for(const status of ['paid','expired','cancelled','rejected','settled','unavailable']) {
  result={status};await recoverCheckout(call,confirmation);
 }
 result={status:'processing',recoveryState:'needs_review'};
 await recoverCheckout(call,confirmation);
 assert.equal(confirms,2);
 result={status:'processing',recoveryState:'processing',nextRetryAt:null};
 await recoverCheckout(call,null);
 assert.equal(confirms,2,'a restored link without a payment key only reads status');
 await recoverCheckout(call,confirmation,()=>false);
 assert.equal(confirms,2,'leaving or hiding the page while status loads must not start approval');
});

function memoryStorage() {
 const data=new Map();
 return {data,getItem:key=>data.get(key)??null,setItem:(key,value)=>{data.set(key,value);},removeItem:key=>{data.delete(key);}};
}

function deferred() {
 let resolve;
 const promise=new Promise(done=>{resolve=done;});
 return {promise,resolve};
}

test('concurrent clicks share the original request even when the response succeeds',async()=>{
 const storage=memoryStorage();const journal=createPendingRentals(storage);
 const started=deferred();const response=deferred();const received=[];
 const send=async request=>{received.push(request.p_request_id);started.resolve();await response.promise;return {id:'reservation'};};
 const first=journal.submit('alice',input,send);
 await started.promise;
 const second=journal.submit('alice',{...input,p_request_id:nextRequestId},send);
 response.resolve();
 assert.deepEqual(await Promise.all([first,second]),[{id:'reservation'},{id:'reservation'}]);
 assert.deepEqual(received,[input.p_request_id],'the second click must not queue a fresh request after journal removal');
 assert.equal(await journal.read('alice',itemId),null);
});

test('a cross-context lock blocks competing submissions and preserves a lost response for retry',async()=>{
 const storage=memoryStorage();const locks=new Set();
 storage.runExclusive=async(key,work)=>{
  if(locks.has(key))throw Object.assign(new Error('another context is submitting'),{code:'RENTAL_REQUEST_IN_PROGRESS'});
  locks.add(key);try{return await work();}finally{locks.delete(key);}
 };
 const firstTab=createPendingRentals(storage);const secondTab=createPendingRentals(storage);
 const started=deferred();const response=deferred();let requests=0;
 const first=firstTab.submit('alice',input,async()=>{requests++;started.resolve();await response.promise;throw new Error('response lost');});
 const firstRejected=assert.rejects(first,/response lost/);
 await started.promise;
 await assert.rejects(secondTab.submit('alice',{...input,p_request_id:nextRequestId},async()=>{requests++;}),{code:'RENTAL_REQUEST_IN_PROGRESS'});
 response.resolve();await firstRejected;
 assert.equal(requests,1);
 const recovered=await secondTab.submit('alice',{...input,p_request_id:nextRequestId},async request=>request.p_request_id);
 assert.equal(recovered,input.p_request_id);
 assert.equal(await secondTab.read('alice',itemId),null);
});

test('completion and rejection cannot remove a different request written by an older client',async()=>{
 for(const rejected of [false,true]) {
  const storage=memoryStorage();const journal=createPendingRentals(storage);
  const replacement={...input,p_request_id:nextRequestId};
  const operation=journal.submit('alice',input,async()=>{
   storage.setItem(journalKey,JSON.stringify(replacement));
   if(rejected)throw new RentalRequestRejected('rejected');
   return {id:'reservation'};
  });
  if(rejected)await assert.rejects(operation,RentalRequestRejected);else await operation;
  assert.deepEqual(await journal.read('alice',itemId),replacement);
 }
});

test('corrupt journals are reported and retained without sending a new identity',async()=>{
 const invalid=[
  {p_request_id:''},{p_request_id:'not-a-uuid'},{p_item_id:'not-a-uuid'},
  {p_item_id:'26000000-0000-4000-8000-000000000002'},
  {p_item_version:'invalid-version'},{p_item_version:'infinity'},
  {p_starts_at:'2026-02-30T01:00:00Z'},{p_starts_at:'2026-10-01'},
  {p_ends_at:'2026-10-01T25:00:00Z'},{p_ends_at:'2026-10-01T09:00:00'},
  {p_ends_at:input.p_starts_at},{p_ends_at:'2026-09-30T01:00:00Z'},
 ];
 for(const raw of ['', '{broken', 'null', '[]', ...invalid.map(fields=>JSON.stringify({...input,...fields}))]) {
  const storage=memoryStorage();storage.setItem(journalKey,raw);
  const journal=createPendingRentals(storage);let requests=0;
  await assert.rejects(journal.read('alice',itemId),{code:'RENTAL_REQUEST_STORAGE_CORRUPT'});
  await assert.rejects(journal.submit('alice',input,async()=>{requests++;}),{code:'RENTAL_REQUEST_STORAGE_CORRUPT'});
  assert.equal(requests,0);assert.equal(storage.getItem(journalKey),raw);
 }
});

test('invalid new input never creates a journal or contacts the server',async()=>{
 const storage=memoryStorage();const journal=createPendingRentals(storage);let requests=0;
 await assert.rejects(journal.submit('alice',{...input,p_request_id:'invalid'},async()=>{requests++;}),{code:'RENTAL_REQUEST_STORAGE_CORRUPT'});
 assert.equal(requests,0);assert.equal(storage.getItem(journalKey),null);
});
