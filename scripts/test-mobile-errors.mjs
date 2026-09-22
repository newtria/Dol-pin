import {test} from 'node:test';
import assert from 'node:assert/strict';
import {errorMessage} from '../apps/mobile/src/error-message.ts';
import {ApiRequestError,errorMessage as sharedErrorMessage,errorRequestId} from '../packages/api-client/src/errors.ts';

test('internal errors never expose stack, SQL, paths or arbitrary server copy',()=>{
 for(const error of [new Error('SQL relation private.users failed at /private/server.ts:42'), {message:'secret=abc123',code:'unknown'}, 'Error: private key abc', null, undefined]){
  assert.equal(errorMessage(error),'오류가 발생했습니다. 잠시 후 다시 시도해 주세요.');
 }
});

test('web and mobile share the same safe error boundary for API and journal codes',()=>{
 assert.equal(errorMessage,sharedErrorMessage);
 for(const [code,copy] of [
  ['AUTH_REQUIRED','다시 로그인'],['STATE_CONFLICT','최신 상태'],
  ['PAYMENT_REVIEW_REQUIRED','중복 결제'],['REQUEST_TIMEOUT','처리 결과'],
  ['RENTAL_REQUEST_STORAGE_CORRUPT','새 요청을 중지'],['RENTAL_REQUEST_IN_PROGRESS','다른 화면'],
  ['RENTAL_REQUEST_LOCK_UNAVAILABLE','최신 브라우저'],
  ['AUTH_CALLBACK_INVALID','확인 메일을 새로'],
 ]) {
  const error=new ApiRequestError({code,error:'secret SQL /private/path stacktrace'});
  assert.match(sharedErrorMessage(error),new RegExp(copy));
  assert.doesNotMatch(sharedErrorMessage(error),/secret|SQL|private|stacktrace/);
 }
 assert.equal(sharedErrorMessage(new ApiRequestError({error:'do not render me'})),sharedErrorMessage(null));
});

test('locally authored recovery instructions require an exact allowlist match',()=>{
 const copy='결제 링크를 확인할 수 없습니다. 거래 상세에서 결제 결과를 확인하거나 결제를 시작해 주세요.';
 assert.equal(sharedErrorMessage(new Error(copy)),copy);
 assert.equal(sharedErrorMessage(new Error(copy+' SQL /private/token')),sharedErrorMessage(null));
});

test('stopped financial recovery never promises automatic progress',()=>{
 for(const code of ['PAYMENT_REVIEW_REQUIRED','PDR01']) {
  assert.match(sharedErrorMessage({code}),/자동 처리가 멈춰 운영 확인이 필요/);
  assert.match(sharedErrorMessage({code}),/중복 결제/);
 }
});

test('mobile photo validation keeps useful instructions without accepting appended details',()=>{
 for(const copy of ['반납 사진을 먼저 선택해 주세요.','사진을 읽지 못했습니다.','5MB 이하 사진을 선택해 주세요.','JPG, PNG, WebP 사진을 선택해 주세요.']) {
  assert.equal(sharedErrorMessage(new Error(copy)),copy);
  assert.equal(sharedErrorMessage(new Error(copy+' /private/image token=secret')),sharedErrorMessage(null));
 }
});

test('only UUID request references are safe to show next to an error',()=>{
 const id='82ca464a-f28c-4e80-83b0-485086ba9b17';
 assert.equal(errorRequestId(new ApiRequestError({requestId:id})),id);
 for(const requestId of ['/private/credentials','SQL constraint private',123,null,''])
  assert.equal(errorRequestId({requestId}),undefined);
});
test('known failures have actionable app-owned copy',()=>{
 const cases=[
  [new Error("KeyChainException: entitlement absent at ExpoSecureStore/SecureStoreModule.swift:168"),'앱을 다시 실행'],
  [new TypeError('Network request failed'),'인터넷 연결'],
  [{code:'otp_expired'},'새 번호'],
  [{code:'over_request_rate_limit'},'잠시 기다려'],
  [{code:'23P01'},'다른 기간'],
  [{code:'PGRST116'},'목록에서 다시'],
  [{code:'refresh_token_not_found'},'다시 로그인'],
 ];
 for(const [error,expected] of cases) assert.ok(errorMessage(error).includes(expected));
});
