import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {chmodSync,copyFileSync,existsSync,mkdirSync,mkdtempSync,readFileSync,rmSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname,join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const source=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const env={...process.env,GIT_CONFIG_GLOBAL:'/dev/null',GIT_CONFIG_NOSYSTEM:'1',GIT_TERMINAL_PROMPT:'0'};
function fixture(t) {
 const folder=mkdtempSync(join(tmpdir(),'dolpin-public-check-'));const cwd=join(folder,'checkout');mkdirSync(cwd);
 t.after(()=>rmSync(folder,{recursive:true,force:true}));
 const run=(command,args,options={})=>spawnSync(command,args,{cwd,env,encoding:'utf8',...options});
 const git=(...args)=>{const r=run('git',args);assert.equal(r.status,0,r.stderr);return r.stdout.trim();};
 const write=(path,value)=>{mkdirSync(dirname(join(cwd,path)),{recursive:true});writeFileSync(join(cwd,path),value);};
 const commit=message=>git('-c','core.hooksPath=/dev/null','commit','-qm',message);
 git('init','-q');git('config','user.name','Public check fixture');git('config','user.email','fixture@example.invalid');
 copyFileSync(join(source,'.gitignore'),join(cwd,'.gitignore'));
 write('README.md','# Public setup\n');write('app.js','export const ready = true;\n');
 git('add','.');commit('Initial public source');
 const base=git('rev-parse','HEAD');
 const check=(args=[],input)=>run(process.execPath,[join(source,'scripts/check-public-files.mjs'),...args],{input});
 return {folder,cwd,run,git,write,commit,base,check};
}

test('published README and templates pass while local notes stay untracked',t=>{
 const f=fixture(t);f.write('apps/web/.env.example','NEXT_PUBLIC_SUPABASE_URL=https://example.invalid\n');
 f.write('notes/research.md','Local working notes');f.write('session.jsonl.zst','Local transcript');
 f.git('add','apps/web/.env.example');f.commit('Add a public configuration template');
 const r=f.check(['--base',f.base]);assert.equal(r.status,0,r.stderr);
 assert.ok(existsSync(join(f.cwd,'notes/research.md')));
 assert.equal(f.git('ls-files','notes/research.md','session.jsonl.zst'),'');
});

test('force-added research, plans and local credentials are blocked without printing their content',t=>{
 const f=fixture(t);
 for(const path of ['scenarios/research.md','dolda_기획서.md','dol-da_기획서.pdf','apps/web/.env.local','session.jsonl']) {
  f.write(path,'sensitive-fixture-value');f.git('add','-f','--',path);
 }
 const r=f.check();assert.equal(r.status,1);
 assert.match(r.stderr,/scenarios\/research\.md/);assert.match(r.stderr,/dolda_기획서\.md/);
 assert.match(r.stderr,/\.env\.local/);assert.doesNotMatch(r.stderr,/sensitive-fixture-value/);
});

test('a research file added and deleted in unpublished commits is still blocked',t=>{
 const f=fixture(t);f.write('docs/research.md','Working notes');f.git('add','-f','docs/research.md');f.commit('Add internal notes');
 f.git('rm','docs/research.md');f.commit('Delete internal notes');
 assert.equal(f.git('status','--porcelain'),'');
 const r=f.check(['--base',f.base]);assert.equal(r.status,1);assert.match(r.stderr,/docs\/research\.md/);
});

test('removing an already published file preserves its local copy and does not block the cleanup',t=>{
 const f=fixture(t);f.write('scenarios/old.md','Already published');f.git('add','-f','scenarios/old.md');f.commit('Historical publication');
 const published=f.git('rev-parse','HEAD');f.git('rm','--cached','scenarios/old.md');f.commit('Stop tracking working material');
 assert.equal(f.check(['--base',published]).status,0);
 assert.equal(readFileSync(join(f.cwd,'scenarios/old.md'),'utf8'),'Already published');
});

test('the actual pre-push hook rejects leaked history for existing and new remote branches',t=>{
 const f=fixture(t);
 for(const path of ['.githooks/pre-push','scripts/check-public-files.mjs']) {
  f.write(path,readFileSync(join(source,path)));if(path.startsWith('.githooks/'))chmodSync(join(f.cwd,path),0o755);
 }
 f.git('add','.githooks','scripts');f.commit('Install public guard source');
 const published=f.git('rev-parse','HEAD');const remote=join(f.folder,'remote.git');f.git('init','--bare','-q',remote);
 f.git('remote','add','origin',remote);f.git('push','-q','origin','HEAD:refs/heads/main');
 f.git('config','core.hooksPath','.githooks');
 f.write('reports/private.md','Internal report');f.git('add','-f','reports/private.md');f.commit('Internal report');
 f.git('rm','reports/private.md');f.commit('Remove report');
 for(const branch of ['main','new-branch']) {
  const r=f.run('git',['push','origin',`HEAD:refs/heads/${branch}`]);assert.notEqual(r.status,0);assert.match(r.stderr,/reports\/private\.md/);
 }
 assert.equal(f.git('--git-dir',remote,'rev-parse','refs/heads/main'),published);
 assert.equal(f.git('--git-dir',remote,'for-each-ref','--format=%(refname)','refs/heads/new-branch'),'');
});

test('pushing another branch or annotated tag checks its tree even with no unpublished commits',t=>{
 const f=fixture(t);f.write('private.md','Historical working material');f.git('add','-f','private.md');f.commit('Historical publication');
 const old=f.git('rev-parse','HEAD');f.git('tag','-a','old-tag','-m','Historical tag');
 const tag=f.git('rev-parse','old-tag');f.git('rm','private.md');f.commit('Clean current branch');
 f.git('update-ref','refs/remotes/origin/main','HEAD');
 for(const head of [old,tag]) {
  const result=f.check(['--pre-push','origin','unused'],`refs/heads/other ${head} refs/heads/other ${'0'.repeat(40)}\n`);
  assert.equal(result.status,1);assert.match(result.stderr,/pushed tree.*private\.md/);
 }
});

test('unrelated staged material does not block a clean outgoing ref',t=>{
 const f=fixture(t);f.write('private.md','Uncommitted notes');f.git('add','-f','private.md');
 const result=f.check(['--pre-push','origin','unused'],`refs/heads/main ${f.base} refs/heads/main ${f.base}\n`);
 assert.equal(result.status,0,result.stderr);
 assert.equal(f.check().status,1);
});

test('an explicit CI base checks deleted material in detached history, including a new remote',t=>{
 const f=fixture(t);f.write('notes/private.md','Working material');f.git('add','-f','notes/private.md');f.commit('Add notes');
 f.git('rm','notes/private.md');f.commit('Remove notes');f.git('checkout','--detach','-q');
 for(const base of [f.base,'0'.repeat(40)]) {
  const result=f.check(['--base',base]);assert.equal(result.status,1);assert.match(result.stderr,/notes\/private\.md/);
 }
});

test('hook setup supports a fresh clone and preserves an existing hook configuration',t=>{
 const f=fixture(t);const path='scripts/install-git-hooks.mjs';f.write(path,readFileSync(join(source,path)));
 let result=f.run(process.execPath,[path]);assert.equal(result.status,0,result.stderr);
 assert.equal(f.git('config','--get','core.hooksPath'),'.githooks');
 f.git('config','core.hooksPath','custom-hooks');result=f.run(process.execPath,[path]);
 assert.equal(result.status,0,result.stderr);assert.equal(f.git('config','--get','core.hooksPath'),'custom-hooks');
 assert.match(result.stderr,/Existing Git hooks preserved/);
});

test('unknown remote base fails closed and deleting a remote ref needs no commit scan',t=>{
 const f=fixture(t);const zero='0'.repeat(40),unknown='1'.repeat(40);
 const blocked=f.check(['--pre-push','origin','unused'],`refs/heads/main ${f.base} refs/heads/main ${unknown}\n`);
 assert.equal(blocked.status,1);assert.match(blocked.stderr,/Fetch the target remote/);
 const deletion=f.check(['--pre-push','origin','unused'],`(delete) ${zero} refs/heads/old ${unknown}\n`);
 assert.equal(deletion.status,0,deletion.stderr);
});
