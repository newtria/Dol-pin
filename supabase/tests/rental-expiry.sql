BEGIN;
INSERT INTO public.users(id,phone,nickname,country,currency) VALUES
 ('11000000-0000-4000-8000-000000000001','expiry-lender','expiry lender','KR','KRW'),
 ('11000000-0000-4000-8000-000000000002','expiry-borrower','expiry borrower','KR','KRW');
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,pickup_method)
VALUES('21000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000001',
 'expiry fixture','lightstick',ARRAY['https://example.invalid/fixture.png'],5000,30000,'KRW','direct');
SELECT set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000002',true);
SELECT set_config('test.rental_id',(public.request_rental(
 '21000000-0000-4000-8000-000000000001',now()+interval '1 day',now()+interval '1 day 4 hours',
 (SELECT updated_at FROM public.rental_items WHERE id='21000000-0000-4000-8000-000000000001'),gen_random_uuid())).id::text,true);
SELECT set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',true);
SELECT public.respond_to_rental(current_setting('test.rental_id')::uuid,'accept');
UPDATE public.reservations SET payment_due_at=now()-interval '1 minute',
 payment_attempt_merchant_uid='unknown-provider-result',payment_attempt_started_at=now()-interval '1 hour'
 WHERE id=current_setting('test.rental_id')::uuid;
SELECT public.expire_unpaid_rentals();
DO $$ BEGIN
 IF (SELECT status FROM public.reservations WHERE id=current_setting('test.rental_id')::uuid) <> 'accepted' THEN
   RAISE EXCEPTION 'unknown financial result released inventory';
 END IF;
END $$;
-- Fixture-only simulation of reconciliation proving no payment occurred.
UPDATE public.reservations SET payment_attempt_merchant_uid=NULL,payment_attempt_started_at=NULL
 WHERE id=current_setting('test.rental_id')::uuid;
SELECT public.expire_unpaid_rentals();
SELECT public.expire_unpaid_rentals();
DO $$ BEGIN
 IF (SELECT status FROM public.reservations WHERE id=current_setting('test.rental_id')::uuid) <> 'expired' THEN
   RAISE EXCEPTION 'unpaid accepted rental did not expire';
 END IF;
 IF (SELECT count(*) FROM public.rental_events WHERE reservation_id=current_setting('test.rental_id')::uuid AND command='expireRental') <> 1 THEN
   RAISE EXCEPTION 'expiry event must be written once';
 END IF;
END $$;
ROLLBACK;
SELECT 'expiry preserves unknown payment attempts and completes once' AS result;
