BEGIN;
-- This suite asserts database authority even when no application is running.
DO $$ BEGIN
 IF has_table_privilege('authenticated','public.payout_accounts','SELECT')
 OR has_table_privilege('authenticated','public.payout_claim_accounts','SELECT')
 OR has_table_privilege('authenticated','public.rental_payouts','UPDATE')
 OR has_function_privilege('authenticated','public.begin_rental_dispute_resolution(uuid,uuid,integer,text)','EXECUTE')
 OR has_function_privilege('authenticated','public.claim_rental_payout(uuid,uuid)','EXECUTE')
 OR has_function_privilege('authenticated','public.finish_rental_payout(uuid,uuid,uuid,text)','EXECUTE')
 OR has_function_privilege('authenticated','public.retry_rental_payout(uuid,uuid,text)','EXECUTE')
 OR has_function_privilege('authenticated','public.finance_rental_detail(uuid,uuid,timestamptz,uuid)','EXECUTE')
 OR has_function_privilege('authenticated','public.finance_evidence_access(uuid,uuid,text,text)','EXECUTE')
 OR has_function_privilege('authenticated','public.reconcile_rental_payout(uuid,uuid,timestamptz,text,text,text)','EXECUTE')
 OR has_table_privilege('authenticated','public.finance_operator_audit','SELECT')
 OR has_table_privilege('authenticated','public.legacy_payment_verifications','SELECT')
 OR has_function_privilege('authenticated','public.record_legacy_payment_review(uuid,uuid,text,integer,integer,text,text,text)','EXECUTE')
 THEN RAISE EXCEPTION 'finance authority or private account access leaked'; END IF;
 IF has_table_privilege('service_role','public.payout_audit','UPDATE')
 OR has_table_privilege('service_role','public.payout_audit','DELETE')
 OR has_table_privilege('service_role','public.finance_operator_audit','UPDATE')
 OR has_table_privilege('service_role','public.finance_operator_audit','DELETE')
 THEN RAISE EXCEPTION 'payout audit is mutable by API service'; END IF;
 IF EXISTS(SELECT 1 FROM public.reservation_transitions WHERE to_status='disputed' AND actor_kind IN ('borrower','lender'))
 THEN RAISE EXCEPTION 'legacy dispute command bypasses case submission'; END IF;
END $$;

INSERT INTO public.users(id,phone,nickname,country,currency) VALUES
 ('12000000-0000-4000-8000-000000000001','commercial-lender','금융 대여자','KR','KRW'),
 ('12000000-0000-4000-8000-000000000002','commercial-borrower','금융 차용자','KR','KRW');
INSERT INTO public.policy_consents(user_id,terms_version,privacy_version) VALUES
 ('12000000-0000-4000-8000-000000000001','2026-09-22','2026-09-22'),
 ('12000000-0000-4000-8000-000000000002','2026-09-22','2026-09-22');
SELECT set_config('request.jwt.claim.role','service_role',true);
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,pickup_method)
VALUES('22000000-0000-4000-8000-000000000001','12000000-0000-4000-8000-000000000001',
 '금융 fixture','lightstick',ARRAY['https://example.invalid/fixture.png'],5000,30000,'KRW','direct');
INSERT INTO public.reservations(id,item_id,borrower_id,lender_id,rental_date,return_date,rental_fee,deposit,total_paid,currency,status,payment_provider,payment_id,starts_at,ends_at)
VALUES('32000000-0000-4000-8000-000000000001','22000000-0000-4000-8000-000000000001',
 '12000000-0000-4000-8000-000000000002','12000000-0000-4000-8000-000000000001',
 CURRENT_DATE-3,CURRENT_DATE-2,5000,30000,35000,'KRW','paid','toss','commercial-capture',now()-interval '3 days',now()-interval '2 days');

DO $$ BEGIN
 PERFORM public.refresh_rental_operator_reviews();
 PERFORM public.refresh_rental_operator_reviews();
 IF (SELECT count(*) FROM public.rental_operator_reviews WHERE reservation_id='32000000-0000-4000-8000-000000000001' AND kind='pickup_overdue')<>1
 THEN RAISE EXCEPTION 'overdue pickup was not escalated exactly once'; END IF;
 IF (SELECT status FROM public.reservations WHERE id='32000000-0000-4000-8000-000000000001')<>'paid'
 THEN RAISE EXCEPTION 'deadline scanner moved money or custody'; END IF;
END $$;

SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','12000000-0000-4000-8000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE d public.rental_disputes; BEGIN
 d:=public.open_rental_dispute('32000000-0000-4000-8000-000000000001','약속된 인수 장소에서 만나지 못했습니다.');
 IF d.reservation_id IS NULL THEN RAISE EXCEPTION 'paid borrower could not report no-show'; END IF;
 BEGIN
  PERFORM public.confirm_rental_pickup(d.reservation_id);
  RAISE EXCEPTION 'disputed reservation advanced custody';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='disputed reservation advanced custody' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
DO $$ BEGIN
 BEGIN
  PERFORM public.begin_rental_dispute_resolution('32000000-0000-4000-8000-000000000001','12000000-0000-4000-8000-000000000002',1000,'권한 없는 자체 분쟁 종결');
  RAISE EXCEPTION 'unverified operator resolved money';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
ROLLBACK;
SELECT 'commercial finance authority, no-show escalation and dispute freeze assertions passed' AS result;
