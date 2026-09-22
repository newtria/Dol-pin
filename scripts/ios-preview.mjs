import {spawnSync,execFileSync} from 'node:child_process';
import {existsSync,mkdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,resolve,join} from 'node:path';
import {tmpdir} from 'node:os';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const mobile=join(root,'apps/mobile');
const buildRoot=process.env.DOLPIN_IOS_BUILD_ROOT??join(process.env.DOLPIN_RUNTIME_ROOT??tmpdir(),'dolpin-ios-preview');
const app=join(buildRoot,'Build/Products/Release-iphonesimulator/dolpin.app');
const bundle='app.dolpin.preview';
const mode=process.argv[2];
const udid=process.argv[3];
const run=(command,args,cwd=root,env=process.env)=>{
 const result=spawnSync(command,args,{cwd,stdio:'inherit',env});
 if(result.error)throw result.error;
 if(result.status!==0)throw new Error(`${command} failed (${result.status})`);
};
const capture=(command,args)=>execFileSync(command,args,{cwd:root,encoding:'utf8',timeout:120000}).trim();
if(process.platform!=='darwin')throw new Error('iOS preview requires macOS and Xcode.');
if(mode==='build'){
 let restoreRuntime;
 if(udid){
  const devices=JSON.parse(capture('xcrun',['simctl','list','devices','available','--json'])).devices;
  const runtimeId=Object.entries(devices).find(([,items])=>items.some(d=>d.udid===udid))?.[0];
  const runtime=JSON.parse(capture('xcrun',['simctl','list','runtimes','--json'])).runtimes.find(r=>r.identifier===runtimeId);
  if(!runtime||runtime.platform!=='iOS')throw new Error('Provide an available iOS simulator UDID.');
  const mapping=Object.entries(JSON.parse(capture('xcrun',['simctl','runtime','match','list','--json']))).find(([name])=>name.startsWith('iphoneos'));
  if(!mapping)throw new Error('The selected Xcode has no iOS SDK.');
  const [sdk,previous]=mapping;
  if(previous.chosenRuntimeBuild!==runtime.buildversion){
   run('xcrun',['simctl','runtime','match','set',sdk,runtime.buildversion]);
   restoreRuntime=()=>run('xcrun',['simctl','runtime','match','set',sdk,previous.userOverriddenBuild??'--default']);
  }
 }
 try {
 mkdirSync(buildRoot,{recursive:true});
 run('npm',['exec','--','expo','prebuild','--platform','ios','--no-install'],mobile);
 // CocoaPods autolinking resolves the project from cwd, not --project-directory.
 // Pod prepare scripts compile host binaries. Use the selected Xcode's SDK
 // so a newer Command Line Tools SDK cannot be mixed with an older linker.
 const podEnv={...process.env,SDKROOT:capture('xcrun',['--sdk','macosx','--show-sdk-path'])};
 run('pod',['install'],join(mobile,'ios'),podEnv);
 // Keep Xcode's simulator signing: disabling it breaks SecureStore entitlements.
 run('xcodebuild',['-workspace',join(mobile,'ios/dolpin.xcworkspace'),'-scheme','dolpin','-configuration','Release','-sdk','iphonesimulator','-destination','generic/platform=iOS Simulator','-derivedDataPath',buildRoot,'ARCHS=arm64','CODE_SIGNING_ALLOWED=YES','CODE_SIGN_IDENTITY=-','build']);
 if(!existsSync(join(app,'main.jsbundle')))throw new Error('Preview must contain its own JS bundle.');
 console.log(`Standalone preview: ${app}`);
 }finally{restoreRuntime?.();}
}else if(mode==='open'||mode==='qa'){
 if(!udid||!/^[A-Fa-f0-9-]{36}$/.test(udid))throw new Error('Provide an explicit simulator UDID: npm run ios:open -- <UDID>');
 if(!existsSync(app))throw new Error('Build first: npm run ios:build');
 const devices=Object.values(JSON.parse(capture('xcrun',['simctl','list','devices','available','--json'])).devices).flat();
 const device=devices.find(d=>d.udid===udid);if(!device)throw new Error('Simulator not found. Devices are never created or deleted by this script.');
 if(device.state!=='Booted')run('xcrun',['simctl','boot',udid]);
 run('xcrun',['simctl','bootstatus',udid,'-b']);
 run('open',['-a','Simulator','--args','-CurrentDeviceUDID',udid]);
 run('xcrun',['simctl','install',udid,app]);
 const rounds=mode==='qa'?5:1;
 for(let i=0;i<rounds;i++){
  const output=capture('xcrun',['simctl','launch','--terminate-running-process',udid,bundle]);
  const pid=Number(output.match(/:\s*(\d+)$/)?.[1]);if(!pid)throw new Error(`Missing process ID: ${output}`);
  for(let tick=0;tick<(mode==='qa'?20:10);tick++){
   await new Promise(done=>setTimeout(done,1000));
   // Simulator processes share the host PID namespace. Check identity as well
   // as liveness so a reused PID cannot turn a crash into a false pass.
   const command=capture('ps',['-p',String(pid),'-o','comm=']);
   if(!command.endsWith('/dolpin.app/dolpin'))throw new Error(`Preview process ${pid} exited or changed identity.`);
  }
  console.log(`Preview survived launch ${i+1}/${rounds} (pid ${pid}).`);
 }
 console.log(mode==='qa'?'Five cold launches passed. Verify rendered UI and navigation separately.':'Preview is running.');
}else throw new Error('Usage: node scripts/ios-preview.mjs build | open <UDID> | qa <UDID>');
