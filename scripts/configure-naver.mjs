import {existsSync} from 'node:fs';
import {createClient} from '@supabase/supabase-js';
if(existsSync('.env')) process.loadEnvFile('.env');
for(const name of ['SUPABASE_URL','SUPABASE_SERVICE_ROLE_KEY','NAVER_CLIENT_ID','NAVER_CLIENT_SECRET']) {
 if(!process.env[name]) throw new Error(`Set ${name} in .env first.`);
}
const client=createClient(process.env.SUPABASE_URL,process.env.SUPABASE_SERVICE_ROLE_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
const identifier='custom:naver';
const settings={name:'Naver',client_id:process.env.NAVER_CLIENT_ID,client_secret:process.env.NAVER_CLIENT_SECRET,
 issuer:'https://nid.naver.com',scopes:['openid','profile'],pkce_enabled:true,email_optional:true,enabled:true};
const api=client.auth.admin.customProviders;
const existing=await api.getProvider(identifier);
if(existing.error && existing.error.code!=='custom_provider_not_found' && existing.error.status!==404) throw new Error('Could not read custom providers. Check the target URL, server key, and Auth version.');
const result=existing.data
 ? await api.updateProvider(identifier,settings)
 : await api.createProvider({provider_type:'oidc',identifier,...settings});
if(result.error) throw new Error(`Naver configuration failed: ${result.error.code ?? result.error.status}`);
console.log('Naver OIDC configured. Register the callback URL shown in Supabase Auth with Naver Developers.');
