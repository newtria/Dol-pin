import {test,expect,type APIRequestContext,type Browser} from '@playwright/test';

const gateway='http://127.0.0.1:55325';
async function control(request:APIRequestContext,path:string,data?:Record<string,unknown>){
 const response=await request.post(`${gateway}/__qa/${path}`,{data});
 expect(response.ok(),`${path} fixture request`).toBeTruthy();
 return response.json();
}
async function actor(browser:Browser,session:unknown){
 const context=await browser.newContext();
 // Install only the isolated fixture's login. DB, Auth, API and UI responses
 // remain real; the gateway replaces only the external payment provider.
 await context.addInitScript(session=>{
  if(!sessionStorage.getItem('qa-initial-login')){
   localStorage.setItem('sb-127-auth-token',JSON.stringify(session));
   sessionStorage.setItem('qa-initial-login','yes');
  }
 },session);
 const page=await context.newPage();const errors:string[]=[];
 page.on('pageerror',error=>errors.push(error.message));
 return {context,page,errors};
}

test('renaming an account preserves region and language already stored for it',async({browser,request})=>{
 const f=await control(request,'seed');const borrower=await actor(browser,f.borrower);
 try{
  const initial=await control(request,'profile-preferences',{tag:f.tag,initialize:true});
  expect(initial).toMatchObject({region:'서울',locale:'ja'});
  await borrower.page.goto('/account');
  await borrower.page.getByLabel('새 닉네임',{exact:true}).fill('변경한 닉네임');
  await borrower.page.getByRole('button',{name:'닉네임 변경',exact:true}).click();
  await expect(borrower.page.getByRole('status')).toContainText('닉네임을 변경했습니다.');
  await expect(borrower.page.getByText('변경한 닉네임',{exact:true})).toBeVisible();
  const saved=await control(request,'profile-preferences',{tag:f.tag});
  expect(saved).toMatchObject({nickname:'변경한 닉네임',region:'서울',locale:'ja'});
  expect(borrower.errors).toEqual([]);
 }finally{
  await borrower.context.close();await control(request,'cleanup',{tag:f.tag});
 }
});

test('a general inquiry reaches the operator and its notification opens the actual reply',async({browser,request})=>{
 const f=await control(request,'seed');const borrower=await actor(browser,f.borrower);
 try{
  await borrower.page.goto('/support');
  const description='기기 알림을 받지 못하고 있습니다. 설정 방법을 확인해 주세요.';
  await borrower.page.getByLabel('일반 문의',{exact:true}).fill(description);
  await borrower.page.getByRole('button',{name:'문의 접수',exact:true}).click();
  await expect(borrower.page.getByRole('status')).toContainText('문의를 접수했습니다.');
  await expect(borrower.page.getByText(description,{exact:true})).toBeVisible();
  await expect(borrower.page.getByRole('heading',{name:'접수 · 확인 중'})).toBeVisible();
  const {answer}=await control(request,'answer-support',{tag:f.tag});
  await borrower.page.goto('/notifications');
  const result=borrower.page.getByRole('link',{name:'문의 처리 결과 보기',exact:true});
  await expect(result).toHaveAttribute('href','/support');
  await result.click();
  await expect(borrower.page).toHaveURL(/\/support$/);
  await expect(borrower.page.getByRole('heading',{name:'답변 완료',exact:true})).toBeVisible();
  await expect(borrower.page.getByRole('heading',{name:'운영팀 답변',exact:true})).toBeVisible();
  await expect(borrower.page.getByText(answer,{exact:true})).toBeVisible();
  await expect(borrower.page.getByRole('main').getByRole('alert')).toHaveCount(0);
  expect(borrower.errors).toEqual([]);
 }finally{
  await borrower.context.close();await control(request,'cleanup',{tag:f.tag});
 }
});

test('both transaction parties can read the settled dispute amount and decision',async({browser,request})=>{
 const f=await control(request,'seed');const borrower=await actor(browser,f.borrower),lender=await actor(browser,f.lender);
 try{
  const decision=await control(request,'resolved-rental',{tag:f.tag});
  for(const user of [borrower,lender]){
   await user.page.goto(`/rentals/${decision.reservationId}`);
   await expect(user.page.getByText('분쟁 해결',{exact:true})).toBeVisible();
   const result=user.page.getByRole('region',{name:'운영 검토 결과',exact:true});
   await expect(result).toContainText('환불액 32,000원');
   await expect(result).toContainText(decision.reason);
   await expect(result).toContainText('결제 수단 반영 시점은 결제사에 따라');
   await expect(user.page.getByRole('main').getByRole('alert')).toHaveCount(0);
  }
  expect([...borrower.errors,...lender.errors]).toEqual([]);
 }finally{
  await borrower.context.close();await lender.context.close();await control(request,'cleanup',{tag:f.tag});
 }
});
