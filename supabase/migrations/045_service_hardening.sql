-- Omitted profile fields are a patch; explicitly clearing a region remains possible.
DROP FUNCTION public.update_my_profile(text,text,text);
CREATE FUNCTION public.update_my_profile(p_nickname text,p_region text DEFAULT NULL,p_locale text DEFAULT NULL,p_update_region boolean DEFAULT false)
RETURNS public.users LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE profile public.users;
BEGIN
 SELECT * INTO profile FROM public.users WHERE id=auth.uid() AND deleted_at IS NULL AND suspended_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '이 계정은 현재 이용할 수 없습니다.' USING ERRCODE='42501'; END IF;
 IF p_nickname IS NULL OR length(trim(p_nickname)) NOT BETWEEN 2 AND 30
 OR length(p_region)>100 OR (p_locale IS NOT NULL AND p_locale NOT IN ('ko','en','ja','zh'))
 OR p_update_region IS NULL THEN RAISE EXCEPTION '프로필 내용을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 UPDATE public.users SET nickname=trim(p_nickname),
 region=CASE WHEN p_update_region OR p_region IS NOT NULL THEN nullif(trim(p_region),'') ELSE region END,
 locale=coalesce(p_locale,locale) WHERE id=auth.uid() RETURNING * INTO profile;
 RETURN profile;
END $$;
REVOKE ALL ON FUNCTION public.update_my_profile(text,text,text,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.update_my_profile(text,text,text,boolean) TO authenticated;

ALTER TABLE public.reports ADD COLUMN reservation_id uuid REFERENCES public.reservations(id);
ALTER TABLE public.reports ADD COLUMN resolution_note text CHECK(length(resolution_note)<=500);
CREATE INDEX service_pending_reports ON public.reports(created_at,id) WHERE status='pending';
CREATE INDEX service_suspended_accounts ON public.users(suspended_at,id) WHERE suspended_at IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX service_moderated_items ON public.rental_items(moderated_at,id) WHERE moderated_at IS NOT NULL;
CREATE INDEX service_review_deliveries ON public.notification_deliveries(next_attempt_at,id) WHERE status='review';
CREATE INDEX service_pending_closures ON public.account_closures(requested_at,user_id) WHERE auth_deleted_at IS NULL;

DROP FUNCTION public.submit_report(uuid,uuid,text,text);
CREATE FUNCTION public.submit_report(p_user_id uuid,p_item_id uuid,p_reason text,p_description text DEFAULT NULL,p_reservation_id uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE target uuid; rental public.reservations;
BEGIN
 -- Restricted participants still need to report a problem with an existing transaction.
 PERFORM 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION '계정에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
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
  IF NOT FOUND OR target<>CASE WHEN rental.borrower_id=auth.uid() THEN rental.lender_id ELSE rental.borrower_id END
  OR (p_item_id IS NOT NULL AND p_item_id<>rental.item_id) THEN RAISE EXCEPTION '거래에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
 ELSE PERFORM public.assert_active_account(); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||target::text||coalesce(p_item_id::text,'')||coalesce(p_reservation_id::text,''),2));
 IF EXISTS(SELECT 1 FROM public.reports WHERE reporter_id=auth.uid() AND reported_user_id=target
  AND reported_item_id IS NOT DISTINCT FROM p_item_id AND reservation_id IS NOT DISTINCT FROM p_reservation_id AND status='pending') THEN RETURN; END IF;
 PERFORM public.require_service_quota(auth.uid(),'report');
 INSERT INTO public.reports(reporter_id,reported_user_id,reported_item_id,reservation_id,reason,description)
 VALUES(auth.uid(),target,p_item_id,p_reservation_id,p_reason,nullif(trim(p_description),''));
END $$;
REVOKE ALL ON FUNCTION public.submit_report(uuid,uuid,text,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.submit_report(uuid,uuid,text,text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.moderate_service(p_actor uuid,p_action text,p_target uuid,p_value boolean DEFAULT NULL,p_reason text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE report public.reports;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor AND raw_app_meta_data->>'dolpin_operator'='true')
 OR NOT public.account_is_active(p_actor) THEN RAISE EXCEPTION 'Operator required' USING ERRCODE='42501'; END IF;
 IF p_action IN ('suspend','item','resolved','dismissed') AND (p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 2 AND 500)
 THEN RAISE EXCEPTION '처리 사유를 입력해 주세요.' USING ERRCODE='22023'; END IF;
 IF p_action='suspend' THEN
  IF p_actor=p_target OR p_value IS NULL THEN RAISE EXCEPTION 'Invalid moderation request' USING ERRCODE='22023'; END IF;
  UPDATE public.users SET suspended_at=CASE WHEN p_value THEN clock_timestamp() ELSE NULL END,
  suspension_reason=CASE WHEN p_value THEN trim(p_reason) ELSE NULL END WHERE id=p_target AND deleted_at IS NULL;
 ELSIF p_action='item' THEN
  IF p_value IS NULL THEN RAISE EXCEPTION 'Invalid moderation request' USING ERRCODE='22023'; END IF;
  UPDATE public.rental_items SET moderated_at=CASE WHEN p_value THEN clock_timestamp() ELSE NULL END,
  status=CASE WHEN p_value THEN 'hidden' ELSE status END WHERE id=p_target;
 ELSIF p_action IN ('resolved','dismissed') THEN
  UPDATE public.reports SET status=p_action,resolved_at=clock_timestamp(),resolution_note=trim(p_reason)
  WHERE id=p_target AND status='pending' RETURNING * INTO report;
 ELSIF p_action='retry_notification' THEN
  UPDATE public.notification_deliveries SET status=CASE WHEN receipt_id IS NOT NULL THEN 'receipt' ELSE 'pending' END,
  next_attempt_at=clock_timestamp(),attempt_count=0,lease_token=NULL,lease_until=NULL
  WHERE id=p_target AND status='review' AND (receipt_id IS NOT NULL OR last_code IN ('PROVIDER_REJECTED','RATE_LIMITED'));
 ELSIF p_action='dismiss_notification' THEN
  UPDATE public.notification_deliveries SET status='failed',last_code='OPERATOR_DISMISSED',lease_token=NULL,lease_until=NULL WHERE id=p_target AND status='review';
 ELSE RAISE EXCEPTION 'Invalid moderation request' USING ERRCODE='22023'; END IF;
 IF NOT FOUND THEN RAISE EXCEPTION 'Target not found' USING ERRCODE='22023'; END IF;
 INSERT INTO public.service_audit(actor_id,action,target_id,reason) VALUES(p_actor,p_action,p_target,left(p_reason,500));
 IF report.id IS NOT NULL THEN
  PERFORM public.enqueue_notification(report.reporter_id,'report:'||report.id||':'||report.status,'support','신고 처리 결과가 등록되었습니다. 내 문의에서 확인해 주세요.',NULL);
 END IF;
END $$;

-- Page management lists instead of making older records unreachable.
DROP FUNCTION public.my_items();
CREATE FUNCTION public.my_items(p_offset integer DEFAULT 0) RETURNS SETOF public.rental_items
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_active_account();
 IF p_offset IS NULL OR p_offset<0 THEN RAISE EXCEPTION '조회 위치를 확인해 주세요.' USING ERRCODE='22023'; END IF;
 RETURN QUERY SELECT * FROM public.rental_items WHERE lender_id=auth.uid() ORDER BY created_at DESC,id DESC LIMIT 50 OFFSET p_offset;
END $$;
DROP FUNCTION public.my_blocked_users();
CREATE FUNCTION public.my_blocked_users(p_offset integer DEFAULT 0) RETURNS TABLE(id uuid,nickname text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_active_account();
 IF p_offset IS NULL OR p_offset<0 THEN RAISE EXCEPTION '조회 위치를 확인해 주세요.' USING ERRCODE='22023'; END IF;
 RETURN QUERY SELECT u.id,u.nickname FROM public.user_blocks b JOIN public.users u ON u.id=b.blocked_id
 WHERE b.blocker_id=auth.uid() ORDER BY b.created_at DESC,b.id DESC LIMIT 50 OFFSET p_offset;
END $$;
REVOKE ALL ON FUNCTION public.my_items(integer),public.my_blocked_users(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.my_items(integer),public.my_blocked_users(integer) TO authenticated;
CREATE INDEX owned_items_page ON public.rental_items(lender_id,created_at DESC,id DESC);
CREATE INDEX owned_blocks_page ON public.user_blocks(blocker_id,created_at DESC,id DESC);
CREATE INDEX owned_reports_page ON public.reports(reporter_id,created_at DESC,id DESC);

CREATE OR REPLACE FUNCTION public.begin_account_closure(p_user_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM 1 FROM public.users WHERE id=p_user_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '계정을 찾을 수 없습니다.' USING ERRCODE='22023'; END IF;
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
 UPDATE public.users SET deleted_at=clock_timestamp(),nickname='탈퇴한 사용자',phone=NULL,profile_image=NULL,region=NULL,
 fav_groups=NULL,fcm_token=NULL,identity_verified=false,is_lender=false WHERE id=p_user_id;
 UPDATE public.rental_items SET status='hidden',pickup_note=NULL,pickup_location=NULL,imei=NULL WHERE lender_id=p_user_id;
 DELETE FROM public.push_tokens WHERE user_id=p_user_id;
 DELETE FROM public.payout_accounts WHERE user_id=p_user_id;
 -- Read access is revoked immediately, even if Auth deletion needs a later retry.
END $$;
