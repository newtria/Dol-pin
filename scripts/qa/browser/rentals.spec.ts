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
 await expect(page.getByRole('region',{name:'예상 결제 금액'})).toContainText('총 결제액 35,000원');
 await page.getByRole('button',{name:'예약 요청',exact:true}).click();
 await expect(page).toHaveURL(/\/rentals\/[0-9a-f-]+$/);
 await expect(page.getByText('수락 대기',{exact:true})).toBeVisible();
 await expect(page.getByRole('heading',{name:'수락한 거래 조건'})).toHaveCount(0);
 await expect(page.getByText('빌려주는 분의 수락을 기다리고 있어요')).toBeVisible();return new URL(page.url()).pathname;
}
async function accept(lender:Page,borrower:Page,path:string) {
 await lender.goto(path);await lender.getByRole('button',{name:'예약 수락',exact:true}).click();
 await expect(lender.getByText('수락됨',{exact:true})).toBeVisible();
 await expect(borrower.getByRole('button',{name:'결제하기',exact:true})).toBeVisible();
 await expect(borrower.getByRole('button',{name:'결제 결과 다시 확인',exact:true})).toHaveCount(0);
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
  await expect(b.page.getByText('연결이 원활하지 않아 다시 확인 중입니다. 결제 실패로 확정된 상태는 아닙니다.')).toBeVisible();
  await expect(b.page.getByRole('main').getByRole('alert')).toHaveCount(0);
  await b.context.close();const recovered=await actor(browser,f.borrower,true);fresh=recovered.context;
  expect((await request.post(`${gateway}/__qa/recovery-due`,{data:{tag:f.tag}})).ok()).toBeTruthy();
  await recovered.page.goto(path);
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
  await expect(l.page.getByRole('button',{name:'물품을 전달했어요'})).toBeVisible();await l.page.getByRole('button',{name:'물품을 전달했어요'}).click();
  await expect(b.page.getByLabel('반납 사진 선택')).toBeVisible();
  await b.page.getByLabel('반납 사진 선택').setInputFiles({name:'return.png',mimeType:'image/png',buffer:png});
  await expect(b.page.getByAltText('제출할 반납 사진')).toBeVisible();
  await expect(b.page.getByText('사용 중',{exact:true})).toBeVisible();
  await expect(l.page.getByRole('button',{name:'반납 수령 확인 · 보증금 반환'})).toHaveCount(0);
  await b.page.getByRole('button',{name:'사진 제거',exact:true}).click();
  await expect(b.page.getByRole('button',{name:'반납 제출',exact:true})).toHaveCount(0);
  await b.page.getByLabel('반납 사진 선택').setInputFiles({name:'replacement.png',mimeType:'image/png',buffer:png});
  await b.page.getByRole('button',{name:'반납 제출',exact:true}).click();
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
  await l.page.getByLabel('공개할 만남 지역',{exact:true}).fill('공연장 인근');
  await l.page.getByLabel('상세 인수·반납 장소',{exact:true}).fill('공연장 3번 출구');
  await l.page.getByRole('button',{name:'물품 등록',exact:true}).click();
  await expect(l.page).toHaveURL(/\/items\/[0-9a-f-]+$/);
  await expect(l.page.getByText('만남 지역: 공연장 인근')).toBeVisible();
  await expect(l.page.getByText('상대에게 안내할 상세 장소: 공연장 3번 출구')).toBeVisible();expect(errors).toEqual([]);
 } finally {await l.context.close();expect((await request.post(`${gateway}/__qa/cleanup`,{data:{tag:f.tag}})).ok()).toBeTruthy();}
});

test('checkout recovers a lost response automatically without presenting failure',async({browser,request})=>{
 const f=await seed(request);const b=await actor(browser,f.borrower,true),l=await actor(browser,f.lender);
 try {
  const errors=health(b.page,true);const path=await requestRental(b.page,f.item.id);await accept(l.page,b.page,path);
  await request.post(`${gateway}/__qa/lose-approval`);await paymentReturn(b.page);
  await expect(b.page.getByRole('heading',{name:'결제 결과 확인 중'})).toBeVisible();
  await expect(b.page.getByRole('main').getByRole('alert')).toHaveCount(0);
  await expect(b.page.getByText('연결이 원활하지 않아 다시 확인 중입니다. 결제 실패로 확정된 상태는 아닙니다.')).toBeVisible();
  expect((await request.post(`${gateway}/__qa/recovery-due`,{data:{tag:f.tag}})).ok()).toBeTruthy();
  await expect(b.page.getByRole('heading',{name:'결제 완료',exact:true})).toBeVisible();
  await b.page.reload();await expect(b.page.getByRole('heading',{name:'결제 완료',exact:true})).toBeVisible();
  await b.page.getByRole('link',{name:'거래로 돌아가기'}).click();await expect(b.page).toHaveURL(new RegExp(path+'$'));expect(errors).toEqual([]);
 }finally{await b.context.close();await l.context.close();expect((await request.post(`${gateway}/__qa/cleanup`,{data:{tag:f.tag}})).ok()).toBeTruthy();}
});

test('reviewed payment explains that automatic work stopped in checkout and rental detail',async({browser,request})=>{
 const f=await seed(request);const b=await actor(browser,f.borrower),l=await actor(browser,f.lender);
 try {
  const path=await requestRental(b.page,f.item.id);await accept(l.page,b.page,path);
  await request.post(`${gateway}/__qa/lose-approval`);await paymentReturn(b.page);
  await expect(b.page.getByText('연결이 원활하지 않아 다시 확인 중입니다. 결제 실패로 확정된 상태는 아닙니다.')).toBeVisible();
  expect((await request.post(`${gateway}/__qa/review-checkout`,{data:{tag:f.tag}})).ok()).toBeTruthy();
  await expect(b.page.getByRole('heading',{name:'결제 처리에 운영 확인이 필요해요'})).toBeVisible();
  await expect(b.page.getByText('자동 처리가 멈췄습니다.',{exact:false})).toBeVisible();
  await b.page.getByRole('link',{name:'거래로 돌아가기'}).click();
  await expect(b.page).toHaveURL(new RegExp(path+'$'));
  await expect(b.page.getByRole('heading',{name:'결제 처리에 운영 확인이 필요해요'})).toBeVisible();
  await expect(b.page.getByText(`문의용 거래 번호: ${path.split('/').pop()}`)).toBeVisible();
 }finally{await b.context.close();await l.context.close();expect((await request.post(`${gateway}/__qa/cleanup`,{data:{tag:f.tag}})).ok()).toBeTruthy();}
});

test('refund requires amount review and an explicit confirmation',async({browser,request})=>{
 const f=await seed(request);const b=await actor(browser,f.borrower,true),l=await actor(browser,f.lender);
 try {
  const errors=health(b.page);const path=await requestRental(b.page,f.item.id);await accept(l.page,b.page,path);await paymentReturn(b.page);
  await b.page.getByRole('link',{name:'거래로 돌아가기'}).click();
  await b.page.getByRole('button',{name:'거래 취소 · 전액 환불',exact:true}).click();
  const review=b.page.getByRole('region',{name:'환불 확인'});await expect(review).toContainText('35,000원');
  await expect(b.page.getByText('결제 완료',{exact:true})).toBeVisible();
  await review.getByRole('button',{name:'거래 유지'}).click();await expect(review).toHaveCount(0);
  await expect(b.page.getByText('결제 완료',{exact:true})).toBeVisible();
  await b.page.getByRole('button',{name:'거래 취소 · 전액 환불',exact:true}).click();
  await b.page.screenshot({path:test.info().outputPath('refund-review-mobile.png'),fullPage:true});
  await review.getByRole('button',{name:'취소하고 35,000원 환불',exact:true}).click();
  await expect(b.page.getByText('취소됨',{exact:true})).toBeVisible();expect(errors).toEqual([]);
 }finally{await b.context.close();await l.context.close();expect((await request.post(`${gateway}/__qa/cleanup`,{data:{tag:f.tag}})).ok()).toBeTruthy();}
});

test('estimated total follows 24 hour boundaries and hides invalid periods',async({browser,request})=>{
 const f=await seed(request);const b=await actor(browser,f.borrower);
 try {
  await b.page.goto(`/items/${f.item.id}/reserve`);
  const day=new Date(Date.now()+8*86400000).toISOString().slice(0,10),tomorrow=new Date(Date.now()+9*86400000).toISOString().slice(0,10);
  const summary=b.page.getByRole('region',{name:'예상 결제 금액'});
  await b.page.getByLabel('시작 일시').fill(`${day}T10:00`);await b.page.getByLabel('반납 일시').fill(`${tomorrow}T10:00`);
  await expect(summary).toContainText('총 결제액 35,000원');
  await b.page.getByLabel('반납 일시').fill(`${tomorrow}T10:01`);await expect(summary).toContainText('총 결제액 40,000원');
  await b.page.getByLabel('반납 일시').fill(`${day}T10:00`);await expect(summary).toHaveCount(0);
 }finally{await b.context.close();expect((await request.post(`${gateway}/__qa/cleanup`,{data:{tag:f.tag}})).ok()).toBeTruthy();}
});

test('expired checkout explains the state and provides a working way back',async({browser,request})=>{
 const f=await seed(request);const b=await actor(browser,f.borrower,true),l=await actor(browser,f.lender);
 try {
  const path=await requestRental(b.page,f.item.id);await accept(l.page,b.page,path);
  await b.page.getByRole('button',{name:'결제하기',exact:true}).click();
  await expect(b.page.getByRole('button',{name:'토스페이먼츠로 결제'})).toBeVisible();
  expect((await request.post(`${gateway}/__qa/expire-checkout`,{data:{tag:f.tag}})).ok()).toBeTruthy();
  await b.page.reload();await expect(b.page.getByRole('heading',{name:'결제 기한이 끝났어요'})).toBeVisible();
  await expect(b.page.getByRole('button',{name:'토스페이먼츠로 결제'})).toHaveCount(0);
  await b.page.getByRole('link',{name:'거래로 돌아가기'}).click();await expect(b.page).toHaveURL(new RegExp(path+'$'));
 }finally{await b.context.close();await l.context.close();expect((await request.post(`${gateway}/__qa/cleanup`,{data:{tag:f.tag}})).ok()).toBeTruthy();}
});
