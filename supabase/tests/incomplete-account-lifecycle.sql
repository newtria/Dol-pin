BEGIN;
INSERT INTO auth.users(id,email,email_confirmed_at,is_anonymous,raw_app_meta_data) VALUES
 ('62000000-0000-4000-8000-000000000001','incomplete-support@example.invalid',now(),false,'{}'),
 ('62000000-0000-4000-8000-000000000002','incomplete-outsider@example.invalid',now(),false,'{}'),
 ('62000000-0000-4000-8000-000000000003','incomplete-close@example.invalid',now(),false,'{}'),
 ('62000000-0000-4000-8000-000000000004','incomplete-operator@example.invalid',now(),false,'{"dolpin_operator":true}');
INSERT INTO public.users(id,nickname,country) VALUES
 ('62000000-0000-4000-8000-000000000004','support operator','KR');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','62000000-0000-4000-8000-000000000001',true);
DO $$
BEGIN
 IF NOT public.support_account_is_open() OR public.account_is_active(auth.uid()) OR public.account_session_open() THEN
  RAISE EXCEPTION 'support identity unexpectedly requires or grants a trading profile';
 END IF;
 PERFORM public.submit_report(NULL,NULL,'other','프로필 생성 전에 계정 문의를 남깁니다.');
 PERFORM public.submit_report(NULL,NULL,'other','프로필 생성 전에 계정 문의를 남깁니다.');
 IF (SELECT count(*) FROM public.reports WHERE reporter_id=auth.uid())<>1 THEN RAISE EXCEPTION 'support retry duplicated'; END IF;
 IF EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid()) THEN RAISE EXCEPTION 'support fabricated a profile'; END IF;
 BEGIN
  PERFORM public.record_consent('2026-09-22','2026-09-22');
  RAISE EXCEPTION 'support created trading consent authority';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.submit_report('62000000-0000-4000-8000-000000000004',NULL,'other','프로필 없이 다른 사용자를 신고합니다.');
  RAISE EXCEPTION 'support identity gained targeted-report authority';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM 1 FROM public.account_identities;
  RAISE EXCEPTION 'client can inspect identity registry';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  INSERT INTO public.reports(reporter_id,reason,description) VALUES(auth.uid(),'other','direct insert');
  RAISE EXCEPTION 'client bypassed support command';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM public.submit_report(NULL,NULL,'other','첫 번째 추가 문의를 남깁니다.');
 PERFORM public.submit_report(NULL,NULL,'other','두 번째 추가 문의를 남깁니다.');
 BEGIN
  PERFORM public.submit_report(NULL,NULL,'other','세 번째 추가 문의는 제한되어야 합니다.');
  RAISE EXCEPTION 'incomplete accounts bypass support quota';
 EXCEPTION WHEN SQLSTATE 'P4290' THEN NULL; END;
END $$;

SELECT set_config('request.jwt.claim.sub','62000000-0000-4000-8000-000000000002',true);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.reports WHERE reporter_id='62000000-0000-4000-8000-000000000001') THEN
  RAISE EXCEPTION 'another account read support history';
 END IF;
END $$;

SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claim.role','service_role',true);
DO $$ DECLARE report_id uuid; BEGIN
 SELECT id INTO STRICT report_id FROM public.reports WHERE reporter_id='62000000-0000-4000-8000-000000000001'
  AND description='프로필 생성 전에 계정 문의를 남깁니다.';
 PERFORM public.moderate_service('62000000-0000-4000-8000-000000000004','resolved',report_id,NULL,'프로필 없이도 문의 답변을 확인할 수 있습니다.');
 IF NOT EXISTS(SELECT 1 FROM public.service_audit WHERE target_id=report_id AND action='resolved') THEN RAISE EXCEPTION 'support decision lost audit'; END IF;
 BEGIN
  PERFORM public.consume_api_quota('62000000-0000-4000-8000-000000000001','gemini-analyze');
  RAISE EXCEPTION 'support registry granted non-support API quota authority';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','62000000-0000-4000-8000-000000000001',true);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.reports WHERE reporter_id=auth.uid() AND status='resolved' AND resolution_note IS NOT NULL) THEN
  RAISE EXCEPTION 'incomplete account cannot read operator reply';
 END IF;
 IF (SELECT count(*) FROM public.notifications WHERE user_id=auth.uid() AND kind='support')<>1 THEN
  RAISE EXCEPTION 'support reply notification missing';
 END IF;
 PERFORM public.ensure_profile('later trading profile');
 IF (SELECT count(*) FROM public.reports WHERE reporter_id=auth.uid())<>3 THEN RAISE EXCEPTION 'profile creation lost prior support history'; END IF;
 IF (public.consent_status()->>'accepted')::boolean THEN RAISE EXCEPTION 'profile creation fabricated trading consent'; END IF;
END $$;

SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claim.role','service_role',true);
DO $$ BEGIN
 -- This account has neither a trading profile nor a previous support identity.
 PERFORM public.begin_account_closure('62000000-0000-4000-8000-000000000003');
 PERFORM public.begin_account_closure('62000000-0000-4000-8000-000000000003');
 IF EXISTS(SELECT 1 FROM public.users WHERE id='62000000-0000-4000-8000-000000000003') THEN RAISE EXCEPTION 'closure fabricated a profile'; END IF;
 IF (SELECT count(*) FROM public.account_closures WHERE user_id='62000000-0000-4000-8000-000000000003' AND auth_deleted_at IS NULL)<>1 THEN
  RAISE EXCEPTION 'Auth-only closure is not durably retryable';
 END IF;
 PERFORM public.begin_account_closure('62000000-0000-4000-8000-000000000001');
END $$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','62000000-0000-4000-8000-000000000003',true);
DO $$ BEGIN
 IF public.support_account_is_open() THEN RAISE EXCEPTION 'closed incomplete account remains authorized'; END IF;
 BEGIN PERFORM public.require_open_session(); RAISE EXCEPTION 'stale JWT bypassed closure'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.ensure_profile('resurrect closed account'); RAISE EXCEPTION 'profile recreated closed identity'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.submit_report(NULL,NULL,'other','탈퇴한 계정에서 다시 문의합니다.'); RAISE EXCEPTION 'closed identity submitted support'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT set_config('request.jwt.claim.sub','62000000-0000-4000-8000-000000000001',true);
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.reports WHERE reporter_id=auth.uid()) OR EXISTS(SELECT 1 FROM public.notifications WHERE user_id=auth.uid()) THEN
  RAISE EXCEPTION 'closed account still reads private support or notifications';
 END IF;
END $$;

RESET ROLE;
SELECT set_config('request.jwt.claim.role','service_role',true);
DELETE FROM auth.users WHERE id='62000000-0000-4000-8000-000000000003';
DO $$ BEGIN
 PERFORM public.begin_account_closure('62000000-0000-4000-8000-000000000003');
 IF NOT EXISTS(SELECT 1 FROM public.account_closures WHERE user_id='62000000-0000-4000-8000-000000000003') THEN
  RAISE EXCEPTION 'Auth deletion erased closure recovery identity';
 END IF;
END $$;
-- Suspending trading privileges must not strand an existing participant's
-- evidence or captured-payment reconciliation behind the shared quota check.
INSERT INTO auth.users(id,email,email_confirmed_at,is_anonymous,raw_app_meta_data) VALUES
 ('62000000-0000-4000-8000-000000000005','suspended-participant@example.invalid',now(),false,'{}'),
 ('62000000-0000-4000-8000-000000000006','suspended-participant-lender@example.invalid',now(),false,'{}');
INSERT INTO public.users(id,nickname,country) VALUES
 ('62000000-0000-4000-8000-000000000005','suspended participant','KR'),
 ('62000000-0000-4000-8000-000000000006','participant lender','KR');
INSERT INTO public.policy_consents(user_id,terms_version,privacy_version)
 SELECT id,'2026-09-22','2026-09-22' FROM public.users WHERE id IN
 ('62000000-0000-4000-8000-000000000005','62000000-0000-4000-8000-000000000006');
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,pickup_method)
 VALUES('63000000-0000-4000-8000-000000000001','62000000-0000-4000-8000-000000000006','suspended participant fixture','lightstick',
 ARRAY['https://example.invalid/fixture.png'],1000,10000,'KRW','direct');
INSERT INTO public.reservations(id,item_id,borrower_id,lender_id,rental_date,return_date,rental_fee,deposit,total_paid,currency,status,starts_at,ends_at)
 VALUES('64000000-0000-4000-8000-000000000001','63000000-0000-4000-8000-000000000001',
 '62000000-0000-4000-8000-000000000005','62000000-0000-4000-8000-000000000006',
 CURRENT_DATE+1,CURRENT_DATE+2,1000,10000,11000,'KRW','picked_up',now()+interval '1 day',now()+interval '2 days');
UPDATE public.users SET suspended_at=clock_timestamp() WHERE id='62000000-0000-4000-8000-000000000005';

SET LOCAL ROLE service_role;
DO $$ DECLARE feature text; BEGIN
 FOREACH feature IN ARRAY ARRAY['evidence-upload','payment-verify'] LOOP
  IF (public.consume_api_quota('62000000-0000-4000-8000-000000000005',feature)->>'allowed')::boolean IS DISTINCT FROM true THEN
   RAISE EXCEPTION 'suspension blocked existing transaction capability: %',feature;
  END IF;
  BEGIN
   PERFORM public.consume_api_quota('62000000-0000-4000-8000-000000000002',feature);
   RAISE EXCEPTION 'profile-less identity gained transaction capability: %',feature;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
   PERFORM public.consume_api_quota('62000000-0000-4000-8000-000000000001',feature);
   RAISE EXCEPTION 'deleted profile gained transaction capability: %',feature;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 END LOOP;
 FOREACH feature IN ARRAY ARRAY['reservation','product-upload'] LOOP
  BEGIN
   PERFORM public.consume_api_quota('62000000-0000-4000-8000-000000000005',feature);
   RAISE EXCEPTION 'suspension allowed new trading capability: %',feature;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 END LOOP;
END $$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','62000000-0000-4000-8000-000000000005',true);
INSERT INTO storage.objects(bucket_id,name,owner) VALUES
 ('rental-evidence','64000000-0000-4000-8000-000000000001/62000000-0000-4000-8000-000000000005/suspended.png','62000000-0000-4000-8000-000000000005');
DO $$ BEGIN
 BEGIN
  PERFORM public.request_rental('63000000-0000-4000-8000-000000000001',now()+interval '5 days',now()+interval '6 days',
   (SELECT updated_at FROM public.rental_items WHERE id='63000000-0000-4000-8000-000000000001'),'65000000-0000-4000-8000-000000000001');
  RAISE EXCEPTION 'suspended participant started a new rental';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
