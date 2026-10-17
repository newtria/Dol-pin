import {test} from 'node:test';
import assert from 'node:assert/strict';
import {rentalPeriodConflict,rentalNextStep} from '../packages/contracts/src/rental-ux.ts';
import {safeReturnTo,accountHref} from '../apps/web/components/auth-return.ts';
import {localExploreTime} from '../apps/web/lib/explore-time.ts';

const start='2099-10-18T10:00:00+09:00',end='2099-10-18T14:00:00+09:00';
const slot={starts_at:start,ends_at:end};
test('shared date links preserve the same Korean time across timezone formats',()=>{
 for(const value of ['2099-10-18T10:00:00+09:00','2099-10-18T10:00:00+0900','2099-10-18T01:00:00Z',' 2099-10-18 10:00 ']) {
  assert.equal(localExploreTime(value),'2099-10-18T10:00');
 }
 for(const invalid of ['2099-02-30T10:00','2099-02-30T10:00:00Z']) {
  assert.ok(rentalPeriodConflict(localExploreTime(invalid),'2099-03-01T14:00',[]));
 }
});
test('reservation form compares occupied intervals as half-open ranges',()=>{
 assert.equal(rentalPeriodConflict('2099-10-18T09:00','2099-10-18T10:00',[slot]),null);
 assert.equal(rentalPeriodConflict('2099-10-18T14:00','2099-10-18T15:00',[slot]),null);
 assert.match(rentalPeriodConflict('2099-10-18T09:59','2099-10-18T10:01',[slot]),/겹쳐/);
 assert.match(rentalPeriodConflict(start,end,[slot]),/겹쳐/);
});
test('item availability uses the Korean date for both endpoints',()=>{
 assert.equal(rentalPeriodConflict('2099-10-17T15:00:00Z','2099-10-18T14:59:00Z',[],'2099-10-18','2099-10-18'),null);
 assert.match(rentalPeriodConflict('2099-10-17T14:59:00Z','2099-10-18T12:00:00Z',[],'2099-10-18'),/부터/);
 assert.match(rentalPeriodConflict(start,'2099-10-18T15:00:00Z',[],null,'2099-10-18'),/까지/);
});
test('incomplete, impossible, past and reversed periods never appear available',()=>{
 for(const invalid of ['', '2099-02-30T10:00', '2099-02-30T10:00:00Z', 'not a date']) {
  assert.ok(rentalPeriodConflict(invalid,end,[]));
 }
 assert.ok(rentalPeriodConflict('2000-01-01T10:00','2000-01-02T10:00',[]));
 assert.ok(rentalPeriodConflict(end,start,[]));
 assert.ok(rentalPeriodConflict(start,end,[{starts_at:'invalid',ends_at:end}]));
});

const rental={status:'requested',lender_id:'lender',borrower_id:'borrower'};
test('next actions follow the participant role',()=>{
 assert.equal(rentalNextStep(rental,'lender').actionLabel,'요청 확인');
 assert.equal(rentalNextStep(rental,'borrower').tone,'waiting');
 assert.equal(rentalNextStep({...rental,status:'accepted'},'borrower').actionLabel,'결제하기');
 assert.equal(rentalNextStep({...rental,status:'accepted'},'lender').tone,'waiting');
 assert.equal(rentalNextStep({...rental,status:'returned'},'lender').actionLabel,'반납 확인');
 assert.equal(rentalNextStep({...rental,status:'returned'},'borrower').tone,'waiting');
 assert.equal(rentalNextStep(rental,'outsider').tone,'neutral');
});
test('financial uncertainty takes precedence over normal transaction actions',()=>{
 const accepted={...rental,status:'accepted',payment_attempt_merchant_uid:'order'};
 assert.equal(rentalNextStep(accepted,'borrower').actionLabel,'결제 결과 확인');
 assert.equal(rentalNextStep(accepted,'borrower',{state:'needs_review',reference:'r',next_retry_at:null}).tone,'warning');
 assert.equal(rentalNextStep({...rental,status:'returned',payment_action:'settle_pending'},'lender').tone,'waiting');
 assert.notEqual(rentalNextStep({...rental,status:'accepted',payment_due_at:'2000-01-01T00:00:00Z'},'borrower').actionLabel,'결제하기');
});
test('an already confirmed pickup waits for the other participant',()=>{
 const paid={...rental,status:'paid'},pickup={borrowerConfirmed:true,lenderConfirmed:false};
 assert.equal(rentalNextStep(paid,'borrower',undefined,pickup).tone,'waiting');
 assert.equal(rentalNextStep(paid,'lender',undefined,pickup).actionLabel,'전달 확인');
 assert.ok(rentalNextStep(paid,'lender').priority<rentalNextStep({...rental,status:'settled'},'lender').priority);
});

test('authentication preserves selected rental dates and intended internal destination',()=>{
 const destination='/items/75000000-0000-4000-8000-000000000001/reserve?startsAt=2099-10-18T10%3A00&endsAt=2099-10-18T14%3A00';
 assert.equal(safeReturnTo(destination),destination);
 const account=new URL(accountHref(destination),'https://dolpin.invalid');
 assert.equal(account.pathname,'/account');
 assert.equal(account.searchParams.get('returnTo'),destination);
 for(const path of ['/items','/items/new','/items/mine','/rentals','/rentals/rental-id','/notifications','/support','/account/payouts','/operations']) {
  assert.equal(safeReturnTo(path),path);
 }
});
test('post-login navigation rejects external, malformed and unsupported routes',()=>{
 for(const path of [null,undefined,'','https://evil.invalid/items','//evil.invalid/items','/\\evil.invalid/items',
  '/items/..//evil.invalid','/items/%2e%2e//evil.invalid','/items/one\n','/items/one\u0000',
  '/auth/callback?code=secret','/payments/checkout?token=secret','/api/admin']) {
  assert.equal(safeReturnTo(path),'/account',String(path));
 }
 assert.equal(accountHref('//evil.invalid'),'/account');
 assert.equal(accountHref('/account'),'/account');
 assert.equal(safeReturnTo('/account/?returnTo=%2Frentals'),'/account');
 assert.equal(accountHref('/account/'),'/account');
 assert.equal(safeReturnTo('/rentals#discarded-fragment'),'/rentals');
 assert.equal(safeReturnTo('/account?returnTo=%2Frentals'),'/account');
});
