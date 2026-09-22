-- Run against isolated local Supabase with psql -v ON_ERROR_STOP=1.
-- Fixtures are rolled back. This test never calls a payment provider.
BEGIN;

INSERT INTO public.users(id,phone,nickname,country,currency) VALUES
 ('14000000-0000-4000-8000-000000000001','private-item-lender','private item lender','KR','KRW'),
 ('14000000-0000-4000-8000-000000000002','private-item-borrower','private item borrower','KR','KRW'),
 ('14000000-0000-4000-8000-000000000003','private-item-outsider','private item outsider','KR','KRW');
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,
 pickup_method,pickup_area,pickup_note,pickup_location,imei)
VALUES('24000000-0000-4000-8000-000000000001','14000000-0000-4000-8000-000000000001',
 'private item fixture','lightstick',ARRAY['https://example.invalid/fixture.png'],5000,30000,'KRW',
 'direct','공연장 인근','수락 당시 전용 장소','{"address":"private fixture address"}', 'private-device-id');

SET LOCAL ROLE anon;
DO $$
DECLARE field text; area text;
BEGIN
 SELECT pickup_area INTO STRICT area FROM public.rental_items
 WHERE id='24000000-0000-4000-8000-000000000001';
 IF area IS DISTINCT FROM '공연장 인근' THEN RAISE EXCEPTION 'public meeting area unavailable'; END IF;
 FOREACH field IN ARRAY ARRAY['pickup_note','pickup_location','imei'] LOOP
  BEGIN
   EXECUTE format('SELECT %I FROM public.rental_items WHERE id=$1',field)
    USING '24000000-0000-4000-8000-000000000001'::uuid;
   RAISE EXCEPTION 'anonymous private column read allowed: %',field;
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
 END LOOP;
 BEGIN
  PERFORM * FROM public.rental_items WHERE id='24000000-0000-4000-8000-000000000001';
  RAISE EXCEPTION 'anonymous wildcard read allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  PERFORM to_jsonb(i) FROM public.rental_items i WHERE id='24000000-0000-4000-8000-000000000001';
  RAISE EXCEPTION 'anonymous whole-row JSON read allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  PERFORM public.own_item_pickup_note('24000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'anonymous owner RPC allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000003',true);
DO $$
DECLARE field text;
BEGIN
 FOREACH field IN ARRAY ARRAY['pickup_note','pickup_location','imei'] LOOP
  BEGIN
   EXECUTE format('SELECT %I FROM public.rental_items WHERE id=$1',field)
    USING '24000000-0000-4000-8000-000000000001'::uuid;
   RAISE EXCEPTION 'non-owner private column read allowed: %',field;
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
 END LOOP;
 BEGIN
  PERFORM public.own_item_pickup_note('24000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'non-owner owner RPC allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;

SELECT set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE created_id uuid; public_area text;
BEGIN
 IF public.own_item_pickup_note('24000000-0000-4000-8000-000000000001') IS DISTINCT FROM '수락 당시 전용 장소' THEN
  RAISE EXCEPTION 'owner could not read private instructions through RPC';
 END IF;
 BEGIN
  PERFORM pickup_note FROM public.rental_items WHERE id='24000000-0000-4000-8000-000000000001';
  RAISE EXCEPTION 'owner direct private-column read must use RPC';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 -- Product authoring must still work with public RETURNING columns, even
 -- though detailed directions are a private INSERT field.
 INSERT INTO public.rental_items(lender_id,title,category,photos,daily_price,deposit,currency,
  pickup_method,pickup_area,pickup_note)
 VALUES('14000000-0000-4000-8000-000000000001','owner created fixture','lightstick',
  ARRAY['https://example.invalid/fixture.png'],5000,30000,'KRW','direct','역 인근','상대방 전용 안내')
 RETURNING id,pickup_area INTO created_id,public_area;
 IF created_id IS NULL OR public_area IS DISTINCT FROM '역 인근'
  OR public.own_item_pickup_note(created_id) IS DISTINCT FROM '상대방 전용 안내' THEN
  RAISE EXCEPTION 'owner create/public projection contract failed';
 END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000002',true);
SELECT set_config('test.private_item_rental_id',(public.request_rental(
 '24000000-0000-4000-8000-000000000001',now()+interval '7 days',now()+interval '7 days 4 hours',
 (SELECT updated_at FROM public.rental_items WHERE id='24000000-0000-4000-8000-000000000001'),
 gen_random_uuid())).id::text,true);
DO $$
DECLARE snapshot jsonb;
BEGIN
 SELECT terms_snapshot INTO snapshot FROM public.reservations
 WHERE id=current_setting('test.private_item_rental_id')::uuid;
 IF snapshot IS NOT NULL THEN RAISE EXCEPTION 'unaccepted request exposed private terms'; END IF;
 BEGIN
  PERFORM public.own_item_pickup_note('24000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'requesting borrower read current owner instructions';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;

SELECT set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000001',true);
SELECT public.respond_to_rental(current_setting('test.private_item_rental_id')::uuid,'accept');
UPDATE public.rental_items SET pickup_note='수락 이후 수정된 안내'
 WHERE id='24000000-0000-4000-8000-000000000001';
DO $$ BEGIN
 IF public.own_item_pickup_note('24000000-0000-4000-8000-000000000001') IS DISTINCT FROM '수락 이후 수정된 안내' THEN
  RAISE EXCEPTION 'owner private instruction update unavailable';
 END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE snapshot jsonb;
BEGIN
 SELECT terms_snapshot INTO STRICT snapshot FROM public.reservations
 WHERE id=current_setting('test.private_item_rental_id')::uuid;
 IF snapshot->>'pickup_note' IS DISTINCT FROM '수락 당시 전용 장소'
  OR snapshot->'pickup_location'->>'address' IS DISTINCT FROM 'private fixture address' THEN
  RAISE EXCEPTION 'accepted borrower did not receive frozen private terms';
 END IF;
 IF snapshot ? 'imei' THEN RAISE EXCEPTION 'device identifier leaked into rental snapshot'; END IF;
 BEGIN
  PERFORM public.own_item_pickup_note('24000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'accepted borrower read current owner instructions';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;

SELECT set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000003',true);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.reservations WHERE id=current_setting('test.private_item_rental_id')::uuid) THEN
  RAISE EXCEPTION 'outsider read accepted private terms';
 END IF;
END $$;

ROLLBACK;
SELECT 'private item columns, owner command and accepted snapshot isolation passed' AS result;
