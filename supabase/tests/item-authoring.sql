BEGIN;
INSERT INTO public.users(id,nickname,country) VALUES
 ('71000000-0000-4000-8000-000000000001','item author','KR'),
 ('71000000-0000-4000-8000-000000000002','other author','KR'),
 ('71000000-0000-4000-8000-000000000003','author without consent','KR');
INSERT INTO public.policy_consents(user_id,terms_version,privacy_version) VALUES
 ('71000000-0000-4000-8000-000000000001','2026-09-22','2026-09-22'),
 ('71000000-0000-4000-8000-000000000002','2026-09-22','2026-09-22');
INSERT INTO storage.objects(bucket_id,name) VALUES
 ('product-photos','71000000-0000-4000-8000-000000000001/item-authoring.jpg'),
 ('product-photos','71000000-0000-4000-8000-000000000001/new-photo.jpg'),
 ('product-photos','71000000-0000-4000-8000-000000000002/item-authoring.jpg'),
 ('product-photos','71000000-0000-4000-8000-000000000003/item-authoring.jpg');
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,pickup_method)
 VALUES('72000000-0000-4000-8000-000000000099','71000000-0000-4000-8000-000000000003','Legacy nullable details','lightstick',
 ARRAY['https://storage.invalid/legacy.jpg'],5000,30000,'KRW','direct');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE input jsonb; first public.rental_items; replay public.rental_items; edited public.rental_items; blocked boolean:=false; field text; invalid jsonb;
BEGIN
 IF to_regprocedure('public.update_my_item(uuid,jsonb)') IS NOT NULL THEN
  RAISE EXCEPTION 'unversioned update bypass remains available';
 END IF;
 input:=jsonb_build_object('title','등록 복구 물품','description','입력한 설명','category','lightstick','concert_id',NULL,
  'daily_price',5000,'deposit',30000,'photos',jsonb_build_array('https://storage.invalid/storage/v1/object/public/product-photos/'||auth.uid()||'/item-authoring.jpg'),
  'pickup_method','direct','pickup_area','잠실역','pickup_note','3번 출구','available_from','2099-10-18','available_to','2099-10-20');
 first:=public.create_my_item('73000000-0000-4000-8000-000000000001',input);
 replay:=public.create_my_item('73000000-0000-4000-8000-000000000001',input);
 IF first.id<>replay.id OR (SELECT count(*) FROM public.rental_items WHERE lender_id=auth.uid())<>1 THEN
  RAISE EXCEPTION 'creation retry duplicated the item';
 END IF;
 IF first.pickup_note<>'3번 출구' OR first.daily_price<>5000 OR first.available_to<>'2099-10-20'::date THEN
  RAISE EXCEPTION 'creation did not preserve the submitted fields';
 END IF;
 replay:=public.get_my_item(first.id);
 IF replay.updated_at IS DISTINCT FROM first.updated_at OR replay.pickup_note IS DISTINCT FROM first.pickup_note THEN
  RAISE EXCEPTION 'editor snapshot did not include private instructions and version';
 END IF;
 BEGIN
  INSERT INTO public.rental_items(lender_id,title,category,photos,daily_price,deposit,currency,pickup_method,pickup_area,pickup_note)
  VALUES(auth.uid(),'direct insert bypass','lightstick',first.photos,5000,30000,'KRW','direct','잠실역','3번 출구');
  RAISE EXCEPTION 'direct insert bypassed creation command';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF has_table_privilege('authenticated','public.rental_items','INSERT') OR EXISTS(
  SELECT 1 FROM pg_attribute WHERE attrelid='public.rental_items'::regclass AND attnum>0 AND NOT attisdropped
  AND has_column_privilege('authenticated','public.rental_items',attname,'INSERT')) THEN
  RAISE EXCEPTION 'direct insert table or column grants remain';
 END IF;
 FOREACH field IN ARRAY ARRAY['pickup_area','pickup_note'] LOOP
  FOR invalid IN SELECT value FROM jsonb_array_elements(jsonb_build_array(
   input-field,input||jsonb_build_object(field,NULL),input||jsonb_build_object(field,42),input||jsonb_build_object(field,jsonb_build_array()),
   input||jsonb_build_object(field,''),input||jsonb_build_object(field,'  '),input||jsonb_build_object(field,E'\t\n'),
   input||jsonb_build_object(field,U&'\00A0\FEFF'),input||jsonb_build_object(field,'a'),
   input||jsonb_build_object(field,repeat('a',CASE WHEN field='pickup_area' THEN 101 ELSE 301 END)))) LOOP
   blocked:=false;
   BEGIN PERFORM public.create_my_item('73000000-0000-4000-8000-000000000010',invalid);
   EXCEPTION WHEN invalid_parameter_value THEN blocked:=true; END;
   IF NOT blocked THEN RAISE EXCEPTION 'new creation accepted invalid %',field; END IF;
   IF invalid ? field THEN
    blocked:=false;
    BEGIN PERFORM public.update_my_item(first.id,jsonb_build_object(field,invalid->field),first.updated_at);
    EXCEPTION WHEN invalid_parameter_value THEN blocked:=true; END;
    IF NOT blocked THEN RAISE EXCEPTION 'update accepted invalid %',field; END IF;
   END IF;
  END LOOP;
 END LOOP;
 blocked:=false;
 BEGIN
  PERFORM public.create_my_item('73000000-0000-4000-8000-000000000001',input||'{"daily_price":7000}'::jsonb);
 EXCEPTION WHEN SQLSTATE 'PIT01' THEN blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'same creation identity accepted different content'; END IF;
 -- Replaying a successful creation must not undo a later normal edit.
 edited:=public.update_my_item(first.id,jsonb_build_object('daily_price',6000,'photos',jsonb_build_array(
  'https://storage.invalid/storage/v1/object/public/product-photos/'||auth.uid()||'/new-photo.jpg')),first.updated_at);
 IF edited.updated_at<=first.updated_at THEN RAISE EXCEPTION 'successful edit did not advance its version'; END IF;
 blocked:=false;
 BEGIN PERFORM public.update_my_item(first.id,input||'{"daily_price":7000}'::jsonb,first.updated_at);
 EXCEPTION WHEN SQLSTATE 'PIV01' THEN blocked:=true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'stale edit overwrote another editor'; END IF;
 replay:=public.update_my_item(first.id,'{"pickup_area":"  새로운 지역  ","pickup_note":"  새로운 상세 장소  "}'::jsonb,edited.updated_at);
 IF replay.updated_at<=edited.updated_at OR replay.daily_price<>6000 OR replay.photos IS DISTINCT FROM edited.photos
 OR replay.pickup_area<>'새로운 지역' OR replay.pickup_note<>'새로운 상세 장소' THEN
  RAISE EXCEPTION 'refreshed edit lost current fields, normalization or version';
 END IF;
 replay:=public.create_my_item('73000000-0000-4000-8000-000000000001',input);
 IF replay.id<>first.id OR replay.daily_price<>6000 THEN RAISE EXCEPTION 'replay overwrote the current item'; END IF;
 blocked:=false;
 BEGIN
  PERFORM public.create_my_item('73000000-0000-4000-8000-000000000002',input||'{"lender_id":"71000000-0000-4000-8000-000000000002"}'::jsonb);
 EXCEPTION WHEN invalid_parameter_value THEN blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'caller-controlled ownership accepted'; END IF;
 blocked:=false;
 BEGIN PERFORM 1 FROM public.item_creation_requests;
 EXCEPTION WHEN insufficient_privilege THEN blocked:=true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'private request ledger is directly readable'; END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE input jsonb; item public.rental_items;
BEGIN
 input:=jsonb_build_object('title','다른 계정 물품','description','','category','lightstick','concert_id',NULL,
  'daily_price',5000,'deposit',30000,'photos',jsonb_build_array('https://storage.invalid/storage/v1/object/public/product-photos/'||auth.uid()||'/item-authoring.jpg'),
  'pickup_method','direct','pickup_area','잠실역','pickup_note','3번 출구');
 item:=public.create_my_item('73000000-0000-4000-8000-000000000001',input);
 IF item.lender_id<>auth.uid() THEN RAISE EXCEPTION 'creation identity crossed account boundaries'; END IF;
 BEGIN
  PERFORM public.get_my_item((SELECT id FROM public.rental_items WHERE lender_id='71000000-0000-4000-8000-000000000001' LIMIT 1));
  RAISE EXCEPTION 'another owner read private editor snapshot';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

SELECT set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000003',true);
DO $$
DECLARE blocked boolean:=false;
BEGIN
 BEGIN
  PERFORM public.create_my_item('73000000-0000-4000-8000-000000000001',jsonb_build_object(
   'title','미동의 계정 물품','description','','category','lightstick','concert_id',NULL,'daily_price',5000,'deposit',30000,
   'photos',jsonb_build_array('https://storage.invalid/storage/v1/object/public/product-photos/'||auth.uid()||'/item-authoring.jpg'),
   'pickup_method','direct','pickup_area','잠실역','pickup_note','3번 출구'));
 EXCEPTION WHEN SQLSTATE 'PCN01' THEN blocked:=true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'creation bypassed required consent'; END IF;
END $$;

RESET ROLE;
INSERT INTO public.policy_consents(user_id,terms_version,privacy_version)
 VALUES('71000000-0000-4000-8000-000000000003','2026-09-22','2026-09-22');
SET LOCAL ROLE authenticated;
DO $$
DECLARE edited public.rental_items;
BEGIN
 edited:=public.update_my_item('72000000-0000-4000-8000-000000000099','{"daily_price":6000}',
  (SELECT updated_at FROM public.rental_items WHERE id='72000000-0000-4000-8000-000000000099'));
 IF edited.pickup_area IS NOT NULL OR edited.pickup_note IS NOT NULL OR edited.daily_price<>6000 THEN
  RAISE EXCEPTION 'omitted legacy nullable details prevented a partial edit';
 END IF;
END $$;
RESET ROLE;
DO $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.rental_items WHERE id='72000000-0000-4000-8000-000000000099' AND pickup_area IS NULL AND pickup_note IS NULL) THEN
  RAISE EXCEPTION 'legacy nullable meeting details were changed';
 END IF;
 IF (SELECT count(*) FROM public.item_creation_requests WHERE owner_id IN
 ('71000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000002'))<>2 THEN
  RAISE EXCEPTION 'unexpected creation ledger count';
 END IF;
 IF EXISTS(SELECT 1 FROM public.item_creation_requests WHERE owner_id='71000000-0000-4000-8000-000000000003') THEN
  RAISE EXCEPTION 'failed creation left a committed request';
 END IF;
END $$;
ROLLBACK;
