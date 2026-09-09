-- Real Postgres/RLS baseline. Fixtures are rolled back; no provider is called.
-- Run with psql -v ON_ERROR_STOP=1 against an isolated local Supabase database.
BEGIN;

INSERT INTO public.users (id, phone, nickname, country, currency) VALUES
 ('10000000-0000-4000-8000-000000000001', 'fixture-lender', '대여자 fixture', 'KR', 'KRW'),
 ('10000000-0000-4000-8000-000000000002', 'fixture-borrower', '차용자 fixture', 'KR', 'KRW'),
 ('10000000-0000-4000-8000-000000000003', 'fixture-outsider', '외부인 fixture', 'KR', 'KRW');

INSERT INTO public.rental_items
 (id, lender_id, category, title, photos, daily_price, currency, deposit, pickup_method)
VALUES
 ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
  'lightstick', '콘서트 응원봉 fixture', ARRAY['https://example.invalid/fixture.png'], 10000, 'KRW', 30000, 'direct');

SELECT set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
SELECT set_config('test.reservation_id',
 (public.create_reservation_intent('20000000-0000-4000-8000-000000000001',
 CURRENT_DATE + 1, CURRENT_DATE + 3)).id::text, true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE r public.reservations%ROWTYPE; changed integer; result jsonb;
BEGIN
 SELECT * INTO STRICT r FROM public.reservations
 WHERE id = current_setting('test.reservation_id')::uuid;
 IF r.total_paid <> 50000 OR r.rental_fee <> 20000 OR r.deposit <> 30000 THEN
   RAISE EXCEPTION 'server quote invariant failed';
 END IF;
 BEGIN
   UPDATE public.reservations SET status = 'picked_up' WHERE id = r.id;
   GET DIAGNOSTICS changed = ROW_COUNT;
   IF changed <> 0 THEN RAISE EXCEPTION 'direct status mutation was allowed'; END IF;
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 result := public.transition_reservation_status(r.id, 'picked_up');
 IF result->>'ok' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'unpaid pickup was allowed'; END IF;
 BEGIN
   PERFORM public.create_reservation_intent(r.item_id, CURRENT_DATE + 1, CURRENT_DATE + 3);
   RAISE EXCEPTION 'legacy creation bypass was allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;

SELECT set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
DO $$
DECLARE result jsonb;
BEGIN
 IF EXISTS (SELECT 1 FROM public.reservations WHERE id = current_setting('test.reservation_id')::uuid) THEN
   RAISE EXCEPTION 'outsider read was allowed';
 END IF;
 result := public.transition_reservation_status(current_setting('test.reservation_id')::uuid, 'cancelled');
 IF result->>'ok' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'outsider transition was allowed'; END IF;
END $$;

RESET ROLE;
SET LOCAL ROLE service_role;
SELECT public.mark_reservation_paid(current_setting('test.reservation_id')::uuid, 'fixture-payment', 'portone');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
DO $$
DECLARE result jsonb;
BEGIN
 result := public.transition_reservation_status(current_setting('test.reservation_id')::uuid, 'picked_up');
 IF result->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'paid lender pickup failed: %', result; END IF;
END $$;
ROLLBACK;
SELECT 'legacy authority baseline passed' AS result;
