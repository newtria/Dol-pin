#!/usr/bin/env node
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';

function git(args,{input,allowMissing=false}={}) {
 const result=spawnSync('git',args,{encoding:'utf8',input,maxBuffer:32*1024*1024});
 if(result.error)throw result.error;
 if(result.status!==0&&!(allowMissing&&result.status===1))throw new Error(result.stderr.trim()||`Git exited ${result.status}`);
 return result.stdout;
}
const split=value=>value.split('\0').filter(Boolean);
const lines=value=>value.trim().split('\n').filter(Boolean);
const isOid=value=>/^(?:[0-9a-f]{40}|[0-9a-f]{64})$/i.test(value);
const isZero=value=>/^0+$/.test(value);
function commitsSince(head,bases) {
 git(['rev-parse','--verify',`${head}^{commit}`]);
 for(const base of bases)git(['rev-parse','--verify',`${base}^{commit}`]);
 return lines(git(['rev-list',head,...(bases.length?['--not',...bases]:[])]));
}
function ignored(paths) {
 if(!paths.length)return [];
 return split(git(['check-ignore','--no-index','--stdin','-z'],{input:paths.join('\0')+'\0',allowMissing:true}));
}

try {
 const args=process.argv.slice(2);const commits=new Set();const heads=new Set();
 const prePush=args[0]==='--pre-push';
 if(prePush) {
  const remote=args[1];
  for(const line of lines(readFileSync(0,'utf8'))) {
   const fields=line.split(/\s+/);if(fields.length!==4||!isOid(fields[1])||!isOid(fields[3]))throw new Error('Invalid pre-push reference input');
   const [,head,,base]=fields;if(isZero(head))continue;
   heads.add(head);
   // A new branch may include commits already on this same remote. Never use
   // another remote's history as evidence that material is already public.
   const bases=!isZero(base)?[base]:/^[a-z0-9_.-]+$/i.test(remote??'')
    ?lines(git(['for-each-ref','--format=%(objectname)',`refs/remotes/${remote}/`])):[];
   for(const commit of commitsSince(head,bases))commits.add(commit);
  }
 } else if(args.length===2&&args[0]==='--base') {
  for(const commit of commitsSince('HEAD',isOid(args[1])&&isZero(args[1])?[]:[args[1]]))commits.add(commit);
 } else if(args.length===0) {
  const upstream=spawnSync('git',['rev-parse','--verify','@{upstream}'],{encoding:'utf8'});
  if(upstream.status===0)for(const commit of commitsSince('HEAD',[upstream.stdout.trim()]))commits.add(commit);
 } else throw new Error('Usage: check-public-files.mjs [--base REF | --pre-push REMOTE URL]');

 const blocked=new Map();
 if(!prePush)for(const path of split(git(['ls-files','-ci','--exclude-standard','-z'])))blocked.set(path,'tracked/index');
 // Git can push a branch or tag other than the checked-out branch. Validate
 // each destination tree even when all of its commits are already published.
 for(const head of heads) {
  const paths=split(git(['ls-tree','-r','--name-only','-z',`${head}^{commit}`]));
  for(const path of ignored(paths))blocked.set(path,`pushed tree ${head.slice(0,12)}`);
 }
 for(const commit of commits) {
  // Inspect every introduced/modified path, including merge parents and files
  // deleted by a later commit. Removing a file from HEAD does not erase it.
  const paths=split(git(['diff-tree','--root','--no-commit-id','--name-only','--no-renames','--diff-filter=ACMT','-r','-m','-z',commit]));
  for(const path of ignored([...new Set(paths)]))blocked.set(path,commit.slice(0,12));
 }
 if(blocked.size) {
  console.error('Public-file check blocked: ignored/local material is tracked or included in unpublished history.');
  for(const [path,source] of blocked)console.error(`${source}: ${JSON.stringify(path)}`);
  console.error('Keep local copies; remove them from Git and from any unpublished commits before pushing.');
  process.exitCode=1;
 } else console.log(`Public-file check passed (${commits.size} unpublished commits inspected). This is a path policy, not a content/secret scan.`);
} catch(error) {
 console.error(`Public-file check failed: ${error.message}. Fetch the target remote if its base commit is unavailable.`);
 process.exitCode=1;
}
