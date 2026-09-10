import {test} from 'node:test';
import assert from 'node:assert/strict';
import {errorMessage} from '../apps/mobile/src/error-message.ts';

test('internal errors never expose stack, SQL, paths or arbitrary server copy',()=>{
 for(const error of [new Error('SQL relation private.users failed at /private/server.ts:42'), {message:'secret=abc123',code:'unknown'}, 'Error: private key abc', null, undefined]){
  assert.equal(errorMessage(error),'오류가 발생했습니다. 잠시 후 다시 시도해 주세요.');
 }
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
