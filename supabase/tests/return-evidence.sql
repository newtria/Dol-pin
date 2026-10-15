BEGIN;
SELECT set_config('request.jwt.claim.role','service_role',true);
INSERT INTO public.users(id,phone,nickname,country,currency) VALUES
 ('16000000-0000-4000-8000-000000000001','evidence-lender','증빙 대여자','KR','KRW'),
 ('16000000-0000-4000-8000-000000000002','evidence-borrower','증빙 차용자','KR','KRW'),
 ('16000000-0000-4000-8000-000000000003','evidence-outsider','증빙 외부인','KR','KRW'),
 ('16000000-0000-4000-8000-000000000004','evidence-operator','증빙 운영자','KR','KRW');
INSERT INTO auth.users(id,raw_app_meta_data) VALUES
 ('16000000-0000-4000-8000-000000000001','{}'),
 ('16000000-0000-4000-8000-000000000002','{}'),
 ('16000000-0000-4000-8000-000000000003','{}'),
 ('16000000-0000-4000-8000-000000000004','{"dolpin_operator":true}');
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,pickup_method)
VALUES('26000000-0000-4000-8000-000000000001','16000000-0000-4000-8000-000000000001',
 '반납 증빙 fixture','lightstick',ARRAY['https://example.invalid/fixture.png'],5000,30000,'KRW','direct');
INSERT INTO public.reservations(id,item_id,borrower_id,lender_id,rental_date,return_date,rental_fee,deposit,total_paid,currency,status,starts_at,ends_at)
VALUES
 ('36000000-0000-4000-8000-000000000001','26000000-0000-4000-8000-000000000001',
 '16000000-0000-4000-8000-000000000002','16000000-0000-4000-8000-000000000001',
 CURRENT_DATE+1,CURRENT_DATE+2,5000,30000,35000,'KRW','picked_up',now()+interval '1 day',now()+interval '2 days'),
 ('36000000-0000-4000-8000-000000000002','26000000-0000-4000-8000-000000000001',
 '16000000-0000-4000-8000-000000000002','16000000-0000-4000-8000-000000000001',
 CURRENT_DATE+4,CURRENT_DATE+5,5000,30000,35000,'KRW','picked_up',NULL,NULL);
INSERT INTO storage.buckets(id,name,public) VALUES('rental-photos','rental-photos',true) ON CONFLICT DO NOTHING;
INSERT INTO storage.objects(bucket_id,name,owner) VALUES
 ('rental-evidence','36000000-0000-4000-8000-000000000001/16000000-0000-4000-8000-000000000002/private.png','16000000-0000-4000-8000-000000000002'),
 ('rental-evidence','36000000-0000-4000-8000-000000000001/16000000-0000-4000-8000-000000000002/other-owner.png','16000000-0000-4000-8000-000000000003'),
 ('rental-photos','returns/36000000-0000-4000-8000-000000000001/16000000-0000-4000-8000-000000000002/public.png','16000000-0000-4000-8000-000000000002'),
 ('rental-photos','returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000002/legacy.png','16000000-0000-4000-8000-000000000002'),
 ('rental-photos','returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000002/other-owner.png','16000000-0000-4000-8000-000000000003');

DO $$ BEGIN
 IF has_function_privilege('authenticated','public.resolve_rental_return_evidence(uuid,text)','EXECUTE')
 OR has_function_privilege('service_role','public.resolve_rental_return_evidence(uuid,text)','EXECUTE')
 OR has_function_privilege('anon','public.rental_return_evidence(uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'evidence resolver exposed an unscoped capability'; END IF;
END $$;

SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','16000000-0000-4000-8000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE result jsonb; BEGIN
 BEGIN
  PERFORM public.return_rental('36000000-0000-4000-8000-000000000001',
   '36000000-0000-4000-8000-000000000001/16000000-0000-4000-8000-000000000002/other-owner.png');
  RAISE EXCEPTION 'private submission accepted another object owner';
 EXCEPTION WHEN no_data_found THEN NULL; END;
 BEGIN
  PERFORM public.confirm_reservation_return('36000000-0000-4000-8000-000000000001',
   'returns/36000000-0000-4000-8000-000000000001/16000000-0000-4000-8000-000000000002/public.png');
  RAISE EXCEPTION 'new rental accepted legacy public evidence';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM='new rental accepted legacy public evidence' THEN RAISE; END IF;
 END;
 IF (SELECT status FROM public.reservations WHERE id='36000000-0000-4000-8000-000000000001')<>'picked_up'
 THEN RAISE EXCEPTION 'rejected legacy return changed custody'; END IF;
 result:=public.confirm_reservation_return('36000000-0000-4000-8000-000000000001',
  '36000000-0000-4000-8000-000000000001/16000000-0000-4000-8000-000000000002/private.png');
 IF result->>'status'<>'returned' THEN RAISE EXCEPTION 'compatibility RPC did not delegate private return'; END IF;
 result:=public.confirm_reservation_return('36000000-0000-4000-8000-000000000001',
  '36000000-0000-4000-8000-000000000001/16000000-0000-4000-8000-000000000002/private.png');
 IF result->>'already'<>'true' THEN RAISE EXCEPTION 'private return replay was not idempotent'; END IF;
 result:=public.rental_return_evidence('36000000-0000-4000-8000-000000000001');
 IF result->>'bucket'<>'rental-evidence' OR result->>'path'<>'36000000-0000-4000-8000-000000000001/16000000-0000-4000-8000-000000000002/private.png'
 THEN RAISE EXCEPTION 'private evidence identity changed'; END IF;
 result:=public.confirm_reservation_return('36000000-0000-4000-8000-000000000002',
  'https://old-project.supabase.co/storage/v1/object/public/rental-photos/returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000002/legacy.png');
 IF result->>'status'<>'returned' THEN RAISE EXCEPTION 'legacy return compatibility failed'; END IF;
 IF (SELECT return_photo FROM public.reservations WHERE id='36000000-0000-4000-8000-000000000002')<>'returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000002/legacy.png'
 THEN RAISE EXCEPTION 'legacy return kept caller URL as authority'; END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','16000000-0000-4000-8000-000000000001',true);
DO $$ DECLARE result jsonb; BEGIN
 result:=public.rental_return_evidence('36000000-0000-4000-8000-000000000002');
 IF result->>'bucket'<>'rental-photos' THEN RAISE EXCEPTION 'lender lost legacy evidence access'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','16000000-0000-4000-8000-000000000003',true);
DO $$ BEGIN
 BEGIN
  PERFORM public.rental_return_evidence('36000000-0000-4000-8000-000000000002');
  RAISE EXCEPTION 'outsider resolved submitted evidence';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.role','service_role',true);

-- Historical URLs are read without rewriting an already submitted record.
UPDATE public.reservations SET return_photo='https://old-project.supabase.co/storage/v1/object/public/rental-photos/returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000002/legacy.png'
 WHERE id='36000000-0000-4000-8000-000000000002';
DO $$ DECLARE path text; ref text; BEGIN
 path:=public.finance_evidence_access('36000000-0000-4000-8000-000000000002','16000000-0000-4000-8000-000000000004','return');
 IF path<>'returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000002/legacy.png'
 THEN RAISE EXCEPTION 'operator return resolver kept a URL or chose another object'; END IF;
 IF (SELECT count(*) FROM public.finance_operator_audit WHERE reservation_id='36000000-0000-4000-8000-000000000002' AND action='view_return_evidence')<>1
 THEN RAISE EXCEPTION 'legacy evidence access was not audited'; END IF;
 FOREACH ref IN ARRAY ARRAY[
  'https://old-project.supabase.co/storage/v1/object/public/rental-photos/returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000002/legacy.png?other=1',
  'https://old-project.supabase.co/storage/v1/object/public/rental-photos/returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000002/legacy.png#other',
  'https://example.invalid/photo.png',
  'returns/36000000-0000-4000-8000-000000000001/16000000-0000-4000-8000-000000000002/public.png',
  'returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000003/legacy.png',
  'returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000002/missing.png',
  'returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000002/other-owner.png',
  'returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000002/../legacy.png',
  'returns/36000000-0000-4000-8000-000000000002/16000000-0000-4000-8000-000000000002/%2e%2e/legacy.png'
 ] LOOP
  UPDATE public.reservations SET return_photo=ref WHERE id='36000000-0000-4000-8000-000000000002';
  BEGIN
   PERFORM public.finance_evidence_access('36000000-0000-4000-8000-000000000002','16000000-0000-4000-8000-000000000004','return');
   RAISE EXCEPTION 'operator resolved an invalid evidence reference';
  EXCEPTION WHEN no_data_found THEN NULL; END;
 END LOOP;
 IF (SELECT count(*) FROM public.finance_operator_audit WHERE reservation_id='36000000-0000-4000-8000-000000000002' AND action='view_return_evidence')<>1
 THEN RAISE EXCEPTION 'rejected evidence reference produced a successful access audit'; END IF;
 UPDATE public.users SET suspended_at=clock_timestamp() WHERE id='16000000-0000-4000-8000-000000000004';
 BEGIN
  PERFORM public.finance_evidence_access('36000000-0000-4000-8000-000000000001','16000000-0000-4000-8000-000000000004','return');
  RAISE EXCEPTION 'suspended operator resolved return evidence';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
SELECT 'private return authority and historical evidence access assertions passed' AS result;
