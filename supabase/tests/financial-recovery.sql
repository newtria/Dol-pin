BEGIN;
INSERT INTO public.users(id,phone,nickname,country,currency) VALUES
 ('11000000-0000-4000-8000-000000000001','toss-lender','toss lender','KR','KRW'),
 ('11000000-0000-4000-8000-000000000002','toss-borrower','toss borrower','KR','KRW');
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,pickup_method)
VALUES('21000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000001',
 'toss fixture','lightstick',ARRAY['https://example.invalid/fixture.png'],5000,30000,'KRW','direct');
UPDATE public.rental_items SET description='original terms',pickup_note='gate 2' WHERE id='21000000-0000-4000-8000-000000000001';
SELECT set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000002',true);
SELECT set_config('test.rental_id',(public.request_rental(
 '21000000-0000-4000-8000-000000000001',now()+interval '1 day',now()+interval '1 day 4 hours',
 (SELECT updated_at FROM public.rental_items WHERE id='21000000-0000-4000-8000-000000000001'),gen_random_uuid())).id::text,true);
SELECT set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',true);
SELECT public.respond_to_rental(current_setting('test.rental_id')::uuid,'accept');


DO $$
DECLARE r uuid:=current_setting('test.rental_id')::uuid; c public.toss_checkouts;
 lease1 uuid:=gen_random_uuid(); lease2 uuid:=gen_random_uuid(); op public.rental_money_operations;
BEGIN
 c:=public.prepare_toss_checkout(r,'11000000-0000-4000-8000-000000000002','first-window',false);
 PERFORM public.prepare_toss_checkout(r,'11000000-0000-4000-8000-000000000002','second-window',true);
 IF (SELECT count(*) FROM public.toss_checkout_sessions WHERE order_id=c.order_id)<>2 THEN RAISE EXCEPTION 'checkout windows were revoked'; END IF;
 IF NOT public.claim_toss_confirmation(c.order_id,lease1,'fixture-key') THEN RAISE EXCEPTION 'claim failed'; END IF;
 IF public.claim_toss_confirmation(c.order_id,lease2,'fixture-key') THEN RAISE EXCEPTION 'concurrent approval claim allowed'; END IF;
 PERFORM public.release_toss_confirmation(c.order_id,lease2);
 IF public.claim_toss_confirmation(c.order_id,lease2,'fixture-key') THEN RAISE EXCEPTION 'wrong lease released claim'; END IF;
 PERFORM public.record_rental_recovery_attempt('checkout',c.order_id,lease1,'UPSTREAM_UNAVAILABLE');
 PERFORM public.release_toss_confirmation(c.order_id,lease1);
 IF public.claim_toss_confirmation(c.order_id,lease2,'fixture-key')
 OR public.claim_toss_confirmation(c.order_id,lease2,NULL) THEN RAISE EXCEPTION 'checkout retry bypassed backoff'; END IF;
 UPDATE public.toss_checkouts SET next_attempt_at=clock_timestamp()-interval '1 second' WHERE order_id=c.order_id;
 IF NOT public.claim_toss_confirmation(c.order_id,lease2,'fixture-key') THEN RAISE EXCEPTION 'due checkout retry failed'; END IF;
 BEGIN
  PERFORM public.finish_toss_confirmation(c.order_id,'fixture-key',lease1);
  RAISE EXCEPTION 'old worker completed checkout after handoff';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='old worker completed checkout after handoff' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.fail_toss_confirmation(c.order_id,lease1);
  RAISE EXCEPTION 'old worker expired checkout after handoff';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='old worker expired checkout after handoff' THEN RAISE; END IF; END;
 UPDATE public.toss_checkouts SET lease_until=clock_timestamp()-interval '1 second' WHERE order_id=c.order_id;
 BEGIN
  PERFORM public.finish_toss_confirmation(c.order_id,'fixture-key',lease2);
  RAISE EXCEPTION 'expired worker completed checkout before handoff';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='expired worker completed checkout before handoff' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.fail_toss_confirmation(c.order_id,lease2);
  RAISE EXCEPTION 'expired worker expired checkout before handoff';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='expired worker expired checkout before handoff' THEN RAISE; END IF; END;
 PERFORM public.record_rental_recovery_attempt('checkout',c.order_id,lease2,'OUTCOME_PENDING',false,false);
 IF (SELECT last_error_code FROM public.toss_checkouts WHERE order_id=c.order_id)<>'UPSTREAM_UNAVAILABLE'
 THEN RAISE EXCEPTION 'expired worker overwrote recovery state'; END IF;
 IF NOT public.claim_toss_confirmation(c.order_id,lease1,'fixture-key') THEN RAISE EXCEPTION 'expired checkout not reclaimed'; END IF;
 UPDATE public.reservations SET payment_attempt_merchant_uid='different-order' WHERE id=r;
 BEGIN
  PERFORM public.fail_toss_confirmation(c.order_id,lease1);
  RAISE EXCEPTION 'checkout expired another payment attempt';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='checkout expired another payment attempt' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.finish_toss_confirmation(c.order_id,'fixture-key',lease1);
  RAISE EXCEPTION 'checkout replaced another payment attempt';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='checkout replaced another payment attempt' THEN RAISE; END IF; END;
 UPDATE public.reservations SET payment_attempt_merchant_uid=c.order_id WHERE id=r;
 PERFORM public.finish_toss_confirmation(c.order_id,'fixture-key',lease1);
 IF public.fail_toss_confirmation(c.order_id,lease1)<>'paid' THEN RAISE EXCEPTION 'late failure reported false expiry'; END IF;
 IF public.claim_toss_confirmation(c.order_id,lease2,'fixture-key') THEN RAISE EXCEPTION 'completed checkout claimed PG work'; END IF;
 op:=public.begin_rental_money_operation(r,'11000000-0000-4000-8000-000000000002','refund');
 IF (public.begin_rental_money_operation(r,'11000000-0000-4000-8000-000000000001','refund')).id<>op.id THEN RAISE EXCEPTION 'retry changed financial intent'; END IF;
 IF (public.claim_rental_money_operation(op.id,lease1)).id IS NULL THEN RAISE EXCEPTION 'initial money claim failed'; END IF;
 PERFORM public.record_rental_recovery_attempt('money',op.id::text,lease1,'UPSTREAM_UNAVAILABLE');
 PERFORM public.release_rental_money_operation(op.id,lease1);
 IF (public.claim_rental_money_operation(op.id,lease2)).id IS NOT NULL THEN RAISE EXCEPTION 'money retry bypassed backoff'; END IF;
 UPDATE public.rental_money_operations SET next_attempt_at=clock_timestamp()-interval '1 second' WHERE id=op.id;
 IF (public.claim_rental_money_operation(op.id,lease2)).id IS NULL THEN RAISE EXCEPTION 'due money retry failed'; END IF;
 BEGIN
  PERFORM public.finish_rental_money_operation(op.id,lease1);
  RAISE EXCEPTION 'old worker completed money operation after handoff';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='old worker completed money operation after handoff' THEN RAISE; END IF; END;
 UPDATE public.rental_money_operations SET lease_until=clock_timestamp()-interval '1 second' WHERE id=op.id;
 BEGIN
  PERFORM public.finish_rental_money_operation(op.id,lease2);
  RAISE EXCEPTION 'expired worker completed money operation before handoff';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='expired worker completed money operation before handoff' THEN RAISE; END IF; END;
 PERFORM set_config('app.rental_money_operation_id','',true);
 BEGIN
  PERFORM public.clear_reservation_payment_action(r,'refund_pending');
  RAISE EXCEPTION 'legacy command erased a durable intent';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='legacy command erased a durable intent' THEN RAISE; END IF;
 END;
 UPDATE public.reservations SET payment_action_started_at=now()-interval '11 minutes' WHERE id=r;
 UPDATE public.rental_items SET description='changed terms',pickup_note='gate 9' WHERE id='21000000-0000-4000-8000-000000000001';
 IF (SELECT terms_snapshot->>'description' FROM public.reservations WHERE id=r)<>'original terms'
 OR (SELECT terms_snapshot->>'pickup_note' FROM public.reservations WHERE id=r)<>'gate 2' THEN RAISE EXCEPTION 'accepted terms changed'; END IF;
 IF has_function_privilege('authenticated','public.finish_rental_money_operation(uuid,uuid)','EXECUTE')
 OR has_table_privilege('authenticated','public.rental_money_operations','UPDATE') THEN RAISE EXCEPTION 'money authority leaked'; END IF;
END $$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE result jsonb; BEGIN
 result:=public.transition_reservation_status(current_setting('test.rental_id')::uuid,'picked_up');
 IF result->>'ok'<>'false' THEN RAISE EXCEPTION 'stale financial intent allowed pickup'; END IF;
 IF (SELECT payment_action FROM public.reservations WHERE id=current_setting('test.rental_id')::uuid) IS NULL THEN RAISE EXCEPTION 'unknown financial intent was erased'; END IF;
END $$;
ROLLBACK;
SELECT 'financial intent retention, capability isolation, lease fencing, snapshot immutability and authority passed' AS result;
