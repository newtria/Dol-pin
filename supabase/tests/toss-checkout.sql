BEGIN;
INSERT INTO public.users(id,phone,nickname,country,currency) VALUES
 ('11000000-0000-4000-8000-000000000001','toss-lender','toss lender','KR','KRW'),
 ('11000000-0000-4000-8000-000000000002','toss-borrower','toss borrower','KR','KRW');
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,pickup_method)
VALUES('21000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000001',
 'toss fixture','lightstick',ARRAY['https://example.invalid/fixture.png'],5000,30000,'KRW','direct');
SELECT set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000002',true);
SELECT set_config('test.rental_id',(public.request_rental(
 '21000000-0000-4000-8000-000000000001',now()+interval '1 day',now()+interval '1 day 4 hours',
 (SELECT updated_at FROM public.rental_items WHERE id='21000000-0000-4000-8000-000000000001'),gen_random_uuid())).id::text,true);
SELECT set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',true);
SELECT public.respond_to_rental(current_setting('test.rental_id')::uuid,'accept');

DO $$ DECLARE c public.toss_checkouts; r uuid := current_setting('test.rental_id')::uuid; lease uuid:=gen_random_uuid(); BEGIN
 BEGIN
  PERFORM public.prepare_toss_checkout(r,'11000000-0000-4000-8000-000000000001','hash',false);
  RAISE EXCEPTION 'lender was allowed to pay';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 c:=public.prepare_toss_checkout(r,'11000000-0000-4000-8000-000000000002','hash',false);
 IF c.amount<>(SELECT total_paid FROM public.reservations WHERE id=r) THEN RAISE EXCEPTION 'amount not server owned'; END IF;
 IF NOT public.claim_toss_confirmation(c.order_id,lease,NULL) THEN RAISE EXCEPTION 'initial lookup claim failed'; END IF;
 PERFORM public.record_rental_recovery_attempt('checkout',c.order_id,lease,'OUTCOME_PENDING',false,false);
 PERFORM public.release_toss_confirmation(c.order_id,lease);
 IF NOT public.claim_toss_confirmation(c.order_id,lease,'test_payment') THEN RAISE EXCEPTION 'initial checkout claim failed'; END IF;
 UPDATE public.reservations SET payment_due_at=now()-interval '1 minute' WHERE id=r;
 PERFORM public.expire_unpaid_rentals();
 IF (SELECT status FROM public.reservations WHERE id=r)<>'accepted' THEN RAISE EXCEPTION 'lost unknown payment'; END IF;
 PERFORM public.begin_toss_confirmation(c.order_id);
 PERFORM public.finish_toss_confirmation(c.order_id,'test_payment',lease);
 PERFORM public.finish_toss_confirmation(c.order_id,'test_payment',lease);
 IF (SELECT status FROM public.reservations WHERE id=r)<>'paid' OR
 (SELECT count(*) FROM public.rental_events WHERE reservation_id=r AND command='confirmTossPayment')<>1 THEN RAISE EXCEPTION 'not idempotent'; END IF;
 BEGIN
  PERFORM public.finish_toss_confirmation(c.order_id,'different_payment',lease);
  RAISE EXCEPTION 'duplicate charge accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='duplicate charge accepted' THEN RAISE; END IF; END;
 IF has_function_privilege('authenticated','public.finish_toss_confirmation(text,text,uuid)','EXECUTE')
 OR has_function_privilege('authenticated','public.fail_toss_confirmation(text,uuid)','EXECUTE')
 OR has_function_privilege('anon','public.prepare_toss_checkout(uuid,uuid,text,boolean)','EXECUTE')
 OR has_table_privilege('authenticated','public.toss_checkouts','SELECT') THEN RAISE EXCEPTION 'checkout privilege leak'; END IF;
 IF to_regprocedure('public.finish_toss_confirmation(text,text)') IS NOT NULL
 OR to_regprocedure('public.fail_toss_confirmation(text)') IS NOT NULL THEN RAISE EXCEPTION 'unfenced legacy completion remains'; END IF;
END $$;
ROLLBACK;
SELECT 'Toss borrower authorization, authoritative amount, expiry safety, idempotency and privileges passed' AS result;
