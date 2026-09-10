import {test} from 'node:test';
import assert from 'node:assert/strict';
import {emailLoginInput,emailSignupInput} from '../apps/mobile/src/email-auth-input.ts';
import {errorMessage} from '../apps/mobile/src/error-message.ts';

test('signup validates confirmation and strength without altering passwords',()=>{
 const input={email:'  qa@example.com  ',password:'Long password ',confirmation:'Long password '};
 assert.equal(emailSignupInput.parse(input).email,'qa@example.com');
 assert.equal(emailSignupInput.parse(input).password,input.password);
 assert.equal(emailSignupInput.safeParse({...input,confirmation:'Long password'}).success,false);
 assert.equal(emailSignupInput.safeParse({...input,password:'short',confirmation:'short'}).success,false);
 assert.equal(emailSignupInput.safeParse({...input,email:'invalid'}).success,false);
});
test('existing login passwords are not subjected to new signup rules',()=>{
 assert.equal(emailLoginInput.safeParse({email:'qa@example.com',password:'legacy'}).success,true);
 assert.equal(emailLoginInput.safeParse({email:'qa@example.com',password:''}).success,false);
});
test('auth errors explain recovery without revealing account details',()=>{
 assert.equal(errorMessage({code:'invalid_credentials',message:'private detail'}),'이메일 또는 비밀번호를 확인해 주세요.');
 assert.match(errorMessage({code:'email_not_confirmed'}),/이메일 확인/);
 assert.match(errorMessage({code:'weak_password'}),/더 안전한/);
});
