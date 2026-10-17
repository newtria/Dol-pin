BEGIN;
INSERT INTO public.users(id,nickname,country) VALUES
 ('75000000-0000-4000-8000-000000000001','catalogue lender','KR'),
 ('75000000-0000-4000-8000-000000000002','catalogue borrower','KR'),
 ('75000000-0000-4000-8000-000000000003','catalogue suspended','KR');
UPDATE public.users SET suspended_at=now() WHERE id='75000000-0000-4000-8000-000000000003';
SELECT set_config('test.catalogue_start',(now()+interval '7 days')::text,true);
SELECT set_config('test.catalogue_end',(now()+interval '7 days 4 hours')::text,true);

-- More than one page of occupied inventory must not hide later matches.
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,
 pickup_method,pickup_area,pickup_note,imei,created_at)
SELECT md5('catalogue-'||n)::uuid,'75000000-0000-4000-8000-000000000001',
 'catalogue fixture '||CASE WHEN n<=60 THEN 'busy ' ELSE 'free ' END||n,'lightstick',
 ARRAY['https://example.invalid/catalogue.png'],5000,30000,'KRW','direct','잠실역 인근','비공개 상세 주소','private-imei',
 CASE WHEN n<=60 THEN now() ELSE now()-interval '1 day' END FROM generate_series(1,115) n;
INSERT INTO public.reservations(item_id,lender_id,borrower_id,rental_date,return_date,starts_at,ends_at,
 rental_fee,deposit,total_paid,currency,status,client_request_id,quoted_item_version,accepted_at,payment_due_at,terms_snapshot,
 payment_attempt_merchant_uid)
SELECT i.id,i.lender_id,'75000000-0000-4000-8000-000000000002',
 (current_setting('test.catalogue_start')::timestamptz AT TIME ZONE 'Asia/Seoul')::date,
 (current_setting('test.catalogue_end')::timestamptz AT TIME ZONE 'Asia/Seoul')::date,
 current_setting('test.catalogue_start')::timestamptz,current_setting('test.catalogue_end')::timestamptz,
 5000,30000,35000,'KRW',
 (ARRAY['pending','accepted','paid','picked_up','returned','disputed'])[1+n%6]::public.reservation_status,
 gen_random_uuid(),i.updated_at,now()-interval '1 hour',now()-interval '30 minutes','{}',
 CASE WHEN n%6=1 THEN 'unresolved-checkout-'||n ELSE NULL END
 FROM generate_series(1,60) n JOIN public.rental_items i ON i.id=md5('catalogue-'||n)::uuid;

INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,pickup_method,pickup_area,
 available_from,available_to,status,moderated_at)
SELECT md5('catalogue-excluded-'||n)::uuid,
 CASE WHEN n=3 THEN '75000000-0000-4000-8000-000000000003' ELSE '75000000-0000-4000-8000-000000000001' END::uuid,
 'catalogue excluded '||n,'lightstick',ARRAY['https://example.invalid/catalogue.png'],5000,30000,'KRW','direct','잠실역 인근',
 CASE WHEN n=4 THEN (now()+interval '9 days')::date END,
 CASE WHEN n=5 THEN (now()+interval '1 day')::date END,
 CASE WHEN n=1 THEN 'hidden' ELSE 'active' END,CASE WHEN n=2 THEN now() END FROM generate_series(1,5) n;
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,pickup_method,pickup_area,created_at)
SELECT md5('catalogue-null-'||n)::uuid,'75000000-0000-4000-8000-000000000001','catalogue null '||n,
 'lightstick',ARRAY['https://example.invalid/catalogue.png'],5000,30000,'KRW','direct','100%_역',NULL FROM generate_series(1,2) n;
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,pickup_method,pickup_area)
SELECT md5('catalogue-other-'||kind)::uuid,'75000000-0000-4000-8000-000000000001','catalogue '||kind,
 'lightstick',ARRAY['https://example.invalid/catalogue.png'],5000,30000,'KRW','direct','잠실역 인근'
 FROM unnest(ARRAY['requested','legacy']) kind;
INSERT INTO public.reservations(item_id,lender_id,borrower_id,rental_date,return_date,starts_at,ends_at,
 rental_fee,deposit,total_paid,currency,status,client_request_id,quoted_item_version)
SELECT i.id,i.lender_id,'75000000-0000-4000-8000-000000000002',
 (current_setting('test.catalogue_start')::timestamptz AT TIME ZONE 'Asia/Seoul')::date,
 (current_setting('test.catalogue_end')::timestamptz AT TIME ZONE 'Asia/Seoul')::date+1,
 CASE WHEN kind='requested' THEN current_setting('test.catalogue_start')::timestamptz END,
 CASE WHEN kind='requested' THEN current_setting('test.catalogue_end')::timestamptz END,
 5000,30000,35000,'KRW',CASE WHEN kind='requested' THEN 'requested' ELSE 'pending' END::public.reservation_status,
 gen_random_uuid(),i.updated_at FROM unnest(ARRAY['requested','legacy']) kind
 JOIN public.rental_items i ON i.id=md5('catalogue-other-'||kind)::uuid;

SET LOCAL ROLE anon;
DO $$
DECLARE first_page jsonb; last_id uuid; last_created timestamptz; row_data jsonb; next_count integer;
BEGIN
 SELECT jsonb_agg(to_jsonb(s)) INTO first_page FROM public.search_rental_items(
  p_search=>'catalogue fixture',p_pickup_area=>'잠실',
  p_starts_at=>current_setting('test.catalogue_start')::timestamptz,
  p_ends_at=>current_setting('test.catalogue_end')::timestamptz) s;
 IF jsonb_array_length(first_page)<>51 THEN RAISE EXCEPTION 'availability filtered after pagination'; END IF;
 FOR row_data IN SELECT value FROM jsonb_array_elements(first_page) LOOP
  IF row_data->>'title' NOT LIKE '%free%' THEN RAISE EXCEPTION 'occupied inventory advertised as available'; END IF;
  IF row_data ?| ARRAY['pickup_note','pickup_location','imei','borrower_id','reservation_id'] THEN
   RAISE EXCEPTION 'private field leaked by search RPC';
  END IF;
 END LOOP;
 last_id:=(first_page->49->>'id')::uuid;last_created:=(first_page->49->>'created_at')::timestamptz;
 SELECT count(*) INTO next_count FROM public.search_rental_items(
  p_search=>'catalogue fixture',p_pickup_area=>'잠실',
  p_starts_at=>current_setting('test.catalogue_start')::timestamptz,
  p_ends_at=>current_setting('test.catalogue_end')::timestamptz,
  p_before_created_at=>last_created,p_before_id=>last_id);
 IF next_count<>5 THEN RAISE EXCEPTION 'keyset cursor skipped or repeated equal timestamp rows'; END IF;
 IF EXISTS(SELECT 1 FROM public.search_rental_items(p_search=>'catalogue excluded',
  p_starts_at=>current_setting('test.catalogue_start')::timestamptz,
  p_ends_at=>current_setting('test.catalogue_end')::timestamptz)) THEN RAISE EXCEPTION 'visibility or item window bypass'; END IF;
 IF (SELECT count(*) FROM public.search_rental_items(p_search=>'catalogue requested',
  p_starts_at=>current_setting('test.catalogue_start')::timestamptz,
  p_ends_at=>current_setting('test.catalogue_end')::timestamptz))<>1 THEN RAISE EXCEPTION 'unaccepted request incorrectly holds inventory'; END IF;
 IF EXISTS(SELECT 1 FROM public.search_rental_items(p_search=>'catalogue legacy',
  p_starts_at=>current_setting('test.catalogue_start')::timestamptz,
  p_ends_at=>current_setting('test.catalogue_end')::timestamptz)) THEN RAISE EXCEPTION 'legacy pending reservation ignored'; END IF;
 IF (SELECT count(*) FROM public.search_rental_items(p_search=>'catalogue fixture busy',
  p_starts_at=>current_setting('test.catalogue_end')::timestamptz,
  p_ends_at=>current_setting('test.catalogue_end')::timestamptz+interval '1 hour'))<>51 THEN
  RAISE EXCEPTION 'back-to-back half-open periods incorrectly overlap';
 END IF;
 IF EXISTS(SELECT 1 FROM public.search_rental_items(p_search=>'catalogue fixture',p_pickup_area=>'%')) THEN
  RAISE EXCEPTION 'pickup search interpreted literal percent as wildcard';
 END IF;
 SELECT id INTO last_id FROM public.search_rental_items(p_search=>'catalogue null',p_pickup_area=>'100%_') LIMIT 1;
 IF last_id IS NULL OR (SELECT count(*) FROM public.search_rental_items(p_search=>'catalogue null',
  p_before_created_at=>'-infinity',p_before_id=>last_id))<>1 THEN RAISE EXCEPTION 'null timestamp cursor failed'; END IF;
 BEGIN
  PERFORM public.search_rental_items(p_starts_at=>now()+interval '1 day');
  RAISE EXCEPTION 'partial period accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.search_rental_items(p_starts_at=>now()+interval '2 days',p_ends_at=>now()+interval '1 day');
  RAISE EXCEPTION 'reversed period accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
ROLLBACK;
