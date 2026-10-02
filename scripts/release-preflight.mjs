#!/usr/bin/env node
import {existsSync,readFileSync} from 'node:fs';
import {dirname,join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const structureOnly=process.argv.includes('--structure-only');
const failures=[];
function envFile(path){
 if(!existsSync(join(root,path)))return {};
 return Object.fromEntries(readFileSync(join(root,path),'utf8').split(/\r?\n/).flatMap(line=>{
  const match=/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/.exec(line);
  return match?[[match[1],match[2].replace(/^(['"])(.*)\1$/,'$2')]]:[];
 }));
}
const requiredFiles=[
 'apps/mobile/app.config.ts','apps/mobile/eas.json','apps/web/app/operations/page.tsx',
 'packages/api-client/src/finance.ts','packages/api-client/src/services.ts',
 'supabase/migrations/042_commercial_finance.sql','supabase/migrations/043_commercial_services.sql',
 'supabase/migrations/046_operations_health.sql',
 '.github/workflows/deploy-backend.yml','.github/workflows/operations-watchdog.yml',
 'scripts/deploy-backend.mjs','scripts/check-release-ci.mjs','scripts/operations-watchdog.mjs',
 ...['toss-payment','rental-payment','rental-recovery','finance-ops','service-ops','service-delivery','account-lifecycle'].map(name=>`supabase/functions/${name}/index.ts`),
 'scripts/qa/commercial_finance_test.ts','scripts/qa/services_test.ts',
];
for(const path of requiredFiles)if(!existsSync(join(root,path)))failures.push(`Missing source: ${path}`);
function present(env,key){
 const value=env[key]?.trim();
 if(!value||/your-|replace_me|placeholder|change-me|example\./i.test(value)){failures.push(`Configure ${key}`);return null;}
 return value;
}
function https(env,key){const value=present(env,key);if(value){try{const url=new URL(value);if(url.protocol!=='https:'||url.username||url.password||/^(localhost|127\.|0\.0\.0\.0)/.test(url.hostname))throw Error();}catch{failures.push(`Production HTTPS URL required: ${key}`);}}}
function publicKey(env,key){
 const value=present(env,key);if(!value)return;
 if(value.startsWith('sb_publishable_'))return;
 try{const claims=JSON.parse(Buffer.from(value.split('.')[1],'base64url').toString('utf8'));if(claims.role!=='anon')throw Error();}
 catch{failures.push(`A public Supabase key is required: ${key}`);}
}
if(!structureOnly){
 const edge={...envFile('.env'),...envFile('supabase/functions/.env'),...process.env};
 const mobile={...envFile('apps/mobile/.env.local'),...process.env};
 const web={...envFile('apps/web/.env.local'),...process.env};
 for(const key of ['SUPABASE_URL','DOLPIN_WEB_URL','OPS_ALERT_WEBHOOK_URL'])https(edge,key);
 for(const key of ['SUPABASE_SERVICE_ROLE_KEY','TOSS_SECRET_KEY','SERVICE_DELIVERY_TOKEN'])present(edge,key);
 if(!edge.TOSS_SECRET_KEY?.startsWith('live_sk_'))failures.push('Production Toss API secret key required');
 if((edge.SERVICE_DELIVERY_TOKEN?.length??0)<32)failures.push('SERVICE_DELIVERY_TOKEN must have at least 32 characters');
 for(const key of ['EXPO_PUBLIC_SUPABASE_URL','EXPO_PUBLIC_TERMS_URL','EXPO_PUBLIC_PRIVACY_URL'])https(mobile,key);
 for(const key of ['EXPO_PUBLIC_SUPABASE_ANON_KEY','EXPO_PUBLIC_EAS_PROJECT_ID','DOLPIN_IOS_BUNDLE_IDENTIFIER','DOLPIN_ANDROID_PACKAGE'])present(mobile,key);
 for(const key of ['DOLPIN_IOS_BUNDLE_IDENTIFIER','DOLPIN_ANDROID_PACKAGE'])if(mobile[key]?.includes('preview'))failures.push(`Preview identifier cannot ship: ${key}`);
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(mobile.EXPO_PUBLIC_EAS_PROJECT_ID??''))failures.push('Valid EAS project UUID required');
 for(const key of ['NEXT_PUBLIC_SUPABASE_URL','NEXT_PUBLIC_TERMS_URL','NEXT_PUBLIC_PRIVACY_URL'])https(web,key);
 for(const key of ['NEXT_PUBLIC_SUPABASE_ANON_KEY','NEXT_PUBLIC_TOSS_CLIENT_KEY'])present(web,key);
 if(!web.NEXT_PUBLIC_TOSS_CLIENT_KEY?.startsWith('live_ck_'))failures.push('Production Toss API client key required');
 publicKey(mobile,'EXPO_PUBLIC_SUPABASE_ANON_KEY');
 publicKey(web,'NEXT_PUBLIC_SUPABASE_ANON_KEY');
 const origins=[edge.SUPABASE_URL,mobile.EXPO_PUBLIC_SUPABASE_URL,web.NEXT_PUBLIC_SUPABASE_URL].map(value=>value?.replace(/\/$/,''));
 if(new Set(origins).size!==1)failures.push('Server, mobile and web must target the same Supabase project');
 if(edge.DOLPIN_ENABLE_LEGACY_PAYMENTS==='true')for(const key of ['PORTONE_IMP_KEY','PORTONE_IMP_SECRET'])present(edge,key);
}
if(failures.length){for(const failure of failures)console.error(failure);process.exitCode=1;}
else console.log(structureOnly?'Release source structure is present; runtime and deployment are unverified.':'Release configuration is present; payment, delivery and native runtime still require verification.');
