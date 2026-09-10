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
 PERFORM public.release_toss_confirmation(c.order_id,lease1);
 PERFORM public.finish_toss_confirmation(c.order_id,'fixture-key');
 op:=public.begin_rental_money_operation(r,'11000000-0000-4000-8000-000000000002','refund');
 IF (public.begin_rental_money_operation(r,'11000000-0000-4000-8000-000000000001','refund')).id<>op.id THEN RAISE EXCEPTION 'retry changed financial intent'; END IF;
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
