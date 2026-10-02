import {closeAuthAccount} from './account-closure.ts';
function assert(value:unknown,message:string):asserts value {if(!value)throw new Error(message);}
type Admin=Parameters<typeof closeAuthAccount>[0];

Deno.test('closure removes existing metadata keys before banning and deidentifying Auth',async()=>{
 const calls:string[]=[];
 const admin={auth:{admin:{
  getUserById:()=>Promise.resolve({data:{user:{user_metadata:{nickname:'private',avatar_url:'private'}}},error:null}),
  updateUserById:(_id:string,attributes:{user_metadata:Record<string,unknown>;ban_duration:string})=>{
   calls.push('restrict');
   assert(attributes.user_metadata.nickname===null&&attributes.user_metadata.avatar_url===null,'empty metadata would preserve private fields');
   assert(attributes.ban_duration==='876000h','login not disabled before deletion');
   return Promise.resolve({error:null});
  },
  deleteUser:(_id:string,soft:boolean)=>{calls.push('delete');assert(soft,'Auth references should survive deidentification');return Promise.resolve({error:null});},
 }}} as unknown as Admin;
 assert(await closeAuthAccount(admin,'user'),'successful closure not acknowledged');
 assert(calls.join(',')==='restrict,delete','Auth closure order changed');
});
Deno.test('closure retries a missing Auth user as success, and preserves pending status on API failure',async()=>{
 const absent={auth:{admin:{getUserById:()=>Promise.resolve({data:{user:null},error:{code:'user_not_found',status:404}})}}} as unknown as Admin;
 assert(await closeAuthAccount(absent,'missing'),'idempotent deletion retry failed');
 let deleted=false;
 const unavailable={auth:{admin:{
  getUserById:()=>Promise.resolve({data:{user:{user_metadata:{nickname:'private'}}},error:null}),
  updateUserById:()=>Promise.resolve({error:{status:503}}),
  deleteUser:()=>{deleted=true;return Promise.resolve({error:null});},
 }}} as unknown as Admin;
 assert(!await closeAuthAccount(unavailable,'user'),'partial cleanup incorrectly acknowledged');
 assert(!deleted,'deletion ran before metadata cleanup succeeded');
});
