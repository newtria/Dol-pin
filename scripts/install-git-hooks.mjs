#!/usr/bin/env node
import {spawnSync} from 'node:child_process';
import {realpathSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const git=args=>spawnSync('git',args,{cwd:root,encoding:'utf8'});
const top=git(['rev-parse','--show-toplevel']);
if(top.status!==0||realpathSync(top.stdout.trim())!==realpathSync(root)) {
 console.log('No project Git checkout; skipped pre-push hook installation.');
} else {
 const current=git(['config','--get','core.hooksPath']);
 if(current.status===0&&current.stdout.trim()!=='.githooks') {
  console.warn('Existing Git hooks preserved. Add this project’s .githooks/pre-push check to your hook before publishing.');
 } else {
  const installed=git(['config','--local','core.hooksPath','.githooks']);
  if(installed.status!==0)throw new Error(installed.stderr.trim()||'Cannot install public-file pre-push check');
  console.log('Installed public-file pre-push check.');
 }
}
