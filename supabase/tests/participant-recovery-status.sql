-- Run with psql -v ON_ERROR_STOP=1 against isolated local Supabase.
-- Read-only participant DTO assertions; all fixture changes are rolled back.
BEGIN;
INSERT INTO public.users(id,phone,nickname,country,currency) VALUES
 ('15000000-0000-4000-8000-000000000001','status-lender','status lender','KR','KRW'),
 ('15000000-0000-4000-8000-000000000002','status-borrower','status borrower','KR','KRW'),
 ('15000000-0000-4000-8000-000000000003','status-outsider','status outsider','KR','KRW');
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,pickup_method)
VALUES('25000000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000001',
 'status fixture','lightstick',ARRAY['https://example.invalid/fixture.png'],5000,30000,'KRW','direct');
SELECT set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000002',true);
SELECT set_config('test.status_rental_id',(public.request_rental(
 '25000000-0000-4000-8000-000000000001',now()+interval '7 days',now()+interval '7 days 4 hours',
 (SELECT updated_at FROM public.rental_items WHERE id='25000000-0000-4000-8000-000000000001'),gen_random_uuid())).id::text,true);
SELECT set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000001',true);
SELECT public.respond_to_rental(current_setting('test.status_rental_id')::uuid,'accept');
SELECT set_config('test.status_order_id',(public.prepare_toss_checkout(
 current_setting('test.status_rental_id')::uuid,'15000000-0000-4000-8000-000000000002','private-capability-hash',false)).order_id,true);

SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN
  PERFORM * FROM public.rental_recovery_status(current_setting('test.status_rental_id')::uuid);
  RAISE EXCEPTION 'anonymous caller read recovery status';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000003',true);
DO $$ BEGIN
 BEGIN
  PERFORM * FROM public.rental_recovery_status(current_setting('test.status_rental_id')::uuid);
  RAISE EXCEPTION 'outsider read recovery status';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  PERFORM * FROM public.rental_recovery_status('ffffffff-ffff-4fff-8fff-ffffffffffff');
  RAISE EXCEPTION 'unknown reservation was exposed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
SELECT set_config('request.jwt.claim.sub','',true);
DO $$ BEGIN
 BEGIN
  PERFORM * FROM public.rental_recovery_status(current_setting('test.status_rental_id')::uuid);
  RAISE EXCEPTION 'missing authenticated subject read recovery status';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
SELECT set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE result jsonb;
BEGIN
 SELECT to_jsonb(s) INTO STRICT result FROM public.rental_recovery_status(current_setting('test.status_rental_id')::uuid) s;
 IF result->>'state' IS DISTINCT FROM 'idle' OR result->>'next_retry_at' IS NOT NULL
  OR result->>'reference' IS DISTINCT FROM current_setting('test.status_rental_id') THEN
  RAISE EXCEPTION 'borrower idle status contract failed: %',result;
 END IF;
 IF (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(result) keys(k))
  IS DISTINCT FROM ARRAY['next_retry_at','reference','state'] THEN
  RAISE EXCEPTION 'recovery DTO exposed extra provider fields';
 END IF;
END $$;

RESET ROLE;
-- An untracked financial hold needs an operator, not an automatic-work promise.
UPDATE public.reservations SET payment_action='refund_pending',payment_action_started_at=clock_timestamp()
 WHERE id=current_setting('test.status_rental_id')::uuid;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF (SELECT state FROM public.rental_recovery_status(current_setting('test.status_rental_id')::uuid)) IS DISTINCT FROM 'needs_review' THEN
  RAISE EXCEPTION 'untracked money hold was advertised as automatic recovery';
 END IF;
END $$;
RESET ROLE;
UPDATE public.reservations SET payment_action=NULL,payment_action_started_at=NULL
 WHERE id=current_setting('test.status_rental_id')::uuid;
SELECT public.begin_toss_confirmation(current_setting('test.status_order_id'));
UPDATE public.toss_checkouts SET payment_key='private-payment-key',last_error_code='RAW_PROVIDER_SECRET',
 next_attempt_at=clock_timestamp()+interval '10 minutes',lease_until=NULL,lease_token=NULL
 WHERE order_id=current_setting('test.status_order_id');
SET LOCAL ROLE authenticated;
DO $$
DECLARE result jsonb;
BEGIN
 SELECT to_jsonb(s) INTO STRICT result FROM public.rental_recovery_status(current_setting('test.status_rental_id')::uuid) s;
 IF result->>'state' IS DISTINCT FROM 'retry_scheduled' OR result->>'next_retry_at' IS NULL THEN
  RAISE EXCEPTION 'checkout retry was not scheduled: %',result;
 END IF;
 IF result::text LIKE '%private-payment-key%' OR result::text LIKE '%private-capability-hash%'
  OR result::text LIKE '%RAW_PROVIDER_SECRET%'
  OR (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(result) keys(k)) IS DISTINCT FROM ARRAY['next_retry_at','reference','state'] THEN
  RAISE EXCEPTION 'checkout provider details leaked through status DTO';
 END IF;
 BEGIN
  PERFORM payment_key FROM public.toss_checkouts WHERE order_id=current_setting('test.status_order_id');
  RAISE EXCEPTION 'participant read raw checkout payment key';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
RESET ROLE;
UPDATE public.toss_checkouts SET lease_until=clock_timestamp()+interval '1 minute',lease_token=gen_random_uuid()
 WHERE order_id=current_setting('test.status_order_id');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE result record;
BEGIN
 SELECT * INTO STRICT result FROM public.rental_recovery_status(current_setting('test.status_rental_id')::uuid);
 IF result.state IS DISTINCT FROM 'processing' OR result.next_retry_at IS NOT NULL THEN
  RAISE EXCEPTION 'live checkout lease must take priority over retry clock';
 END IF;
END $$;
RESET ROLE;
UPDATE public.toss_checkouts SET review_required_at=clock_timestamp() WHERE order_id=current_setting('test.status_order_id');
SET LOCAL ROLE authenticated;
DO $$
DECLARE result record;
BEGIN
 SELECT * INTO STRICT result FROM public.rental_recovery_status(current_setting('test.status_rental_id')::uuid);
 IF result.state IS DISTINCT FROM 'needs_review' OR result.next_retry_at IS NOT NULL THEN
  RAISE EXCEPTION 'review must stop the automatic-work promise despite a live lease';
 END IF;
END $$;
RESET ROLE;
UPDATE public.toss_checkouts SET review_required_at=NULL,lease_until=NULL,lease_token=NULL,next_attempt_at=clock_timestamp()-interval '1 second'
 WHERE order_id=current_setting('test.status_order_id');
UPDATE public.reservations SET payment_attempt_merchant_uid='different-untracked-order'
 WHERE id=current_setting('test.status_rental_id')::uuid;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF (SELECT state FROM public.rental_recovery_status(current_setting('test.status_rental_id')::uuid)) IS DISTINCT FROM 'needs_review' THEN
  RAISE EXCEPTION 'checkout of a different attempt was presented as automatic recovery';
 END IF;
END $$;
RESET ROLE;
UPDATE public.reservations SET payment_attempt_merchant_uid=current_setting('test.status_order_id')
 WHERE id=current_setting('test.status_rental_id')::uuid;
DO $$
DECLARE lease uuid:=gen_random_uuid();
BEGIN
 IF NOT public.claim_toss_confirmation(current_setting('test.status_order_id'),lease,'private-payment-key') THEN
  RAISE EXCEPTION 'fixture checkout claim failed';
 END IF;
 PERFORM public.finish_toss_confirmation(current_setting('test.status_order_id'),'private-payment-key',lease);
END $$;
SELECT set_config('test.status_money_id',(public.begin_rental_money_operation(
 current_setting('test.status_rental_id')::uuid,'15000000-0000-4000-8000-000000000002','refund')).id::text,true);
UPDATE public.rental_money_operations SET next_attempt_at=clock_timestamp()+interval '10 minutes',last_error_code='RAW_PROVIDER_SECRET'
 WHERE id=current_setting('test.status_money_id')::uuid;
SET LOCAL ROLE authenticated;
DO $$
DECLARE result jsonb;
BEGIN
 SELECT to_jsonb(s) INTO STRICT result FROM public.rental_recovery_status(current_setting('test.status_rental_id')::uuid) s;
 IF result->>'state' IS DISTINCT FROM 'retry_scheduled' OR result->>'next_retry_at' IS NULL THEN
  RAISE EXCEPTION 'money retry was not scheduled';
 END IF;
 IF (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(result) keys(k)) IS DISTINCT FROM ARRAY['next_retry_at','reference','state']
  OR result::text LIKE '%private-payment-key%' OR result::text LIKE '%RAW_PROVIDER_SECRET%' THEN
  RAISE EXCEPTION 'money provider details leaked through status DTO';
 END IF;
END $$;
RESET ROLE;
UPDATE public.rental_money_operations SET lease_until=clock_timestamp()+interval '1 minute',lease_token=gen_random_uuid()
 WHERE id=current_setting('test.status_money_id')::uuid;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF (SELECT state FROM public.rental_recovery_status(current_setting('test.status_rental_id')::uuid)) IS DISTINCT FROM 'processing' THEN
  RAISE EXCEPTION 'live money lease was not processing';
 END IF;
END $$;
RESET ROLE;
UPDATE public.rental_money_operations SET review_required_at=clock_timestamp() WHERE id=current_setting('test.status_money_id')::uuid;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF (SELECT state FROM public.rental_recovery_status(current_setting('test.status_rental_id')::uuid)) IS DISTINCT FROM 'needs_review' THEN
  RAISE EXCEPTION 'money review was not visible to participant';
 END IF;
END $$;

ROLLBACK;
SELECT 'participant recovery states, authorization and provider-secret isolation passed' AS result;
