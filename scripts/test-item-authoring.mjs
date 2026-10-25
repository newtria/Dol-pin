import assert from 'node:assert/strict';
import {test} from 'node:test';
import {createClient} from '@supabase/supabase-js';
import {QueryClient,QueryObserver} from '@tanstack/react-query';
import {createPendingItems,ItemRequestRejected} from '../packages/api-client/src/pending-items.ts';
import {createApi} from '../packages/api-client/src/index.ts';
import {itemEditorQueryPolicy,freshItemForEditor,captureItemEditorSnapshot} from '../packages/api-client/src/item-editor.ts';

const owner='71000000-0000-4000-8000-000000000001';
const other='71000000-0000-4000-8000-000000000002';
const itemId='72000000-0000-4000-8000-000000000001';
const requestId='73000000-0000-4000-8000-000000000001';
const input={title:'응원봉',description:'작동 확인',category:'lightstick',concert_id:null,daily_price:5000,deposit:30000,photos:[`https://storage.invalid/storage/v1/object/public/product-photos/${owner}/photo.jpg`],pickup_method:'direct',pickup_area:'잠실역',pickup_note:'3번 출구',available_from:null,available_to:null};
const request={requestId,input};
function memory(){const data=new Map();return {data,getItem:key=>data.get(key)??null,setItem:(key,value)=>{data.set(key,value);},removeItem:key=>{data.delete(key);}};}

test('reopening an editor never initializes from its old cached price or a failed refresh',async()=>{
 for(const fail of [false,true]){
  const client=new QueryClient({defaultOptions:{queries:{staleTime:15000,retry:false}}});
  const queryKey=['edit-item',itemId,owner],old={id:itemId,daily_price:5000},latest={id:itemId,daily_price:6000};
  client.setQueryData(queryKey,old);let release;
  const waiting=new Promise(resolve=>{release=resolve;});
  const observer=new QueryObserver(client,{queryKey,...itemEditorQueryPolicy,queryFn:async()=>{await waiting;if(fail)throw new Error('offline');return latest;}});
  assert.equal(freshItemForEditor(observer.getCurrentResult()),undefined);
  const finished=new Promise(resolve=>{observer.subscribe(result=>{if(!result.isFetching&&result.isFetchedAfterMount)resolve(result);});});
  assert.equal(freshItemForEditor(observer.getCurrentResult()),undefined);
  release();const result=await finished;
  assert.deepEqual(freshItemForEditor(result),fail?undefined:latest);
  observer.destroy();client.clear();
 }
});

test('lost creation response restores the complete input and replays one server identity after restart',async()=>{
 const storage=memory(),server=new Map();let attempts=0;
 const send=async command=>{
  assert.deepEqual(JSON.parse(storage.data.get(`dolpin-item-request-v1.${owner}`)).input,input);
  if(!server.has(command.requestId))server.set(command.requestId,{id:itemId});
  if(++attempts===1)throw new Error('response lost after commit');
  return server.get(command.requestId);
 };
 await assert.rejects(createPendingItems(storage).submit(owner,request,send));
 const restarted=createPendingItems(storage);
 assert.deepEqual(await restarted.read(owner),request);
 const result=await restarted.submit(owner,{requestId:'73000000-0000-4000-8000-000000000002',input:{...input,daily_price:9000}},send);
 assert.equal(result.id,itemId);assert.equal(server.size,1);
 assert.deepEqual(await restarted.read(owner),{...request,completedItemId:itemId});
 assert.equal(await restarted.read(other),null);
});
test('double clicks join one operation and a later tab reuses its confirmed receipt',async()=>{
 const storage=memory(),journal=createPendingItems(storage);let calls=0,release;
 const waiting=new Promise(resolve=>{release=resolve;});
 const first=journal.submit(owner,request,async()=>{calls++;await waiting;return {id:itemId};});
 const second=journal.submit(owner,{...request,requestId:'73000000-0000-4000-8000-000000000002'},async()=>{throw new Error('must join');});
 release();assert.deepEqual(await second,await first);assert.equal(calls,1);
 const tab=createPendingItems(storage);
 await tab.submit(owner,{...request,requestId:'73000000-0000-4000-8000-000000000003'},async command=>{assert.equal(command.requestId,requestId);return {id:itemId};});
});
test('storage failures never send a new creation and failed receipt storage preserves the retry identity',async()=>{
 let calls=0;
 await assert.rejects(createPendingItems({...memory(),setItem:()=>{throw new Error('disk unavailable');}}).submit(owner,request,async()=>{calls++;return {id:itemId};}));
 assert.equal(calls,0);
 const storage=memory();let writes=0;
 const journal=createPendingItems({...storage,setItem:(key,value)=>{if(++writes===2)throw new Error('receipt unavailable');storage.setItem(key,value);}});
 await assert.rejects(journal.submit(owner,request,async()=>({id:itemId})),/receipt unavailable/);
 assert.deepEqual(await journal.read(owner),request);
});
test('only definitive new-request rejection unlocks editing; unknown outcomes cannot be discarded',async()=>{
 const journal=createPendingItems(memory());
 await assert.rejects(journal.submit(owner,request,async()=>{throw new Error('gateway timeout');}));
 await assert.rejects(journal.startNew(owner,requestId));assert.deepEqual(await journal.read(owner),request);
 await assert.rejects(journal.submit(owner,request,async()=>{throw new ItemRequestRejected('invalid terms','22023');}));
 assert.equal(await journal.read(owner),null);
 const next={...request,requestId:'73000000-0000-4000-8000-000000000002'};
 await journal.submit(owner,next,async()=>({id:itemId}));
 await assert.rejects(journal.submit(owner,next,async()=>{throw new ItemRequestRejected('temporary access failure','42501');}));
 assert.equal((await journal.read(owner)).completedItemId,itemId);
 await journal.startNew(owner,next.requestId);assert.equal(await journal.read(owner),null);
});
test('an old tab cannot revive a retired receipt or clear the next registration',async()=>{
 const storage=memory(),tabA=createPendingItems(storage),tabB=createPendingItems(storage);
 await assert.rejects(tabB.submit(owner,request,async()=>{throw new Error('R1 response lost');}));
 await tabA.submit(owner,request,async()=>({id:itemId}));
 await tabA.startNew(owner,requestId);
 let oldCalls=0;
 await assert.rejects(tabB.submit(owner,request,async()=>{oldCalls++;return {id:itemId};}),error=>error.code==='STATE_CONFLICT'&&error.completedItemId===itemId);
 assert.equal(oldCalls,0);assert.equal(await tabA.read(owner),null);
 const next={...request,requestId:'73000000-0000-4000-8000-000000000002',input:{...input,title:'새로운 물품'}};
 const nextItem='72000000-0000-4000-8000-000000000002';
 await tabA.submit(owner,next,async command=>{assert.deepEqual(command,next);return {id:nextItem};});
 await assert.rejects(tabB.startNew(owner,requestId));
 assert.deepEqual(await tabA.read(owner),{...next,completedItemId:nextItem});
});
test('a delayed old response and old duplicate click cannot overwrite or join a new registration',async()=>{
 const storage=memory(),tabA=createPendingItems(storage),tabB=createPendingItems(storage);let sent,releaseOld,releaseNew;
 const didSend=new Promise(resolve=>{sent=resolve;}),oldResponse=new Promise(resolve=>{releaseOld=resolve;}),newResponse=new Promise(resolve=>{releaseNew=resolve;});
 const old=tabB.submit(owner,request,async()=>{sent();await oldResponse;return {id:itemId};});
 const oldRejected=assert.rejects(old,error=>error.code==='STATE_CONFLICT');
 await didSend;
 await tabA.submit(owner,request,async()=>({id:itemId}));
 await tabA.startNew(owner,requestId);
 const next={...request,requestId:'73000000-0000-4000-8000-000000000002'};
 const nextItem='72000000-0000-4000-8000-000000000002';
 const pending=tabA.submit(owner,next,async()=>{await newResponse;return {id:nextItem};});
 await assert.rejects(tabA.submit(owner,request,async()=>{throw new Error('must not send old request');}),error=>error.code==='STATE_CONFLICT');
 releaseNew();await pending;releaseOld();await oldRejected;
 assert.deepEqual(await tabA.read(owner),{...next,completedItemId:nextItem});
});
test('a failed removal cannot undo the durable retirement fence',async()=>{
 const storage=memory();const journal=createPendingItems({...storage,removeItem:()=>{throw new Error('remove unavailable');}});
 await journal.submit(owner,request,async()=>({id:itemId}));
 await assert.rejects(journal.startNew(owner,requestId),/remove unavailable/);
 const restarted=createPendingItems(storage);
 assert.equal(await restarted.read(owner),null);
 await assert.rejects(restarted.submit(owner,request,async()=>{throw new Error('must not resend');}),error=>error.code==='STATE_CONFLICT');
 const next={...request,requestId:'73000000-0000-4000-8000-000000000002'};
 await restarted.submit(owner,next,async()=>({id:'72000000-0000-4000-8000-000000000002'}));
 assert.equal((await restarted.read(owner)).requestId,next.requestId);
});
test('a corrupted record fails closed without replacing the saved request',async()=>{
 const storage=memory();storage.data.set(`dolpin-item-request-v1.${owner}`,'{"requestId":"invalid"}');
 const journal=createPendingItems(storage);let calls=0;
 await assert.rejects(journal.submit(owner,request,async()=>{calls++;return {id:itemId};}));
 assert.equal(calls,0);assert.equal(storage.data.get(`dolpin-item-request-v1.${owner}`),'{"requestId":"invalid"}');
});

test('creation refuses a changed account before sending its saved input',async()=>{
 let calls=0;
 const api=createApi({auth:{getSession:async()=>({data:{session:{user:{id:other},access_token:'other-token'}},error:null})},rpc:()=>{calls++;throw new Error('must not send');}});
 await assert.rejects(api.createItem(input,requestId,owner),error=>error.code==='AUTH_REQUIRED');assert.equal(calls,0);
});
test('creation pins the journal owner token through the SDK asynchronous auth lookup',async()=>{
 let reads=0;
 const client=createClient('https://item-authoring-test.invalid','test-anon-key',{
  auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},
  global:{fetch:async(url,init)=>{
   assert.match(String(url),/\/rpc\/create_my_item$/);assert.equal(new Headers(init.headers).get('Authorization'),'Bearer owner-token');
   assert.deepEqual(JSON.parse(init.body),{p_request_id:requestId,p_input:input});
   return new Response(JSON.stringify({...input,id:itemId,lender_id:owner,photos:[]}),{status:200,headers:{'Content-Type':'application/json'}});
  }},
 });
 client.auth.getSession=async()=>({data:{session:{user:{id:++reads===1?owner:other},access_token:reads===1?'owner-token':'other-token'}},error:null});
 assert.equal((await createApi(client).createItem(input,requestId,owner)).id,itemId);assert.ok(reads>=2);
});
test('a committed-identity mismatch stays unresolved instead of permitting a duplicate creation',async()=>{
 const api=createApi({auth:{getSession:async()=>({data:{session:{user:{id:owner},access_token:'token'}},error:null})},rpc:()=>({setHeader(){return Promise.resolve({status:400,data:null,error:{code:'PIT01',message:'different payload'}});}})});
 const journal=createPendingItems(memory());
 await assert.rejects(journal.submit(owner,request,command=>api.createItem(command.input,command.requestId,owner)),error=>error.code==='STATE_CONFLICT');
 assert.deepEqual(await journal.read(owner),request);
});

test('form initialization captures its own version and photos independently of later query updates',()=>{
 const version='2026-10-25T04:05:06.123456+00:00';
 const fetched={...input,photos:[...input.photos],updated_at:version};
 const snapshot=captureItemEditorSnapshot(fetched);
 fetched.updated_at='2026-10-25T04:05:07.123456+00:00';fetched.daily_price=9000;fetched.photos.push('https://storage.invalid/new.jpg');
 assert.equal(snapshot.version,version);assert.deepEqual(snapshot.input,input);
 assert.throws(()=>captureItemEditorSnapshot({...fetched,updated_at:null}),error=>error.code==='PIV01');
});
test('editor reads public fields, private instructions and version through one owned snapshot',async()=>{
 const row={...input,photos:[],id:itemId,updated_at:'2026-10-25T04:05:06.123456+00:00'};let calls=0;
 const api=createApi({rpc:async(name,args)=>{calls++;assert.equal(name,'get_my_item');assert.deepEqual(args,{p_item_id:itemId});return {data:row,error:null};}});
 assert.deepEqual(await api.itemForEdit(itemId),row);assert.equal(calls,1);
});
test('editing sends the exact form snapshot version and refuses an unversioned caller',async()=>{
 const version='2026-10-25T04:05:06.123456+00:00';let calls=0;
 const api=createApi({rpc:async(name,args)=>{
  calls++;assert.equal(name,'update_my_item');assert.deepEqual(args,{p_item_id:itemId,p_input:input,p_expected_version:version});
  return {data:{...input,id:itemId,photos:[],updated_at:'2026-10-25T04:05:07.123456+00:00'},error:null};
 }});
 assert.equal((await api.updateItem(itemId,input,version)).id,itemId);
 await assert.rejects(api.updateItem(itemId,input),error=>error.code==='PIV01');
 assert.equal(calls,1);
});
test('an optimistic edit conflict remains a conflict and preserves the submitted input',async()=>{
 const snapshot=captureItemEditorSnapshot({...input,updated_at:'2026-10-25T04:05:06.123456+00:00'});
 const api=createApi({rpc:async()=>({data:null,error:{code:'PIV01',message:'stale version'}})});
 await assert.rejects(api.updateItem(itemId,snapshot.input,snapshot.version),error=>error.code==='PIV01');
 assert.deepEqual(snapshot.input,input);
});
