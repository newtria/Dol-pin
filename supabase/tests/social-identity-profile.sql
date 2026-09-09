BEGIN;
INSERT INTO auth.users(id,is_anonymous,raw_user_meta_data) VALUES
 ('13000000-0000-4000-8000-000000000001',false,'{}'),
 ('13000000-0000-4000-8000-000000000002',false,'{"provider":"custom:naver"}');
INSERT INTO auth.identities(id,user_id,provider_id,provider,identity_data) VALUES
 (gen_random_uuid(),'13000000-0000-4000-8000-000000000001','naver-sub-fixture','custom:naver','{"sub":"naver-sub-fixture"}');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000001',true);
DO $$ DECLARE p public.users; BEGIN
 p:=public.ensure_profile('네이버 테스트');
 IF p.phone IS NOT NULL OR p.identity_verified IS DISTINCT FROM false THEN RAISE EXCEPTION 'fabricated verification'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000002',true);
DO $$ BEGIN
 BEGIN
  PERFORM public.ensure_profile('위조 메타데이터');
  RAISE EXCEPTION 'metadata spoof accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
SELECT 'Trusted social identity accepted without contact data; client metadata rejected' AS result;
