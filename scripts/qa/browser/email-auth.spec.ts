import {test, expect} from '@playwright/test';

// UI contract tests intentionally mock Auth responses. Real confirmation and
// password login are covered separately by check-local-email-auth.mjs.
test('email signup validates input and explains confirmation without removing other login methods', async ({page}) => {
  let submitted: Record<string, unknown> | undefined;
  await page.route('**/auth/v1/signup**', async route => {
    submitted = route.request().postDataJSON();
    await route.fulfill({status: 200, contentType: 'application/json', body: JSON.stringify({id: '82ca464a-f28c-4e80-83b0-485086ba9b17', aud: 'authenticated', email: 'qa@example.test', identities: [], created_at: '2026-09-01T00:00:00Z'})});
  });
  await page.goto('/account');
  await expect(page.getByRole('heading', {name: '이메일로 로그인'})).toBeVisible();
  await expect(page.getByRole('button', {name: '카카오 로그인'})).toBeVisible();
  await expect(page.getByRole('button', {name: '전화번호로 로그인', exact: true})).toBeVisible();
  await page.getByRole('button', {name: '처음이신가요? 이메일로 가입하기'}).click();
  await page.getByLabel('이메일', {exact: true}).fill('qa@example.test');
  await page.getByLabel('비밀번호', {exact: true}).fill('Long password ');
  await page.getByLabel('비밀번호 확인', {exact: true}).fill('mismatch');
  await page.getByRole('button', {name: '가입하기', exact: true}).click();
  await expect(page.getByText('비밀번호가 일치하지 않습니다.')).toBeVisible();
  expect(submitted).toBeUndefined();
  await page.getByLabel('비밀번호 확인', {exact: true}).fill('Long password ');
  await page.getByRole('button', {name: '가입하기', exact: true}).click();
  await expect(page.getByRole('status')).toContainText('메일의 링크로 가입을 확인');
  await expect(page.getByRole('heading', {name: '이메일로 로그인'})).toBeVisible();
  await expect(page.getByLabel('비밀번호', {exact: true})).toHaveValue('');
  expect(submitted?.email).toBe('qa@example.test');
  expect(submitted?.password).toBe('Long password ');
  await expect(page.getByRole('button', {name: '확인 메일 다시 받기'})).toBeVisible();
});

test('unconfirmed login offers resend and never displays provider details', async ({page}) => {
  let resent = false;
  await page.route('**/auth/v1/token?grant_type=password', route => route.fulfill({status: 400, contentType: 'application/json', body: JSON.stringify({code: 'email_not_confirmed', msg: 'SQL private.users at /private/server.ts:42 secret=abc'})}));
  await page.route('**/auth/v1/resend', async route => {resent = true; await route.fulfill({status: 200, contentType: 'application/json', body: '{}'});});
  await page.goto('/account');
  await page.getByLabel('이메일', {exact: true}).fill('qa@example.test');
  await page.getByLabel('비밀번호', {exact: true}).fill('password');
  await page.getByRole('button', {name: '이메일 로그인', exact: true}).click();
  await expect(page.getByRole('alert')).toContainText('이메일 확인이 필요합니다.');
  await expect(page.getByRole('main')).not.toContainText('private.users');
  await expect(page.getByRole('main')).not.toContainText('secret=abc');
  await page.getByRole('button', {name: '확인 메일 다시 받기'}).click();
  await expect(page.getByRole('status')).toContainText('확인 메일을 다시 보냈습니다.');
  expect(resent).toBe(true);
});

test('callback parameters cannot become user-visible error text', async ({page}) => {
  await page.goto('/auth/callback?error_description=SQL%20private.users%20secret%3Dabc');
  await expect(page.getByRole('alert')).toContainText('다시 로그인하거나 확인 메일을 새로 받아');
  await expect(page.getByRole('main')).not.toContainText('private.users');
  await expect(page.getByRole('main')).not.toContainText('secret=abc');
  await expect(page.getByRole('link', {name: '다시 로그인'})).toHaveAttribute('href', '/account');
});
