import { fixture, checked, fakeProvider, localSql, png } from './fixture.ts';
import { createHandler as checkoutHandler } from '../../supabase/functions/toss-payment/index.ts';
import { createHandler as financeHandler } from '../../supabase/functions/finance-ops/index.ts';
import { createHandler as recoveryHandler } from '../../supabase/functions/rental-recovery/index.ts';
import { createHandler as verifyHandler } from '../../supabase/functions/verify-payment/index.ts';

function assert(value: unknown, message: string): asserts value { if (!value) throw new Error(message); }
async function call(handler: (req: Request) => Promise<Response>, token: string, body: Record<string, unknown>) {
  const response = await handler(new Request('http://127.0.0.1/finance-test', {
    method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  }));
  return { code: response.status, data: await response.json() };
}

Deno.test('commercial finance: operator authority, partial dispute, private payout claim and single transfer', async () => {
  const f = await fixture();
  const pg = fakeProvider(), checkout = checkoutHandler(pg.factory), finance = financeHandler(pg.factory);
  const operatorToken = f.outsider.session.access_token;
  try {
    assert((await call(finance, operatorToken, { action: 'queue' })).code === 403, 'ordinary account read operator queue');
    checked(await f.outsider.client.auth.updateUser({ data: { dolpin_operator: true } }));
    assert((await call(finance, operatorToken, { action: 'queue' })).code === 403, 'user metadata escalated operator privilege');
    checked(await f.admin.auth.admin.updateUserById(f.outsider.id, { app_metadata: { dolpin_operator: true } }));
    const r = await f.rental();
    const prepared = await call(checkout, f.borrower.session.access_token, { action: 'prepare', reservationId: r.id });
    const params = new URLSearchParams(new URL(prepared.data.checkoutUrl).hash.slice(1));
    const approved = await call(checkout, f.borrower.session.access_token, {
      action: 'confirm', orderId: params.get('orderId'), token: params.get('token'), paymentKey: `qa-${r.id}`, amount: r.total_paid,
    });
    assert(approved.data.status === 'paid', 'fixture approval failed');
    const photoPath = `${r.id}/${f.borrower.id}/dispute.png`;
    checked(await f.borrower.client.storage.from('dispute-evidence').upload(photoPath, png, { contentType: 'image/png' }));
    assert((await f.outsider.client.storage.from('dispute-evidence').createSignedUrl(photoPath, 60)).error, 'unrelated account read evidence');
    checked(await f.borrower.client.rpc('open_rental_dispute', { p_reservation_id: r.id, p_reason: '인수 장소에 상대방이 나타나지 않았습니다.', p_evidence_paths: [photoPath] }));
    checked(await f.borrower.client.rpc('send_rental_message', { p_reservation_id: r.id, p_message: '2번 출구에서 기다리고 있습니다.', p_request_id: crypto.randomUUID() }));
    assert((await call(finance, f.borrower.session.access_token, { action: 'rental', reservationId: r.id })).code === 403, 'participant read privileged investigation');
    assert((await f.borrower.client.rpc('finance_rental_detail', { p_reservation_id: r.id, p_actor: f.outsider.id })).error, 'participant bypassed investigation Edge authority');
    const detail = await call(finance, operatorToken, { action: 'rental', reservationId: r.id });
    assert(detail.code === 200 && detail.data.reservation.id === r.id && detail.data.disputes.length === 1, 'investigation did not include case context');
    assert(detail.data.messages[0]?.message === '2번 출구에서 기다리고 있습니다.' && detail.data.reservation.terms_snapshot?.description === '수락 당시 설명', 'investigation lost messages or accepted terms');
    assert(!('payment_id' in detail.data.reservation) && !('token_hash' in detail.data.reservation), 'investigation disclosed payment credentials');
    assert(checked(await f.admin.from('finance_operator_audit').select('id').eq('reservation_id', r.id).eq('action', 'view_rental')).length === 1, 'investigation read was not audited');
    assert((await call(finance, operatorToken, { action: 'rental', reservationId: crypto.randomUUID() })).code === 404, 'missing investigation was not a safe not-found response');
    checked(await f.admin.from('users').update({ suspended_at: new Date().toISOString() }).eq('id', f.outsider.id));
    assert((await call(finance, operatorToken, { action: 'rental', reservationId: r.id })).code === 403, 'suspended operator retained investigation access');
    checked(await f.admin.from('users').update({ suspended_at: null }).eq('id', f.outsider.id));
    assert((await f.lender.client.rpc('confirm_rental_pickup', { p_reservation_id: r.id })).error, 'disputed rental allowed pickup');
    const body = { action: 'resolveDispute', reservationId: r.id, refundAmount: 32000, reason: '양측 증빙을 대조하여 부분 환불을 결정했습니다.' };
    assert((await call(finance, f.borrower.session.access_token, body)).code === 403, 'participant resolved their own dispute');
    const resolutions = await Promise.all([call(finance, operatorToken, body), call(finance, operatorToken, body)]);
    assert(resolutions.every((result) => result.code === 200), 'concurrent identical decision failed');
    assert(pg.cancelIds.length === 1, 'concurrent decisions sent duplicate refunds');
    assert((await call(finance, operatorToken, { ...body, refundAmount: 30000 })).code === 409, 'decision was mutated after dispatch');
    const payouts = checked(await f.lender.client.rpc('own_rental_payouts', {}));
    const payout = payouts.find((row: { reservation_id: string }) => row.reservation_id === r.id);
    assert(payout?.amount === r.total_paid - 32000 && payout.fee_amount === 0, 'payout did not match collected residual');
    assert(checked(await f.borrower.client.rpc('own_rental_payouts', {})).length === 0, 'borrower read lender payouts');
    assert((await f.borrower.client.from('payout_accounts').select('*')).error, 'private account table exposed');
    checked(await f.lender.client.rpc('save_payout_account', { p_bank_name: 'QA은행', p_account_number: '1234567890', p_holder_name: 'QA대여자' }));
    const capture = pg.payments.get(params.get('orderId')!)!;
    capture.refunded = capture.total; capture.status = 'cancelled';
    assert((await call(finance, operatorToken, { action: 'claimPayout', id: payout.id })).code === 409, 'externally cancelled capture released bank instructions');
    capture.refunded = 32000; capture.status = 'paid';
    const claim = await call(finance, operatorToken, { action: 'claimPayout', id: payout.id });
    assert(claim.code === 200 && claim.data.claimToken, 'payout claim failed');
    checked(await f.lender.client.rpc('save_payout_account', { p_bank_name: 'QA새은행', p_account_number: '9876543210', p_holder_name: 'QA대여자' }));
    const sameClaim = await call(finance, operatorToken, { action: 'claimPayout', id: payout.id });
    assert(sameClaim.data.claimToken === claim.data.claimToken && sameClaim.data.account.accountNumber === '1234567890', 'claim account changed after transfer instructions');
    const completion = { action: 'completePayout', id: payout.id, claimToken: claim.data.claimToken, transferReference: `bank-fixture-${r.id}` };
    assert((await call(finance, operatorToken, { ...completion, claimToken: crypto.randomUUID() })).code === 403, 'wrong claim completed payout');
    assert((await call(finance, operatorToken, { action: 'failPayout', id: payout.id, claimToken: claim.data.claimToken, reason: '은행 화면에서 송금 결과를 확인할 수 없습니다.' })).code === 200, 'unknown payout not held');
    assert((await call(finance, operatorToken, { action: 'retryPayout', id: payout.id, reason: '아직 송금 여부 미확인' })).code === 400, 'unknown transfer reset without verification');
    assert((await call(finance, operatorToken, completion)).data.status === 'paid', 'bank receipt did not complete held payout');
    assert((await call(finance, operatorToken, completion)).data.status === 'paid', 'completion retry was not idempotent');
    assert((await call(finance, operatorToken, { action: 'claimPayout', id: payout.id })).code === 409, 'completed payout reclaimed');
    assert((await call(finance, operatorToken, { action: 'evidenceUrl', path: photoPath })).code === 200, 'operator could not inspect case evidence');
    assert((await call(finance, operatorToken, { action: 'evidenceUrl', path: `${r.id}/${f.borrower.id}/unsubmitted.png` })).code === 404, 'operator signed unsubmitted evidence');
    assert(checked(await f.admin.from('finance_operator_audit').select('id').eq('reservation_id', r.id).eq('action', 'view_dispute_evidence')).length === 1, 'evidence access was not audited');
    checked(await f.admin.auth.admin.updateUserById(f.outsider.id, { app_metadata: { dolpin_operator: false } }));
    assert((await call(finance, operatorToken, { action: 'queue' })).code === 403, 'revoked operator retained authority');
  } finally { await f.cleanup(); }
});

Deno.test('operator investigation: same-time message pages and audited no-show escalation', async () => {
  const f = await fixture();
  const pg = fakeProvider(), finance = financeHandler(pg.factory);
  try {
    checked(await f.admin.auth.admin.updateUserById(f.outsider.id, { app_metadata: { dolpin_operator: true } }));
    const r = await f.rental();
    await localSql(`UPDATE public.reservations SET status='paid',payment_provider='portone',payment_id='qa-${r.id}' WHERE id='${r.id}';
      INSERT INTO public.chat_messages(reservation_id,sender_id,receiver_id,message,created_at)
      SELECT '${r.id}','${f.borrower.id}','${f.lender.id}','증빙 대화 '||n,now() FROM generate_series(1,101) n;
      INSERT INTO public.rental_operator_reviews(reservation_id,kind) VALUES('${r.id}','pickup_overdue');`);
    const token = f.outsider.session.access_token;
    const first = await call(finance, token, { action: 'rental', reservationId: r.id });
    assert(first.code === 200 && first.data.messages.length === 100 && first.data.messagesHasMore, 'bounded investigation message page missing');
    const last = first.data.messages.at(-1);
    const next = await call(finance, token, { action: 'rental', reservationId: r.id, messageBefore: { createdAt: last.created_at, id: last.id } });
    assert(next.code === 200 && next.data.messages.length === 1 && !next.data.messagesHasMore, 'same-time cursor skipped or duplicated messages');
    assert(!first.data.messages.some((m: { id: string }) => m.id === next.data.messages[0].id), 'message cursor repeated row');
    const review = checked(await f.admin.from('rental_operator_reviews').select('id').eq('reservation_id', r.id).single());
    const escalation = { action: 'escalateReview', id: review.id, note: '인수 기한 경과 및 양측의 연락 내역을 확인합니다.' };
    assert((await call(finance, token, escalation)).code === 200, 'operator could not escalate no-show');
    assert((await call(finance, token, escalation)).code === 200, 'identical escalation was not idempotent');
    const rental = checked(await f.admin.from('reservations').select('status').eq('id', r.id).single());
    assert(rental.status === 'disputed', 'escalation did not retain funds for review');
    const cases = checked(await f.borrower.client.from('rental_disputes').select('reporter_id,operator_id').eq('reservation_id', r.id));
    assert(cases.length === 1 && cases[0].reporter_id === null && cases[0].operator_id === f.outsider.id, 'operator case actor was invented as a participant');
    assert(checked(await f.admin.from('finance_operator_audit').select('id').eq('reservation_id', r.id).eq('action', 'escalate')).length === 1, 'escalation repeated side effect');
  } finally { await f.cleanup(); }
});

Deno.test('manual bank reconciliation: active owner, revoked operator and stale claim fencing', async () => {
  const f = await fixture();
  const pg = fakeProvider(), finance = financeHandler(pg.factory);
  try {
    for (const actor of [f.outsider, f.borrower]) {
      checked(await f.admin.auth.admin.updateUserById(actor.id, { app_metadata: { dolpin_operator: true } }));
    }
    const r = await f.rental();
    // A terminal legacy capture with a reconciled deposit and unpaid rental fee.
    await localSql(`UPDATE public.reservations SET status='settled',payment_provider='portone',payment_id='qa-${r.id}' WHERE id='${r.id}';
      INSERT INTO public.rental_payouts(reservation_id,lender_id,amount) VALUES('${r.id}','${f.lender.id}',${r.rental_fee});`);
    pg.payments.set(r.id, { id: `qa-${r.id}`, orderId: r.id, total: r.total_paid, currency: 'KRW', refunded: r.deposit, status: 'paid' });
    checked(await f.lender.client.rpc('save_payout_account', { p_bank_name: 'QA은행', p_account_number: '1234567890', p_holder_name: 'QA대여자' }));
    const payout = checked(await f.admin.from('rental_payouts').select('id').eq('reservation_id', r.id).single());
    const claim = await call(finance, f.outsider.session.access_token, { action: 'claimPayout', id: payout.id });
    assert(claim.code === 200, 'fixture claim failed');
    const restore = { action: 'reconcilePayout', id: payout.id, claimedAt: claim.data.payout.claimed_at, outcome: 'not_sent', reason: '이전 담당자 작업을 중단하고 은행 미송금 내역을 확인했습니다.' };
    assert((await call(finance, f.borrower.session.access_token, restore)).code === 409, 'active operator claim was stolen');
    checked(await f.admin.auth.admin.updateUserById(f.outsider.id, { app_metadata: { dolpin_operator: false } }));
    assert((await call(finance, f.borrower.session.access_token, restore)).data.status === 'pending', 'revoked operator stranded payout');
    const newClaim = await call(finance, f.borrower.session.access_token, { action: 'claimPayout', id: payout.id });
    assert(newClaim.code === 200 && newClaim.data.claimToken !== claim.data.claimToken, 'old transfer claim remained valid');
    assert((await call(finance, f.borrower.session.access_token, restore)).code === 409, 'stale investigation reset a newer claim');
    assert((await call(finance, f.borrower.session.access_token, { ...restore, action: 'retryPayout', verifiedNotSent: true })).code === 409, 'legacy retry bypassed the current bank claim fence');
    const receipt = { action: 'reconcilePayout', id: payout.id, claimedAt: newClaim.data.payout.claimed_at, outcome: 'paid', reason: '은행 이체 내역과 수취 계좌를 대조했습니다.', transferReference: `reconciled-${r.id}` };
    assert((await call(finance, f.borrower.session.access_token, receipt)).data.status === 'paid', 'bank receipt did not close recovered payout');
    assert((await call(finance, f.borrower.session.access_token, receipt)).data.status === 'paid', 'receipt retry was not idempotent');
    assert(checked(await f.admin.from('payout_audit').select('id').eq('payout_id', payout.id).eq('action', 'reconciled_paid')).length === 1, 'receipt retry duplicated audit mutation');
  } finally { await f.cleanup(); }
});

Deno.test('legacy verification: lost database response never triggers a refund; rejected captures enter review', async () => {
  const f = await fixture();
  const originalFetch = globalThis.fetch;
  let dropped = false;
  try {
    const r = await f.rental();
    const merchant = `dolpin_${r.id}_1`;
    await localSql(`UPDATE public.reservations SET status='pending',payment_attempt_merchant_uid='${merchant}' WHERE id='${r.id}';`);
    globalThis.fetch = async (input, init) => {
      const url = input instanceof Request ? input.url : String(input);
      if (url.includes('api.iamport.kr')) throw new Error('verification unexpectedly attempted a provider mutation');
      const response = await originalFetch(input, init);
      if (!dropped && url.endsWith('/rpc/mark_reservation_paid') && response.ok) {
        dropped = true;
        await response.arrayBuffer();
        return Response.json({ message: 'fixture committed response lost' }, { status: 503 });
      }
      return response;
    };
    let refunded = 0, providerStatus = 'paid', lookupCount = 0;
    const verify = verifyHandler(async id => {
      lookupCount++;
      return { imp_uid: id, merchant_uid: merchant, amount: r.total_paid, cancel_amount: refunded, currency: 'KRW', status: providerStatus };
    });
    const verified = await call(verify, f.borrower.session.access_token, { imp_uid: `qa-${r.id}` });
    assert(dropped && verified.code === 200 && verified.data.status === 'success', 'ambiguous committed verification did not reconcile its row');
    assert(checked(await f.admin.from('reservations').select('status,payment_id').eq('id', r.id).single()).status === 'paid', 'verification response failure undid captured payment');
    const rejected = await call(verify, f.borrower.session.access_token, { imp_uid: `duplicate-${r.id}` });
    assert(rejected.code === 409 && rejected.data.review_required === true, 'second captured payment was not held for review');
    assert(!('imp_uid' in rejected.data) && !('merchant_uid' in rejected.data), 'rejection leaked provider data');
    const captures = checked(await f.admin.from('legacy_payment_verifications').select('payment_reference,reason_code').eq('reservation_id', r.id));
    assert(captures.length === 1 && captures[0].reason_code === 'different_payment', 'unmatched capture was not persisted for reconciliation');
    assert(checked(await f.admin.from('rental_operator_reviews').select('id').eq('reservation_id', r.id).is('closed_at', null)).length === 1, 'legacy capture was absent from operations queue');
    await localSql(`UPDATE public.reservations SET status='accepted' WHERE id='${r.id}';`);
    assert((await call(verify, f.borrower.session.access_token, { imp_uid: `qa-${r.id}` })).code === 409, 'non-captured state with a matching payment key was reported paid');
    await localSql(`UPDATE public.reservations SET status='settled' WHERE id='${r.id}';`);
    assert((await call(verify, f.borrower.session.access_token, { imp_uid: `qa-${r.id}` })).code === 409, 'settlement was verified without its expected deposit refund');
    refunded = r.deposit;
    assert((await call(verify, f.borrower.session.access_token, { imp_uid: `qa-${r.id}` })).code === 200, 'matching terminal refund did not reconcile');
    await localSql(`UPDATE public.reservations SET status='cancelled' WHERE id='${r.id}';`);
    assert((await call(verify, f.borrower.session.access_token, { imp_uid: `qa-${r.id}` })).code === 409, 'partial refund was advertised as a cancelled rental');
    refunded = r.total_paid; providerStatus = 'cancelled';
    assert((await call(verify, f.borrower.session.access_token, { imp_uid: `qa-${r.id}` })).data.reservation_status === 'cancelled', 'matching full refund did not reconcile');
    checked(await f.admin.from('users').update({ deleted_at: new Date().toISOString() }).eq('id', f.borrower.id));
    const beforeDeletedRead = lookupCount;
    assert((await call(verify, f.borrower.session.access_token, { imp_uid: `qa-${r.id}` })).code === 403 && lookupCount === beforeDeletedRead, 'deleted account JWT reached provider verification');
  } finally { globalThis.fetch = originalFetch; await f.cleanup(); }
});

Deno.test('PortOne disputed payment: lost response is reconciled without repeating cancellation', async () => {
  const f = await fixture();
  const pg = fakeProvider(), finance = financeHandler(pg.factory);
  try {
    checked(await f.admin.auth.admin.updateUserById(f.outsider.id, { app_metadata: { dolpin_operator: true } }));
    const r = await f.rental();
    // No provider call: this fixture represents a captured legacy PortOne payment.
    await localSql(`UPDATE public.reservations SET status='paid',payment_provider='portone',payment_id='qa-${r.id}' WHERE id='${r.id}';`);
    pg.payments.set(r.id, { id: `qa-${r.id}`, orderId: r.id, total: r.total_paid, currency: 'KRW', refunded: 0, status: 'paid' });
    checked(await f.lender.client.rpc('open_rental_dispute', { p_reservation_id: r.id, p_reason: '차용자와 인수 조건 확인이 필요합니다.', p_evidence_paths: [] }));
    pg.loseNextCancel();
    const result = await call(finance, f.outsider.session.access_token, { action: 'resolveDispute', reservationId: r.id, refundAmount: 10000, reason: '합의한 금액을 차용자에게 환불합니다.' });
    assert(result.code === 502, 'lost provider response was advertised as complete');
    assert(checked(await f.admin.from('reservations').select('status,payment_action').eq('id', r.id).single()).payment_action === 'dispute_pending', 'unknown refund lost its hold');
    await localSql(`UPDATE public.rental_money_operations SET next_attempt_at=now() WHERE reservation_id='${r.id}';`);
    const recovery = recoveryHandler(pg.factory, async () => [r.id]);
    assert((await call(recovery, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {})).code === 200, 'dispute recovery failed');
    assert(checked(await f.admin.from('reservations').select('status').eq('id', r.id).single()).status === 'resolved', 'recovery did not resolve dispute');
    assert(pg.cancelIds.length === 1, 'PortOne refund was dispatched twice');
    const payouts = checked(await f.lender.client.rpc('own_rental_payouts', {}));
    assert(payouts.length === 1 && payouts[0].net_amount === r.total_paid - 10000, 'recovered resolution duplicated or mispriced payout');
  } finally { await f.cleanup(); }
});
