import {test,expect,type Browser,type BrowserContext,type Page,type APIRequestContext} from '@playwright/test';
const gateway='http://127.0.0.1:55325';
const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aF9sAAAAASUVORK5CYII=','base64');
async function seed(request:APIRequestContext){const r=await request.post(`${gateway}/__qa/seed`);expect(r.ok()).toBeTruthy();return r.json();}
async function actor(browser:Browser,session:unknown,mobile=false) {
 const context=await browser.newContext({viewport:mobile?{width:390,height:844}:{width:1440,height:1000}});
 await context.addInitScript(session=>{if(!localStorage.getItem('sb-127-auth-token'))localStorage.setItem('sb-127-auth-token',JSON.stringify(session));},session);
 return {context,page:await context.newPage()};
}
async function requestRental(page:Page,itemId:string) {
 await page.goto(`/items/${itemId}/reserve`);
 const start=new Date(Date.now()+8*86400000+9*3600000).toISOString().slice(0,16);
 const end=new Date(Date.now()+8*86400000+13*3600000).toISOString().slice(0,16);
 await page.getByLabel('시작 일시').fill(start);await page.getByLabel('반납 일시').fill(end);
 await page.getByRole('button',{name:'예약 요청',exact:true}).click();
 await expect(page).toHaveURL(/\/rentals\/[0-9a-f-]+$/);
 await expect(page.getByText('수락 대기',{exact:true})).toBeVisible();return new URL(page.url()).pathname;
}
async function accept(lender:Page,borrower:Page,path:string) {
 await lender.goto(path);await lender.getByRole('button',{name:'예약 수락',exact:true}).click();
 await expect(lender.getByText('수락됨',{exact:true})).toBeVisible();
 await expect(borrower.getByRole('button',{name:'결제하기',exact:true})).toBeVisible();
}
async function paymentReturn(page:Page) {
 await page.getByRole('button',{name:'결제하기',exact:true}).click();
 await expect(page.getByRole('button',{name:'토스페이먼츠로 결제'})).toBeVisible();
 const orderId=await page.evaluate(()=>sessionStorage.getItem('toss-order'));
 expect(orderId).toBeTruthy();
 // Simulate the external provider redirect only. The page calls the actual
 // confirmation handler, whose DB writes and auth checks are not mocked.
 await page.goto(`/payments/checkout?orderId=${orderId}&paymentKey=qa_${orderId}&amount=35000`);
}
function health(page:Page,allowLostApproval=false) {
 const errors:string[]=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',msg=>{const injected=allowLostApproval&&msg.text().includes('502 (Bad Gateway)')&&msg.location().url.endsWith('/functions/v1/toss-payment');if(msg.type()==='error'&&!injected)errors.push(msg.text());});
 return errors;
}
test('lost approval survives closing checkout and recovers from a fresh session',async({browser,request})=>{
 const f=await seed(request);const b=await actor(browser,f.borrower),l=await actor(browser,f.lender);let fresh:BrowserContext|undefined;
 try {
  const errors=health(b.page,true);const path=await requestRental(b.page,f.item.id);await accept(l.page,b.page,path);
  await request.post(`${gateway}/__qa/lose-approval`);await paymentReturn(b.page);
  await expect(b.page.getByText('QA: approval response lost',{exact:true})).toBeVisible();
  await b.context.close();const recovered=await actor(browser,f.borrower,true);fresh=recovered.context;
  await recovered.page.goto(path);await recovered.page.getByRole('button',{name:'결제 결과 다시 확인',exact:true}).click();
  await expect(recovered.page.getByText('결제 완료',{exact:true})).toBeVisible();
  await expect(recovered.page.getByText('인수·반납 장소: 공연장 2번 출구')).toBeVisible();
  await recovered.page.screenshot({path:test.info().outputPath('recovered-mobile.png'),fullPage:true});
  expect(errors).toEqual([]);
 } finally {await b.context.close();await l.context.close();await fresh?.close();expect((await request.post(`${gateway}/__qa/cleanup`,{data:{tag:f.tag}})).ok()).toBeTruthy();}
});
test('request → accept → pay → pickup → private return → deposit refund',async({browser,request})=>{
 const f=await seed(request);const b=await actor(browser,f.borrower,true),l=await actor(browser,f.lender);
 try {
  const errors=[health(b.page),health(l.page)];const path=await requestRental(b.page,f.item.id);await accept(l.page,b.page,path);
  await paymentReturn(b.page);await expect(b.page.getByRole('heading',{name:'결제 완료',exact:true})).toBeVisible();
  await b.page.getByRole('link',{name:'거래로 돌아가기'}).click();
  await expect(l.page.getByRole('button',{name:'물품 인수 확인'})).toBeVisible();await l.page.getByRole('button',{name:'물품 인수 확인'}).click();
  await expect(b.page.getByLabel('반납 사진 제출')).toBeVisible();
  await b.page.getByLabel('반납 사진 제출').setInputFiles({name:'return.png',mimeType:'image/png',buffer:png});
  await expect(l.page.getByRole('button',{name:'반납 수령 확인 · 보증금 반환'})).toBeVisible();
  await expect(l.page.getByAltText('반납 증빙')).toBeVisible();
  await l.page.getByRole('button',{name:'반납 수령 확인 · 보증금 반환'}).click();
  await expect(l.page.getByText('거래 완료',{exact:true})).toBeVisible();await expect(b.page.getByText('거래 완료',{exact:true})).toBeVisible();
  await expect(l.page).toHaveTitle(/dol-pin/);
  expect(await b.page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBeTruthy();
  await l.page.screenshot({path:test.info().outputPath('settled-desktop.png'),fullPage:true});
  expect(errors.flat()).toEqual([]);
 } finally {await b.context.close();await l.context.close();expect((await request.post(`${gateway}/__qa/cleanup`,{data:{tag:f.tag}})).ok()).toBeTruthy();}
});
test('catalog pagination and URL filters survive reload',async({browser,request})=>{
 const f=await seed(request);const b=await actor(browser,f.borrower);
 try {
  expect((await request.post(`${gateway}/__qa/catalog`,{data:{tag:f.tag}})).ok()).toBeTruthy();
  const errors=health(b.page);await b.page.goto(`/items?search=${f.tag}`);
  await expect(b.page.getByLabel('상품 검색')).toHaveValue(f.tag);
  const cards=b.page.locator('section[aria-label="상품 목록"] a');await expect(cards).toHaveCount(50);
  await b.page.getByRole('button',{name:'물품 더 보기'}).click();await expect(cards).toHaveCount(53);
  await b.page.reload();await expect(b.page.getByLabel('상품 검색')).toHaveValue(f.tag);
  await expect(cards).toHaveCount(50);
  await b.page.getByRole('button',{name:'공연 더 보기'}).click();
  await b.page.getByRole('combobox',{name:'콘서트'}).click();
  await expect(b.page.getByRole('option',{name:`${f.tag} concert 53`,exact:true})).toBeVisible();
  await expect(b.page.getByRole('option',{name:`${f.tag} concert 0`,exact:true})).toHaveCount(0);
  await b.page.getByRole('option',{name:`${f.tag} concert 53`,exact:true}).click();
  await expect(b.page).toHaveURL(/concertId=/);expect(errors).toEqual([]);
 } finally {await b.context.close();expect((await request.post(`${gateway}/__qa/cleanup`,{data:{tag:f.tag}})).ok()).toBeTruthy();}
});

test('product registration uploads a real photo and persists pickup instructions',async({browser,request})=>{
 const f=await seed(request);const l=await actor(browser,f.lender);
 try {
  const errors=health(l.page);await l.page.goto('/items/new');
  await l.page.getByLabel('상품 사진',{exact:false}).setInputFiles({name:'item.png',mimeType:'image/png',buffer:png});
  await expect(l.page.getByAltText('등록할 상품 사진')).toBeVisible();
  await l.page.getByLabel('상품명',{exact:true}).fill(`${f.tag} registered`);
  await l.page.getByLabel('상품 설명',{exact:true}).fill('실제 등록 폼 QA');
  await l.page.getByLabel('인수·반납 장소',{exact:true}).fill('공연장 3번 출구');
  await l.page.getByRole('button',{name:'물품 등록',exact:true}).click();
  await expect(l.page).toHaveURL(/\/items\/[0-9a-f-]+$/);
  await expect(l.page.getByText('인수·반납 장소: 공연장 3번 출구')).toBeVisible();expect(errors).toEqual([]);
 } finally {await l.context.close();expect((await request.post(`${gateway}/__qa/cleanup`,{data:{tag:f.tag}})).ok()).toBeTruthy();}
});
