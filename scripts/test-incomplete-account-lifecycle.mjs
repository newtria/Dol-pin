import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createClient} from '@supabase/supabase-js';
import {createServiceApi} from '../packages/api-client/src/services.ts';
import {closeAccountIdentity} from '../supabase/functions/_shared/account-closure.ts';

function adminFixture({prepareError,authError,finishError,missingAuth=false,throwAuth=false}={}){
 const calls=[];
 const admin={
  rpc:async(name,input)=>{calls.push([name,input]);return {error:prepareError??null};},
  auth:{admin:{
   getUserById:async(id)=>{calls.push(['lookup',id]);if(throwAuth)throw new Error('network');return {data:{user:missingAuth?null:{user_metadata:{display_name:'private'}}},error:missingAuth?{status:404}:null};},
   updateUserById:async(id,input)=>{calls.push(['restrict',id,input]);return {error:authError??null};},
   deleteUser:async(id,soft)=>{calls.push(['delete',id,soft]);return {error:null};},
  }},
  from:name=>{assert.equal(name,'account_closures','cleanup must not require a trading profile');return {update:input=>({eq:async(key,id)=>{calls.push(['complete',key,id,input]);return {error:finishError??null};}})};},
 };
 return {admin,calls};
}

test('an Auth-only account closes only after its durable cleanup journal is prepared',async()=>{
 const {admin,calls}=adminFixture();
 assert.deepEqual(await closeAccountIdentity(admin,'new-account'),{status:'closed'});
 assert.deepEqual(calls.map(call=>call[0]),['begin_account_closure','lookup','restrict','delete','complete']);
 assert.deepEqual(calls[0][1],{p_user_id:'new-account'});
 assert.equal(calls[3][2],true,'Auth evidence identifiers must survive soft deletion');
 assert.deepEqual(calls[2][2].user_metadata,{display_name:null});
});

test('open trades or failed preparation never delete the Auth account',async()=>{
 for(const code of ['PCL01','42501','08006']){
  const error={code};const {admin,calls}=adminFixture({prepareError:error});
  await assert.rejects(closeAccountIdentity(admin,'existing-account'),e=>e===error);
  assert.deepEqual(calls.map(call=>call[0]),['begin_account_closure']);
 }
});

test('Auth and completion failures stay pending for the durable worker',async()=>{
 for(const options of [{authError:{status:503}},{throwAuth:true},{finishError:{code:'08006'}}]){
  const {admin,calls}=adminFixture(options);
  assert.deepEqual(await closeAccountIdentity(admin,'new-account'),{status:'pending'});
  if(options.authError||options.throwAuth)assert.ok(!calls.some(call=>call[0]==='complete'));
 }
});

test('cleanup can finish after Auth was already deleted on an earlier attempt',async()=>{
 const {admin,calls}=adminFixture({missingAuth:true});
 assert.deepEqual(await closeAccountIdentity(admin,'new-account'),{status:'closed'});
 assert.deepEqual(calls.map(call=>call[0]),['begin_account_closure','lookup','complete']);
});

test('support and closure never run as an account that replaced their initiating session',async()=>{
 const client={auth:{getSession:async()=>({data:{session:{user:{id:'bob'},access_token:'bob-token'}},error:null})},
  rpc:()=>assert.fail('report must not be sent'),functions:{invoke:()=>assert.fail('closure must not be sent')}};
 const api=createServiceApi(client);
 await assert.rejects(api.closeAccount('alice'),error=>error.code==='AUTH_REQUIRED');
 await assert.rejects(api.report({reason:'other',description:'가입 과정에서 문의합니다.'},'alice'),error=>error.code==='AUTH_REQUIRED');
});

test('support uses the initiating identity token without creating a profile or recording trading consent',async()=>{
 const commands=[];let header;
 const client={auth:{getSession:async()=>({data:{session:{user:{id:'new-account'},access_token:'account-token'}},error:null})},
  rpc:(name,input)=>{commands.push([name,input]);return {setHeader:(key,value)=>{header=[key,value];},then:resolve=>Promise.resolve(resolve({data:null,error:null}))};},
  functions:{invoke:async(name,options)=>{commands.push([name,options]);return {data:{status:'pending'},error:null};}},
 };
 const api=createServiceApi(client);
 await api.report({reason:'other',description:'프로필 없이 남기는 문의입니다.'},'new-account');
 assert.deepEqual(header,['Authorization','Bearer account-token']);
 assert.equal(commands[0][0],'submit_report');
 assert.equal(commands[0][1].p_user_id,null);
 assert.deepEqual(await api.closeAccount('new-account'),{status:'pending'});
 assert.equal(commands[1][0],'account-lifecycle');
 assert.deepEqual(commands[1][1],{body:{action:'close'},headers:{Authorization:'Bearer account-token'}});
 assert.equal(commands.length,2);
});

test('the Supabase transport cannot replace support or closure authorization during its async lookup',async()=>{
 for(const operation of ['report','close']){
  let reads=0,calls=0;
  const client=createClient('https://lifecycle-test.invalid','test-anon-key',{
   auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},
   global:{fetch:async(_url,init)=>{
    calls++;
    assert.equal(new Headers(init.headers).get('Authorization'),'Bearer alice-token');
    return new Response(operation==='close'?JSON.stringify({status:'pending'}):'null',{status:200,headers:{'Content-Type':'application/json'}});
   }},
  });
  client.auth.getSession=async()=>{reads++;const owner=reads===1?'alice':'bob';return {data:{session:{user:{id:owner},access_token:`${owner}-token`}},error:null};};
  const api=createServiceApi(client);
  if(operation==='close')assert.equal((await api.closeAccount('alice')).status,'pending');
  else await api.report({reason:'other',description:'계정 전환과 동시에 접수한 문의입니다.'},'alice');
  assert.equal(calls,1);
  assert.ok(reads>=2,'SDK did not exercise the later session lookup');
 }
});
