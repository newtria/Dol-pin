import {readFileSync,writeFileSync,existsSync} from 'node:fs';
// Only local provider enablement is changed; secrets remain env references.
if(existsSync('.env')) process.loadEnvFile('.env');
let config=readFileSync('supabase/config.toml','utf8');
for(const provider of ['google','apple','kakao']) {
 const prefix=provider.toUpperCase();
 const id=process.env[`${prefix}_CLIENT_ID`]; const secret=process.env[`${prefix}_CLIENT_SECRET`];
 if(Boolean(id)!==Boolean(secret)) throw new Error(`${prefix}_CLIENT_ID and ${prefix}_CLIENT_SECRET must both be set.`);
 config=config.replace(new RegExp(`(\\[auth.external.${provider}\\]\\s+enabled = )[^\\n]+`),`$1${Boolean(id&&secret)} # scripts/configure-oauth.mjs`);
 console.log(`${provider}: ${id&&secret?'enabled':'disabled'}`);
}
writeFileSync('supabase/config.toml',config);
