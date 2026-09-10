import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {createClient} from '@supabase/supabase-js';

const env=Object.fromEntries(readFileSync('apps/mobile/.env.local','utf8').trim().split('\n').map(l=>{const i=l.indexOf('=');return [l.slice(0,i),l.slice(i+1)];}));
const url=env.EXPO_PUBLIC_SUPABASE_URL;
assert.match(url,/^http:\/\/127\.0\.0\.1:\d+$/,'Local fixtures only');
const mailUrl=new URL(url);mailUrl.port=String(Number(mailUrl.port)+3);
const email=`email-qa-${randomUUID().slice(0,8)}@example.test`, password=`Qa-${randomUUID()}!`;
const makeClient=()=>createClient(url,env.EXPO_PUBLIC_SUPABASE_ANON_KEY,{auth:{persistSession:false,autoRefreshToken:false,flowType:'pkce'}});
const client=makeClient();
const signup=await client.auth.signUp({email,password,options:{emailRedirectTo:'dolpin://auth/callback'}});
assert.ifError(signup.error);assert.equal(signup.data.session,null,'Enable email confirmations for this test');
const unconfirmed=await client.auth.signInWithPassword({email,password});assert.equal(unconfirmed.error?.code,'email_not_confirmed');
let message;
for(let attempt=0;attempt<15;attempt++){
 const search=await fetch(`${mailUrl.origin}/api/v1/search?query=${encodeURIComponent('to:'+email)}`).then(r=>r.json());
 if(search.messages?.length){message=await fetch(`${mailUrl.origin}/api/v1/message/${search.messages[0].ID}`).then(r=>r.json());break;}
 await new Promise(r=>setTimeout(r,1000));
}
assert.ok(message,'Local confirmation email must arrive');
const html=message.HTML??'';
const link=html.match(/href="([^"]*\/auth\/v1\/verify[^\"]*)"/)?.[1]?.replaceAll('&amp;','&');
assert.ok(link,'Confirmation link must exist');
assert.equal(new URL(link).origin,url,'Never follow an external mail link');
const verified=await fetch(link,{redirect:'manual'});
const location=verified.headers.get('location');assert.ok(location?.startsWith('dolpin://auth/callback'));
const code=new URL(location).searchParams.get('code');assert.ok(code,'PKCE callback must contain a code');
const exchanged=await client.auth.exchangeCodeForSession(code);assert.ifError(exchanged.error);assert.ok(exchanged.data.user.email_confirmed_at);
const profile=await client.rpc('ensure_profile',{p_nickname:'이메일 가입 QA'});assert.ifError(profile.error);
assert.ifError((await client.auth.signOut()).error);
assert.equal((await client.auth.getSession()).data.session,null);
const fresh=makeClient();
assert.equal((await fresh.auth.signInWithPassword({email,password:'wrong-password'})).error?.code,'invalid_credentials');
const login=await fresh.auth.signInWithPassword({email,password});assert.ifError(login.error);assert.equal(login.data.user.id,signup.data.user.id);
assert.ifError((await fresh.auth.signOut()).error);
console.log('Email signup, unconfirmed rejection, local mail confirmation, PKCE callback, profile creation, wrong password and fresh-session login passed.');
