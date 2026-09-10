import {defineConfig} from '@playwright/test';
export default defineConfig({
 testDir:'./scripts/qa/browser',fullyParallel:false,workers:1,retries:process.env.CI?1:0,
 timeout:60000,expect:{timeout:15000},
 outputDir:process.env.DOLPIN_QA_OUTPUT??'/tmp/dolpin-qa-results',
 reporter:'list',
 use:{channel:'chromium',baseURL:'http://127.0.0.1:3010',trace:'retain-on-failure',screenshot:'only-on-failure'},
 webServer:[
  {command:'npm run qa:gateway',url:'http://127.0.0.1:55325/__qa/health',reuseExistingServer:false,timeout:60000},
  {command:'DOLPIN_NEXT_DIST_DIR=.next-qa node node_modules/next/dist/bin/next start apps/web --port 3010 --hostname 127.0.0.1',url:'http://127.0.0.1:3010',reuseExistingServer:false,timeout:60000},
 ],
});
