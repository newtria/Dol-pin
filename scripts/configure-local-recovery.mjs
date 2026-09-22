import {execFileSync,spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
const workdir=process.env.DOLPIN_QA_SUPABASE_WORKDIR??process.cwd();
const project=/^project_id\s*=\s*"([\w-]+)"/m.exec(readFileSync(resolve(workdir,'supabase/config.toml'),'utf8'))?.[1];
if(!project)throw new Error('Missing local project id');
const s=JSON.parse(execFileSync('supabase',['status','-o','json','--workdir',workdir],{encoding:'utf8',stdio:['ignore','pipe','pipe']}));
if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(s.API_URL))throw new Error('Expected local Supabase');
const endpoint=process.env.DOLPIN_RECOVERY_ENDPOINT??`http://supabase_kong_${project}:8000/functions/v1/rental-recovery`;
const literal=v=>"'"+v.replaceAll("'","''")+"'";
const sql=`DO $configure$
DECLARE existing uuid;
BEGIN
 SELECT id INTO existing FROM vault.secrets WHERE name='dolpin_recovery_url';
 IF existing IS NULL THEN PERFORM vault.create_secret(${literal(endpoint)},'dolpin_recovery_url');
 ELSE PERFORM vault.update_secret(existing,${literal(endpoint)}); END IF;
 SELECT id INTO existing FROM vault.secrets WHERE name='dolpin_recovery_token';
 IF existing IS NULL THEN PERFORM vault.create_secret(${literal(s.SERVICE_ROLE_KEY)},'dolpin_recovery_token');
 ELSE PERFORM vault.update_secret(existing,${literal(s.SERVICE_ROLE_KEY)}); END IF;
PERFORM cron.alter_job(jobid,active:=true) FROM cron.job WHERE jobname='dolpin-reconcile-rentals';
END $configure$;`;
const result=spawnSync('docker',['exec','-i',`supabase_db_${project}`,'psql','-X','-q','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:sql,encoding:'utf8'});
if(result.status!==0)throw new Error('Local recovery configuration failed; check the local database connection.');
console.log('Local recovery endpoint and service token saved in Vault. Start the Edge Functions before checking cron delivery.');
