-- Support and account cleanup belong to an authenticated identity, not to a
-- trading profile. Keep this reference after Auth deidentification/deletion so
-- reports, audit records and durable cleanup retries retain their owner.
CREATE TABLE public.account_identities (
 id uuid PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 closed_at timestamptz
);
ALTER TABLE public.account_identities ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_identities FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.account_identities TO service_role;
INSERT INTO public.account_identities(id)
 SELECT id FROM public.users
 UNION SELECT user_id FROM public.api_usage_counters
 UNION SELECT reporter_id FROM public.reports
 UNION SELECT user_id FROM public.notifications
 UNION SELECT user_id FROM public.account_closures;
UPDATE public.account_identities a SET closed_at=coalesce(u.deleted_at,c.requested_at)
 FROM public.users u LEFT JOIN public.account_closures c ON c.user_id=u.id
 WHERE a.id=u.id AND (u.deleted_at IS NOT NULL OR c.user_id IS NOT NULL);

ALTER TABLE public.reports DROP CONSTRAINT reports_reporter_id_fkey;
ALTER TABLE public.reports ADD CONSTRAINT reports_reporter_id_fkey
 FOREIGN KEY(reporter_id) REFERENCES public.account_identities(id);
ALTER TABLE public.account_closures DROP CONSTRAINT account_closures_user_id_fkey;
ALTER TABLE public.account_closures ADD CONSTRAINT account_closures_user_id_fkey
 FOREIGN KEY(user_id) REFERENCES public.account_identities(id);
ALTER TABLE public.notifications DROP CONSTRAINT notifications_user_id_fkey;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_user_id_fkey
 FOREIGN KEY(user_id) REFERENCES public.account_identities(id);
ALTER TABLE public.api_usage_counters DROP CONSTRAINT api_usage_counters_user_id_fkey;
ALTER TABLE public.api_usage_counters ADD CONSTRAINT api_usage_counters_user_id_fkey
 FOREIGN KEY(user_id) REFERENCES public.account_identities(id) ON DELETE CASCADE;

-- Every new trading profile obtains the same identity lock as support and
-- closure. A delayed ensure_profile call cannot recreate a closed account.
CREATE FUNCTION public.guard_profile_identity() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE closed timestamptz;
BEGIN
 INSERT INTO public.account_identities(id) VALUES(NEW.id) ON CONFLICT DO NOTHING;
 SELECT closed_at INTO closed FROM public.account_identities WHERE id=NEW.id FOR SHARE;
 IF closed IS NOT NULL THEN RAISE EXCEPTION '탈퇴 처리된 계정입니다.' USING ERRCODE='42501'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.guard_profile_identity() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_profile_identity BEFORE INSERT ON public.users
 FOR EACH ROW EXECUTE FUNCTION public.guard_profile_identity();

-- This support-only predicate must not replace account_is_active or
-- account_session_open: having an identity does not grant trading/storage rights.
CREATE FUNCTION public.support_account_is_open() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT auth.uid() IS NOT NULL
  AND (EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NULL)
   OR EXISTS(SELECT 1 FROM auth.users WHERE id=auth.uid() AND deleted_at IS NULL AND NOT coalesce(is_anonymous,false)))
  AND NOT EXISTS(SELECT 1 FROM public.account_identities WHERE id=auth.uid() AND closed_at IS NOT NULL)
  AND NOT EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NOT NULL)
$$;
REVOKE ALL ON FUNCTION public.support_account_is_open() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.support_account_is_open() TO authenticated;
CREATE POLICY open_support_reports ON public.reports AS RESTRICTIVE FOR SELECT TO authenticated
 USING(public.support_account_is_open());
DROP POLICY notification_owner_read ON public.notifications;
CREATE POLICY notification_owner_read ON public.notifications FOR SELECT TO authenticated
 USING(user_id=auth.uid() AND public.support_account_is_open());

CREATE OR REPLACE FUNCTION public.require_open_session() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NOT NULL AND auth.role()<>'service_role' AND (
  EXISTS(SELECT 1 FROM public.account_identities WHERE id=auth.uid() AND closed_at IS NOT NULL)
  OR EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NOT NULL))
 THEN RAISE EXCEPTION '탈퇴 처리된 계정입니다.' USING ERRCODE='42501'; END IF;
END $$;


CREATE OR REPLACE FUNCTION public.consume_api_quota(p_user_id uuid,p_feature text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE policy public.api_usage_limits; counter public.api_usage_counters; current_time_value timestamptz; current_day date; wait_seconds integer;
BEGIN
 -- Existing transaction evidence and captured-payment reconciliation remain
 -- available to suspended participants, but still require an undeleted profile.
 IF p_feature IN ('evidence-upload','payment-verify') THEN
  PERFORM 1 FROM public.users WHERE id=p_user_id AND deleted_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION '계정에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
 ELSIF p_feature IS DISTINCT FROM 'report' THEN
  PERFORM public.assert_active_account(p_user_id);
 END IF;
 SELECT * INTO policy FROM public.api_usage_limits WHERE feature=p_feature;
 IF p_user_id IS NULL OR policy.feature IS NULL THEN RAISE EXCEPTION 'Invalid quota request' USING ERRCODE='22023'; END IF;
 current_time_value:=clock_timestamp();current_day:=(current_time_value AT TIME ZONE 'UTC')::date;
 INSERT INTO public.api_usage_counters(user_id,feature,day_start,minute_start)
 VALUES(p_user_id,p_feature,current_day,current_time_value) ON CONFLICT DO NOTHING;
 SELECT * INTO counter FROM public.api_usage_counters WHERE user_id=p_user_id AND feature=p_feature FOR UPDATE;
 current_time_value:=clock_timestamp();current_day:=(current_time_value AT TIME ZONE 'UTC')::date;
 IF counter.day_start<>current_day THEN counter.day_count:=0;counter.day_start:=current_day; END IF;
 IF counter.minute_start+interval '1 minute'<=current_time_value THEN counter.minute_count:=0;counter.minute_start:=current_time_value; END IF;
 IF counter.day_count>=policy.per_day OR counter.minute_count>=policy.per_minute THEN
  wait_seconds:=greatest(1,ceil(extract(epoch FROM CASE WHEN counter.day_count>=policy.per_day
   THEN ((current_day+1)::timestamp AT TIME ZONE 'UTC') ELSE counter.minute_start+interval '1 minute' END-current_time_value))::integer);
  RETURN jsonb_build_object('allowed',false,'retryAfter',wait_seconds);
 END IF;
 UPDATE public.api_usage_counters SET day_start=counter.day_start,day_count=counter.day_count+1,
 minute_start=counter.minute_start,minute_count=counter.minute_count+1 WHERE user_id=p_user_id AND feature=p_feature;
 RETURN jsonb_build_object('allowed',true,'remaining',policy.per_day-counter.day_count-1);
END $$;


CREATE OR REPLACE FUNCTION public.submit_report(p_user_id uuid,p_item_id uuid,p_reason text,p_description text DEFAULT NULL,p_reservation_id uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE target uuid; rental public.reservations;
BEGIN
 IF NOT public.support_account_is_open() THEN RAISE EXCEPTION '계정에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
 INSERT INTO public.account_identities(id) VALUES(auth.uid()) ON CONFLICT DO NOTHING;
 PERFORM 1 FROM public.account_identities WHERE id=auth.uid() AND closed_at IS NULL FOR SHARE;
 IF NOT FOUND OR NOT public.support_account_is_open() THEN RAISE EXCEPTION '계정에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
 IF p_user_id IS NULL AND p_item_id IS NULL AND p_reservation_id IS NULL THEN
  IF p_reason IS DISTINCT FROM 'other' OR p_description IS NULL OR length(trim(p_description)) NOT BETWEEN 10 AND 2000
  THEN RAISE EXCEPTION '문의 내용을 10자 이상 입력해 주세요.' USING ERRCODE='22023'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':support',2));
  IF EXISTS(SELECT 1 FROM public.reports WHERE reporter_id=auth.uid() AND reported_user_id IS NULL
   AND reported_item_id IS NULL AND reservation_id IS NULL AND description=trim(p_description) AND status='pending') THEN RETURN; END IF;
  PERFORM public.require_service_quota(auth.uid(),'report');
  INSERT INTO public.reports(reporter_id,reason,description) VALUES(auth.uid(),'other',trim(p_description));
  RETURN;
 END IF;
 -- Restricted participants still need to report a problem with an existing transaction.
 PERFORM 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION '계정에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
 IF (p_user_id IS NULL AND p_item_id IS NULL) OR p_reason IS NULL OR p_reason NOT IN ('fraud','abuse','unsafe','prohibited','other')
 OR length(p_description)>2000 THEN RAISE EXCEPTION '신고 내용을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 target:=p_user_id;
 IF p_item_id IS NOT NULL THEN
  SELECT lender_id INTO target FROM public.rental_items WHERE id=p_item_id;
  IF NOT FOUND OR (p_user_id IS NOT NULL AND p_user_id<>target) THEN RAISE EXCEPTION '신고 대상을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 END IF;
 IF target=auth.uid() OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=target) THEN RAISE EXCEPTION '신고 대상을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 IF p_reservation_id IS NOT NULL THEN
  SELECT * INTO rental FROM public.reservations WHERE id=p_reservation_id AND auth.uid() IN (borrower_id,lender_id);
  IF NOT FOUND THEN RAISE EXCEPTION '거래에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
  IF target IS DISTINCT FROM (CASE WHEN rental.borrower_id=auth.uid() THEN rental.lender_id ELSE rental.borrower_id END)
  OR (p_item_id IS NOT NULL AND p_item_id<>rental.item_id) THEN RAISE EXCEPTION '거래에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
 ELSE PERFORM public.assert_active_account(); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||target::text||coalesce(p_item_id::text,'')||coalesce(p_reservation_id::text,''),2));
 IF EXISTS(SELECT 1 FROM public.reports WHERE reporter_id=auth.uid() AND reported_user_id=target
  AND reported_item_id IS NOT DISTINCT FROM p_item_id AND reservation_id IS NOT DISTINCT FROM p_reservation_id AND status='pending') THEN RETURN; END IF;
 PERFORM public.require_service_quota(auth.uid(),'report');
 INSERT INTO public.reports(reporter_id,reported_user_id,reported_item_id,reservation_id,reason,description)
 VALUES(auth.uid(),target,p_item_id,p_reservation_id,p_reason,nullif(trim(p_description),''));
END $$;


CREATE OR REPLACE FUNCTION public.begin_account_closure(p_user_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_user_id IS NULL OR (NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_user_id)
  AND NOT EXISTS(SELECT 1 FROM public.users WHERE id=p_user_id)
  AND NOT EXISTS(SELECT 1 FROM public.account_closures WHERE user_id=p_user_id))
 THEN RAISE EXCEPTION '계정을 찾을 수 없습니다.' USING ERRCODE='22023'; END IF;
 INSERT INTO public.account_identities(id) VALUES(p_user_id) ON CONFLICT DO NOTHING;
 -- Non-key locking still fences support/profile FOR SHARE, while permitting
 -- quota/notification FK KEY SHARE after existing commands lock a user row.
 PERFORM 1 FROM public.account_identities WHERE id=p_user_id FOR NO KEY UPDATE;
 PERFORM 1 FROM public.users WHERE id=p_user_id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM public.account_closures WHERE user_id=p_user_id) THEN RETURN; END IF;
 IF EXISTS(SELECT 1 FROM public.reservations WHERE p_user_id IN (borrower_id,lender_id) AND
 (status IN ('requested','accepted','pending','paid','picked_up','returned','disputed') OR payment_action IS NOT NULL OR payment_attempt_merchant_uid IS NOT NULL))
 OR EXISTS(SELECT 1 FROM public.rental_payouts WHERE lender_id=p_user_id AND status<>'paid' AND net_amount>0)
 OR EXISTS(SELECT 1 FROM public.reservations r WHERE p_user_id IN (r.borrower_id,r.lender_id) AND r.status='resolved'
  AND NOT EXISTS(SELECT 1 FROM public.reservation_dispute_resolutions d WHERE d.reservation_id=r.id))
 OR EXISTS(SELECT 1 FROM public.legacy_payment_verifications v JOIN public.reservations r ON r.id=v.reservation_id
  WHERE p_user_id IN (r.borrower_id,r.lender_id) AND v.resolved_at IS NULL)
 THEN RAISE EXCEPTION '진행 중인 거래와 지급을 마친 뒤 탈퇴해 주세요.' USING ERRCODE='PCL01'; END IF;
 INSERT INTO public.account_closures(user_id) VALUES(p_user_id);
 UPDATE public.account_identities SET closed_at=clock_timestamp() WHERE id=p_user_id;
 UPDATE public.users SET deleted_at=clock_timestamp(),nickname='탈퇴한 사용자',phone=NULL,profile_image=NULL,region=NULL,
 fav_groups=NULL,fcm_token=NULL,identity_verified=false,is_lender=false WHERE id=p_user_id;
 UPDATE public.rental_items SET status='hidden',pickup_note=NULL,pickup_location=NULL,imei=NULL WHERE lender_id=p_user_id;
 DELETE FROM public.push_tokens WHERE user_id=p_user_id;
 DELETE FROM public.payout_accounts WHERE user_id=p_user_id;
 -- Read access is revoked immediately, even if Auth deletion needs a later retry.
END $$;


CREATE OR REPLACE FUNCTION public.enqueue_notification(p_user_id uuid,p_event_key text,p_kind text,p_body text,p_reservation_id uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE notification uuid;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.account_identities WHERE id=p_user_id AND closed_at IS NULL)
 OR EXISTS(SELECT 1 FROM public.users WHERE id=p_user_id AND deleted_at IS NOT NULL) THEN RETURN; END IF;
 INSERT INTO public.notifications(user_id,event_key,kind,title,body,reservation_id)
 VALUES(p_user_id,p_event_key,p_kind,'dol-pin',p_body,p_reservation_id) ON CONFLICT DO NOTHING RETURNING id INTO notification;
 IF notification IS NOT NULL THEN
  INSERT INTO public.notification_deliveries(notification_id,token) SELECT notification,token FROM public.push_tokens WHERE user_id=p_user_id;
 END IF;
END $$;

NOTIFY pgrst,'reload schema';
