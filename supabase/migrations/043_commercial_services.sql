ALTER TABLE public.users ADD COLUMN suspended_at timestamptz;
ALTER TABLE public.users ADD COLUMN suspension_reason text;
ALTER TABLE public.rental_items ADD COLUMN moderated_at timestamptz;

CREATE FUNCTION public.account_is_active(p_user_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.users WHERE id=p_user_id AND deleted_at IS NULL AND suspended_at IS NULL)
$$;
CREATE FUNCTION public.assert_active_account(p_user_id uuid DEFAULT auth.uid()) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM 1 FROM public.users WHERE id=p_user_id AND deleted_at IS NULL AND suspended_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION '이 계정은 현재 이용할 수 없습니다.' USING ERRCODE='42501'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.assert_active_account(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.account_is_active(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.account_is_active(uuid) TO authenticated,service_role;

CREATE TABLE public.policy_consents (
 user_id uuid NOT NULL REFERENCES public.users(id), terms_version text NOT NULL,
 privacy_version text NOT NULL, accepted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(user_id,terms_version,privacy_version)
);
ALTER TABLE public.policy_consents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.policy_consents FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.consent_status() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('termsVersion','2026-09-22','privacyVersion','2026-09-22','accepted',
 EXISTS(SELECT 1 FROM public.policy_consents WHERE user_id=auth.uid() AND terms_version='2026-09-22' AND privacy_version='2026-09-22'))
$$;
CREATE FUNCTION public.record_consent(p_terms_version text,p_privacy_version text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_active_account();
 IF p_terms_version IS DISTINCT FROM '2026-09-22' OR p_privacy_version IS DISTINCT FROM '2026-09-22'
 THEN RAISE EXCEPTION '최신 약관을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 INSERT INTO public.policy_consents VALUES(auth.uid(),p_terms_version,p_privacy_version,clock_timestamp()) ON CONFLICT DO NOTHING;
END $$;
CREATE FUNCTION public.update_my_profile(p_nickname text,p_region text DEFAULT NULL,p_locale text DEFAULT 'ko')
RETURNS public.users LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE profile public.users;
BEGIN
 PERFORM public.assert_active_account();
 IF p_nickname IS NULL OR length(trim(p_nickname)) NOT BETWEEN 2 AND 30 OR length(p_region)>100
 OR p_locale IS NULL OR p_locale NOT IN ('ko','en','ja','zh') THEN RAISE EXCEPTION '프로필 내용을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 UPDATE public.users SET nickname=trim(p_nickname),region=nullif(trim(p_region),''),locale=p_locale WHERE id=auth.uid() RETURNING * INTO profile;
 RETURN profile;
END $$;
REVOKE UPDATE(nickname,profile_image,fav_groups,region,locale) ON public.users FROM authenticated;

-- New writes serialize with account closure and enforce quotas below all clients.
INSERT INTO public.api_usage_limits VALUES('reservation',6,40),('product-upload',12,80),('evidence-upload',10,80),('message',30,500),('report',3,15)
ON CONFLICT(feature) DO UPDATE SET per_minute=excluded.per_minute,per_day=excluded.per_day;
-- Quotas belong to the application identity, which outlives Auth deidentification.
ALTER TABLE public.api_usage_counters DROP CONSTRAINT api_usage_counters_user_id_fkey;
ALTER TABLE public.api_usage_counters ADD CONSTRAINT api_usage_counters_user_id_fkey
 FOREIGN KEY(user_id) REFERENCES public.users(id) ON DELETE CASCADE NOT VALID;
CREATE FUNCTION public.require_service_quota(p_user_id uuid,p_feature text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE quota jsonb;
BEGIN
 quota:=public.consume_api_quota(p_user_id,p_feature);
 IF NOT (quota->>'allowed')::boolean THEN RAISE EXCEPTION '요청이 많습니다. 잠시 후 다시 시도해 주세요.' USING ERRCODE='P4290'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.require_service_quota(uuid,text) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.users_are_blocked(p_first uuid,p_second uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.user_blocks WHERE (blocker_id=p_first AND blocked_id=p_second) OR (blocker_id=p_second AND blocked_id=p_first))
$$;
REVOKE ALL ON FUNCTION public.users_are_blocked(uuid,uuid) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.guard_new_rental() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 -- This also fences service-role checkout commands started from an older link.
 -- Existing holds must still reconcile after a suspension.
 IF TG_OP='UPDATE' AND NEW.status='accepted' AND OLD.payment_attempt_merchant_uid IS NULL
 AND NEW.payment_attempt_merchant_uid IS NOT NULL THEN
  PERFORM public.assert_active_account(least(NEW.borrower_id,NEW.lender_id));
  PERFORM public.assert_active_account(greatest(NEW.borrower_id,NEW.lender_id));
 END IF;
 IF coalesce(auth.role(),current_setting('role',true)) IN ('service_role','none','postgres','supabase_admin') THEN RETURN NEW; END IF;
 IF TG_OP='INSERT' OR (NEW.status='accepted' AND OLD.status IS DISTINCT FROM NEW.status) THEN
  PERFORM pg_advisory_xact_lock(hashtextextended(least(NEW.borrower_id,NEW.lender_id)::text||greatest(NEW.borrower_id,NEW.lender_id)::text,1));
  PERFORM public.assert_active_account(least(NEW.borrower_id,NEW.lender_id));
  PERFORM public.assert_active_account(greatest(NEW.borrower_id,NEW.lender_id));
  IF public.users_are_blocked(NEW.borrower_id,NEW.lender_id) THEN RAISE EXCEPTION '이 상대와는 새 거래를 시작할 수 없습니다.' USING ERRCODE='42501'; END IF;
  IF EXISTS(SELECT 1 FROM public.rental_items WHERE id=NEW.item_id AND moderated_at IS NOT NULL) THEN RAISE EXCEPTION '이 물품은 거래할 수 없습니다.' USING ERRCODE='42501'; END IF;
 END IF;
 IF TG_OP='INSERT' THEN
  IF NOT EXISTS(SELECT 1 FROM public.policy_consents WHERE user_id=NEW.borrower_id AND terms_version='2026-09-22' AND privacy_version='2026-09-22')
  THEN RAISE EXCEPTION '예약 전에 이용약관과 개인정보 안내를 확인해 주세요.' USING ERRCODE='PCN01'; END IF;
  PERFORM public.require_service_quota(NEW.borrower_id,'reservation');
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER guard_new_rental BEFORE INSERT OR UPDATE ON public.reservations FOR EACH ROW EXECUTE FUNCTION public.guard_new_rental();

CREATE TABLE public.product_photo_deletions (
 path text PRIMARY KEY, claimed_at timestamptz NOT NULL DEFAULT clock_timestamp(), deleted_at timestamptz,
 attempts integer NOT NULL DEFAULT 0, last_attempt_at timestamptz
);
ALTER TABLE public.product_photo_deletions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.product_photo_deletions FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.product_photo_deletions TO service_role;
CREATE FUNCTION public.guard_item_authoring() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE photo text; object_path text;
BEGIN
 -- Service-role moderation and closure cannot be used as a client write bypass.
 IF coalesce(auth.role(),current_setting('role',true)) IN ('service_role','none','postgres','supabase_admin') THEN RETURN NEW; END IF;
 PERFORM public.assert_active_account(NEW.lender_id);
 IF auth.uid() IS DISTINCT FROM NEW.lender_id THEN RAISE EXCEPTION '물품 수정 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 IF NEW.moderated_at IS NOT NULL AND NEW.status='active' THEN RAISE EXCEPTION '운영 검토 중인 물품입니다.' USING ERRCODE='42501'; END IF;
 IF TG_OP='INSERT' AND NOT EXISTS(SELECT 1 FROM public.policy_consents WHERE user_id=NEW.lender_id AND terms_version='2026-09-22' AND privacy_version='2026-09-22')
 THEN RAISE EXCEPTION '등록 전에 이용약관과 개인정보 안내를 확인해 주세요.' USING ERRCODE='PCN01'; END IF;
 IF NEW.status IS NULL OR NEW.status NOT IN ('active','hidden') THEN RAISE EXCEPTION '지원하지 않는 공개 상태입니다.' USING ERRCODE='22023'; END IF;
 IF NEW.currency IS DISTINCT FROM 'KRW' OR NEW.pickup_method IS DISTINCT FROM 'direct'
 OR (NEW.available_from IS NOT NULL AND NOT isfinite(NEW.available_from)) OR (NEW.available_to IS NOT NULL AND NOT isfinite(NEW.available_to))
 THEN RAISE EXCEPTION '물품 거래 조건을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 FOREACH photo IN ARRAY NEW.photos LOOP
  -- Preserve previously accepted legacy photos; newly attached files must be owned uploads.
  IF TG_OP='UPDATE' AND photo=ANY(OLD.photos) THEN CONTINUE; END IF;
  object_path:=split_part(photo,'/storage/v1/object/public/product-photos/',2);
  IF object_path='' OR split_part(object_path,'/',1)<>NEW.lender_id::text OR position('?' IN object_path)>0
  THEN RAISE EXCEPTION '직접 업로드한 상품 사진을 선택해 주세요.' USING ERRCODE='22023'; END IF;
  PERFORM 1 FROM storage.objects WHERE bucket_id='product-photos' AND name=object_path FOR UPDATE;
  IF NOT FOUND OR EXISTS(SELECT 1 FROM public.product_photo_deletions WHERE path=object_path)
  THEN RAISE EXCEPTION '사진을 다시 업로드해 주세요.' USING ERRCODE='22023'; END IF;
 END LOOP;
 RETURN NEW;
END $$;
CREATE TRIGGER guard_item_authoring BEFORE INSERT OR UPDATE ON public.rental_items FOR EACH ROW EXECUTE FUNCTION public.guard_item_authoring();
REVOKE UPDATE(concert_id,category,title,description,photos,daily_price,deposit,pickup_method,available_from,available_to,status,pickup_note,pickup_area) ON public.rental_items FROM authenticated;
REVOKE DELETE ON public.rental_items FROM authenticated;
CREATE FUNCTION public.my_items() RETURNS SETOF public.rental_items LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_active_account();
 RETURN QUERY SELECT * FROM public.rental_items WHERE lender_id=auth.uid() ORDER BY created_at DESC,id DESC LIMIT 200;
END $$;
CREATE FUNCTION public.update_my_item(p_item_id uuid,p_input jsonb) RETURNS public.rental_items
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.rental_items; input public.rental_items;
BEGIN
 PERFORM public.assert_active_account();
 SELECT * INTO item FROM public.rental_items WHERE id=p_item_id AND lender_id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '물품 수정 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 IF jsonb_typeof(p_input) IS DISTINCT FROM 'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_input) k WHERE k NOT IN
 ('title','description','category','concert_id','daily_price','deposit','photos','pickup_method','pickup_area','pickup_note','available_from','available_to'))
 THEN RAISE EXCEPTION '수정할 내용을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 input:=jsonb_populate_record(item,p_input);
 IF input.pickup_method IS DISTINCT FROM 'direct' THEN RAISE EXCEPTION '직접 전달만 지원합니다.' USING ERRCODE='22023'; END IF;
 -- Accepted reservations retain their frozen terms even if the listing changes.
 UPDATE public.rental_items SET title=input.title,description=input.description,category=input.category,
 concert_id=input.concert_id,daily_price=input.daily_price,deposit=input.deposit,photos=input.photos,
 pickup_method=input.pickup_method,pickup_area=input.pickup_area,pickup_note=input.pickup_note,
 available_from=input.available_from,available_to=input.available_to WHERE id=item.id RETURNING * INTO item;
 RETURN item;
END $$;
CREATE FUNCTION public.set_my_item_status(p_item_id uuid,p_status text) RETURNS public.rental_items
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.rental_items;
BEGIN
 PERFORM public.assert_active_account();
 IF p_status IS NULL OR p_status NOT IN ('active','hidden') THEN RAISE EXCEPTION '공개 상태를 확인해 주세요.' USING ERRCODE='22023'; END IF;
 UPDATE public.rental_items SET status=p_status WHERE id=p_item_id AND lender_id=auth.uid() RETURNING * INTO item;
 IF NOT FOUND THEN RAISE EXCEPTION '물품 수정 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 RETURN item;
END $$;
CREATE FUNCTION public.item_availability(p_item_id uuid) RETURNS TABLE(starts_at timestamptz,ends_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(r.starts_at,r.rental_date::timestamp AT TIME ZONE 'Asia/Seoul'),
 coalesce(r.ends_at,r.return_date::timestamp AT TIME ZONE 'Asia/Seoul') FROM public.reservations r
 WHERE r.item_id=p_item_id AND r.status IN ('pending','accepted','paid','picked_up','returned','disputed')
 AND coalesce(r.ends_at,r.return_date::timestamp AT TIME ZONE 'Asia/Seoul')>now()
 AND EXISTS(SELECT 1 FROM public.rental_items i WHERE i.id=p_item_id AND (i.status='active' OR i.lender_id=auth.uid()))
 ORDER BY 1 LIMIT 500
$$;
DROP POLICY "Active items are publicly readable" ON public.rental_items;
CREATE POLICY "Active items are publicly readable" ON public.rental_items FOR SELECT USING(
 lender_id=auth.uid() OR (status='active' AND moderated_at IS NULL AND public.account_is_active(lender_id)));
GRANT EXECUTE ON FUNCTION public.account_is_active(uuid) TO anon;

-- RPC-only social writes prevent spoofed targets, client-written moderation, and content edits.
REVOKE INSERT,UPDATE,DELETE ON public.chat_messages,public.chat_rooms,public.reports,public.user_blocks FROM anon,authenticated;
REVOKE EXECUTE ON FUNCTION public.get_or_create_room(uuid,uuid,uuid,uuid) FROM authenticated;
ALTER TABLE public.chat_messages ADD COLUMN client_request_id uuid;
CREATE UNIQUE INDEX chat_message_request ON public.chat_messages(sender_id,client_request_id) WHERE client_request_id IS NOT NULL;
CREATE INDEX chat_reservation_cursor ON public.chat_messages(reservation_id,created_at DESC,id DESC);
CREATE FUNCTION public.send_rental_message(p_reservation_id uuid,p_message text,p_request_id uuid)
RETURNS public.chat_messages LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE rental public.reservations; message public.chat_messages; receiver uuid; room uuid;
BEGIN
 PERFORM public.assert_active_account();
 IF p_message IS NULL OR length(trim(p_message)) NOT BETWEEN 1 AND 2000 OR p_request_id IS NULL THEN RAISE EXCEPTION '메시지를 2000자 이내로 입력해 주세요.' USING ERRCODE='22023'; END IF;
 SELECT * INTO rental FROM public.reservations WHERE id=p_reservation_id AND auth.uid() IN (borrower_id,lender_id);
 IF NOT FOUND THEN RAISE EXCEPTION '거래에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
 receiver:=CASE WHEN rental.borrower_id=auth.uid() THEN rental.lender_id ELSE rental.borrower_id END;
 PERFORM pg_advisory_xact_lock(hashtextextended(least(auth.uid(),receiver)::text||greatest(auth.uid(),receiver)::text,1));
 IF public.users_are_blocked(auth.uid(),receiver) OR NOT public.account_is_active(receiver) THEN RAISE EXCEPTION '이 상대에게 메시지를 보낼 수 없습니다. 거래 문제는 신고해 주세요.' USING ERRCODE='42501'; END IF;
 -- Serialize client retries before quota and unique insertion.
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request_id::text,0));
 SELECT * INTO message FROM public.chat_messages WHERE sender_id=auth.uid() AND client_request_id=p_request_id;
 IF FOUND THEN
  IF message.reservation_id<>p_reservation_id OR message.message<>trim(p_message) THEN RAISE EXCEPTION '같은 메시지 식별자로 내용을 바꿀 수 없습니다.' USING ERRCODE='22023'; END IF;
  RETURN message;
 END IF;
 PERFORM public.require_service_quota(auth.uid(),'message');
 room:=public.get_or_create_room(auth.uid(),receiver,rental.item_id,rental.id);
 INSERT INTO public.chat_messages(reservation_id,room_id,sender_id,receiver_id,message,client_request_id)
 VALUES(rental.id,room,auth.uid(),receiver,trim(p_message),p_request_id) RETURNING * INTO message;
 RETURN message;
END $$;
CREATE FUNCTION public.mark_rental_messages_read(p_reservation_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION '계정에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.reservations WHERE id=p_reservation_id AND auth.uid() IN (borrower_id,lender_id)) THEN RAISE EXCEPTION '거래에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
 UPDATE public.chat_messages SET read_at=clock_timestamp() WHERE reservation_id=p_reservation_id AND receiver_id=auth.uid() AND read_at IS NULL;
END $$;
CREATE FUNCTION public.set_user_block(p_user_id uuid,p_blocked boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_active_account();
 IF p_user_id IS NULL OR p_user_id=auth.uid() OR p_blocked IS NULL THEN RAISE EXCEPTION '차단 대상을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(least(auth.uid(),p_user_id)::text||greatest(auth.uid(),p_user_id)::text,1));
 -- Do not expose whether an arbitrary private account exists.
 IF p_blocked THEN
  IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=p_user_id) THEN RAISE EXCEPTION '사용자를 찾을 수 없습니다.' USING ERRCODE='22023'; END IF;
  INSERT INTO public.user_blocks(blocker_id,blocked_id) VALUES(auth.uid(),p_user_id) ON CONFLICT DO NOTHING;
 ELSE DELETE FROM public.user_blocks WHERE blocker_id=auth.uid() AND blocked_id=p_user_id;
 END IF;
END $$;
CREATE FUNCTION public.my_blocked_users() RETURNS TABLE(id uuid,nickname text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT u.id,u.nickname FROM public.user_blocks b JOIN public.users u ON u.id=b.blocked_id
 WHERE b.blocker_id=auth.uid() AND public.account_is_active(auth.uid()) ORDER BY b.created_at DESC LIMIT 200
$$;
CREATE FUNCTION public.submit_report(p_user_id uuid,p_item_id uuid,p_reason text,p_description text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE target uuid;
BEGIN
 PERFORM public.assert_active_account();
 IF (p_user_id IS NULL AND p_item_id IS NULL) OR p_reason IS NULL OR p_reason NOT IN ('fraud','abuse','unsafe','prohibited','other') OR length(p_description)>2000 THEN RAISE EXCEPTION '신고 내용을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 target:=p_user_id;
 IF p_item_id IS NOT NULL THEN
  SELECT lender_id INTO target FROM public.rental_items WHERE id=p_item_id;
  IF NOT FOUND OR (p_user_id IS NOT NULL AND p_user_id<>target) THEN RAISE EXCEPTION '신고 대상을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 END IF;
 IF target=auth.uid() THEN RAISE EXCEPTION '본인을 신고할 수 없습니다.' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||target::text||coalesce(p_item_id::text,''),2));
 IF EXISTS(SELECT 1 FROM public.reports WHERE reporter_id=auth.uid() AND reported_user_id=target AND reported_item_id IS NOT DISTINCT FROM p_item_id AND status='pending') THEN RETURN; END IF;
 PERFORM public.require_service_quota(auth.uid(),'report');
 INSERT INTO public.reports(reporter_id,reported_user_id,reported_item_id,reason,description) VALUES(auth.uid(),target,p_item_id,p_reason,nullif(trim(p_description),''));
END $$;

CREATE TABLE public.notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES public.users(id),
 event_key text NOT NULL, kind text NOT NULL, title text NOT NULL, body text NOT NULL,
 reservation_id uuid REFERENCES public.reservations(id), read_at timestamptz, created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(user_id,event_key)
);
CREATE INDEX notifications_inbox ON public.notifications(user_id,created_at DESC,id DESC);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY notification_owner_read ON public.notifications FOR SELECT TO authenticated USING(user_id=auth.uid()
 AND EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NULL));
REVOKE ALL ON public.notifications FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
CREATE TABLE public.push_tokens (
 token text PRIMARY KEY CHECK(token ~ '^(ExponentPushToken|ExpoPushToken)\[[A-Za-z0-9_-]{10,200}\]$'),
 user_id uuid NOT NULL REFERENCES public.users(id), updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX push_tokens_owner ON public.push_tokens(user_id);
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.push_tokens FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.push_tokens TO service_role;
CREATE TABLE public.notification_deliveries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), notification_id uuid NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
 token text NOT NULL REFERENCES public.push_tokens(token) ON DELETE CASCADE,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','sending','receipt','sent','review','failed')),
 attempt_count integer NOT NULL DEFAULT 0, receipt_id text, next_attempt_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 lease_token uuid, lease_until timestamptz, last_code text, UNIQUE(notification_id,token)
);
CREATE INDEX notification_delivery_due ON public.notification_deliveries(next_attempt_at) WHERE status IN ('pending','receipt','sending');
ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notification_deliveries FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.notification_deliveries TO service_role;
CREATE FUNCTION public.register_push_token(p_token text,p_enabled boolean DEFAULT true) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.' USING ERRCODE='42501'; END IF;
 IF p_enabled THEN
  PERFORM public.assert_active_account();
  PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text,3));
  IF p_token IS NULL OR p_token !~ '^(ExponentPushToken|ExpoPushToken)\[[A-Za-z0-9_-]{10,200}\]$' THEN RAISE EXCEPTION '알림 기기 정보를 확인해 주세요.' USING ERRCODE='22023'; END IF;
  -- Reassignment removes old queued deliveries so a shared device cannot leak a previous account's alerts.
  DELETE FROM public.push_tokens WHERE token=p_token AND user_id<>auth.uid();
  IF (SELECT count(*) FROM public.push_tokens WHERE user_id=auth.uid())>=10 AND NOT EXISTS(SELECT 1 FROM public.push_tokens WHERE token=p_token) THEN RAISE EXCEPTION '등록할 수 있는 기기 수를 초과했습니다.' USING ERRCODE='22023'; END IF;
  INSERT INTO public.push_tokens(token,user_id) VALUES(p_token,auth.uid()) ON CONFLICT(token) DO UPDATE SET updated_at=clock_timestamp() WHERE public.push_tokens.user_id=auth.uid();
 ELSE DELETE FROM public.push_tokens WHERE token=p_token AND user_id=auth.uid();
 END IF;
END $$;
CREATE FUNCTION public.enqueue_notification(p_user_id uuid,p_event_key text,p_kind text,p_body text,p_reservation_id uuid DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE notification uuid;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=p_user_id AND deleted_at IS NULL) THEN RETURN; END IF;
 INSERT INTO public.notifications(user_id,event_key,kind,title,body,reservation_id)
 VALUES(p_user_id,p_event_key,p_kind,'dol-pin',p_body,p_reservation_id) ON CONFLICT DO NOTHING RETURNING id INTO notification;
 IF notification IS NOT NULL THEN
  INSERT INTO public.notification_deliveries(notification_id,token) SELECT notification,token FROM public.push_tokens WHERE user_id=p_user_id;
 END IF;
END $$;
CREATE FUNCTION public.notify_rental_change() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE message text;
BEGIN
 IF TG_OP='UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
 message:=CASE NEW.status WHEN 'requested' THEN '새 대여 요청이 도착했습니다.' WHEN 'accepted' THEN '대여 요청이 수락되었습니다. 결제 기한을 확인해 주세요.'
 WHEN 'paid' THEN '결제가 완료되었습니다. 거래 약속을 확인해 주세요.' WHEN 'picked_up' THEN '물품 인수가 확인되었습니다.' WHEN 'returned' THEN '반납이 접수되었습니다. 물품 상태를 확인해 주세요.'
 WHEN 'settled' THEN '반납과 보증금 반환이 처리되었습니다.' WHEN 'disputed' THEN '거래 문제 확인이 접수되었습니다.' WHEN 'resolved' THEN '거래 문제 처리가 완료되었습니다.'
 WHEN 'rejected' THEN '이번 대여 요청이 거절되었습니다.' WHEN 'expired' THEN '결제 기한이 지나 대여 요청이 만료되었습니다.' WHEN 'cancelled' THEN '거래 취소가 처리되었습니다.' ELSE NULL END;
 IF message IS NULL THEN RETURN NEW; END IF;
 PERFORM public.enqueue_notification(NEW.borrower_id,'rental:'||NEW.id||':'||NEW.status,'rental',message,NEW.id);
 PERFORM public.enqueue_notification(NEW.lender_id,'rental:'||NEW.id||':'||NEW.status,'rental',message,NEW.id);
 RETURN NEW;
END $$;
CREATE TRIGGER notify_rental_change AFTER INSERT OR UPDATE OF status ON public.reservations FOR EACH ROW EXECUTE FUNCTION public.notify_rental_change();
CREATE FUNCTION public.notify_rental_message() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.enqueue_notification(NEW.receiver_id,'message:'||NEW.id,'message','새 거래 메시지가 도착했습니다.',NEW.reservation_id);
 RETURN NEW;
END $$;
CREATE TRIGGER notify_rental_message AFTER INSERT ON public.chat_messages FOR EACH ROW EXECUTE FUNCTION public.notify_rental_message();
CREATE FUNCTION public.mark_notification_read(p_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN UPDATE public.notifications SET read_at=coalesce(read_at,clock_timestamp()) WHERE id=p_id AND user_id=auth.uid(); END $$;

CREATE FUNCTION public.claim_notification_deliveries(p_lease uuid) RETURNS SETOF public.notification_deliveries
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 -- A worker may have sent a push before losing its lease; replaying could duplicate it.
 UPDATE public.notification_deliveries SET status='review',last_code='SEND_OUTCOME_UNKNOWN',lease_token=NULL,lease_until=NULL WHERE status='sending' AND lease_until<=clock_timestamp();
 RETURN QUERY WITH due AS (
 SELECT id FROM public.notification_deliveries WHERE status IN ('pending','receipt') AND next_attempt_at<=clock_timestamp()
 AND (lease_until IS NULL OR lease_until<=clock_timestamp()) ORDER BY next_attempt_at FOR UPDATE SKIP LOCKED LIMIT 40
 ) UPDATE public.notification_deliveries d SET lease_token=p_lease,lease_until=clock_timestamp()+interval '3 minutes',attempt_count=attempt_count+1,
 status=CASE WHEN status='pending' THEN 'sending' ELSE status END FROM due WHERE d.id=due.id RETURNING d.*;
END $$;
CREATE FUNCTION public.finish_notification_delivery(p_id uuid,p_lease uuid,p_status text,p_receipt text DEFAULT NULL,p_code text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_status IS NULL OR p_status NOT IN ('pending','receipt','sent','review','failed') OR (p_status='receipt' AND nullif(p_receipt,'') IS NULL) OR length(p_code)>64 THEN RAISE EXCEPTION 'Invalid delivery result'; END IF;
 UPDATE public.notification_deliveries SET status=CASE WHEN (p_status='pending' AND attempt_count>=8) OR (p_status='receipt' AND attempt_count>=12) THEN 'review' ELSE p_status END,
 receipt_id=CASE WHEN p_status='pending' THEN NULL ELSE coalesce(p_receipt,receipt_id) END,last_code=p_code,lease_token=NULL,lease_until=NULL,
 next_attempt_at=clock_timestamp()+CASE WHEN p_status='receipt' THEN interval '15 minutes' ELSE make_interval(secs=>least(3600,30*power(2,least(attempt_count,7)))::integer) END
 WHERE id=p_id AND lease_token=p_lease AND lease_until>clock_timestamp();
END $$;

-- Product-only cleanup. Frozen rental photos and all transaction evidence are retained.
CREATE FUNCTION public.claim_orphan_product_photos() RETURNS SETOF text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE object record;
BEGIN
 FOR object IN SELECT o.name FROM storage.objects o WHERE o.bucket_id='product-photos' AND o.created_at<clock_timestamp()-interval '24 hours'
 AND NOT EXISTS(SELECT 1 FROM public.product_photo_deletions d WHERE d.path=o.name)
 AND NOT EXISTS(SELECT 1 FROM public.rental_items i,unnest(i.photos) p WHERE split_part(p,'/storage/v1/object/public/product-photos/',2)=o.name)
 AND NOT EXISTS(SELECT 1 FROM public.reservations r,jsonb_array_elements_text(CASE WHEN jsonb_typeof(r.terms_snapshot->'photos')='array' THEN r.terms_snapshot->'photos' ELSE '[]'::jsonb END) p
  WHERE split_part(p,'/storage/v1/object/public/product-photos/',2)=o.name)
 ORDER BY o.created_at LIMIT 50 FOR UPDATE OF o SKIP LOCKED LOOP
  INSERT INTO public.product_photo_deletions(path) VALUES(object.name) ON CONFLICT DO NOTHING;
 END LOOP;
 RETURN QUERY UPDATE public.product_photo_deletions SET attempts=attempts+1,last_attempt_at=clock_timestamp()
 WHERE path IN(SELECT path FROM public.product_photo_deletions WHERE deleted_at IS NULL AND (last_attempt_at IS NULL OR last_attempt_at<clock_timestamp()-interval '1 hour') ORDER BY claimed_at LIMIT 50)
 RETURNING path;
END $$;
CREATE FUNCTION public.guard_storage_upload() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF coalesce(auth.role(),current_setting('role',true)) IN ('service_role','none','postgres','supabase_admin') THEN RETURN NEW; END IF;
 IF NEW.bucket_id IN ('product-photos','rental-evidence','dispute-evidence','rental-photos','profile-photos','chat-images') THEN
  IF NEW.bucket_id IN ('rental-evidence','dispute-evidence') THEN
   -- A suspended participant still needs to return property and submit evidence.
   PERFORM 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NULL FOR SHARE;
   IF NOT FOUND THEN RAISE EXCEPTION '계정에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
  ELSE PERFORM public.assert_active_account(); END IF;
  PERFORM public.require_service_quota(auth.uid(),CASE WHEN NEW.bucket_id IN ('rental-evidence','dispute-evidence') THEN 'evidence-upload' ELSE 'product-upload' END);
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER guard_storage_upload BEFORE INSERT ON storage.objects FOR EACH ROW EXECUTE FUNCTION public.guard_storage_upload();

CREATE TABLE public.account_closures (
 user_id uuid PRIMARY KEY REFERENCES public.users(id), requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 auth_deleted_at timestamptz, attempts integer NOT NULL DEFAULT 0,last_attempt_at timestamptz
);
ALTER TABLE public.account_closures ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_closures FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.account_closures TO service_role;
CREATE FUNCTION public.begin_account_closure(p_user_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM 1 FROM public.users WHERE id=p_user_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '계정을 찾을 수 없습니다.' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM public.account_closures WHERE user_id=p_user_id) THEN RETURN; END IF;
 IF EXISTS(SELECT 1 FROM public.reservations WHERE p_user_id IN (borrower_id,lender_id) AND
 (status IN ('requested','accepted','pending','paid','picked_up','returned','disputed') OR payment_action IS NOT NULL OR payment_attempt_merchant_uid IS NOT NULL))
 OR EXISTS(SELECT 1 FROM public.rental_payouts WHERE lender_id=p_user_id AND status<>'paid' AND net_amount>0)
 OR EXISTS(SELECT 1 FROM public.reservations r WHERE p_user_id IN (r.borrower_id,r.lender_id) AND r.status='resolved'
  AND NOT EXISTS(SELECT 1 FROM public.reservation_dispute_resolutions d WHERE d.reservation_id=r.id))
 THEN RAISE EXCEPTION '진행 중인 거래와 지급을 마친 뒤 탈퇴해 주세요.' USING ERRCODE='PCL01'; END IF;
 INSERT INTO public.account_closures(user_id) VALUES(p_user_id);
 UPDATE public.users SET deleted_at=clock_timestamp(),nickname='탈퇴한 사용자',phone=NULL,profile_image=NULL,region=NULL,
 fav_groups=NULL,fcm_token=NULL,identity_verified=false,is_lender=false WHERE id=p_user_id;
 UPDATE public.rental_items SET status='hidden',pickup_note=NULL,pickup_location=NULL,imei=NULL WHERE lender_id=p_user_id;
 DELETE FROM public.push_tokens WHERE user_id=p_user_id;
 DELETE FROM public.payout_accounts WHERE user_id=p_user_id;
 -- Read access is revoked immediately, even if Auth deletion needs a later retry.
END $$;
CREATE FUNCTION public.account_session_open() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NULL)
$$;
REVOKE ALL ON FUNCTION public.account_session_open() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.account_session_open() TO authenticated;
CREATE POLICY open_account_reservations ON public.reservations AS RESTRICTIVE FOR SELECT TO authenticated USING(public.account_session_open());
CREATE POLICY open_account_messages ON public.chat_messages AS RESTRICTIVE FOR SELECT TO authenticated USING(public.account_session_open());
CREATE POLICY open_account_rooms ON public.chat_rooms AS RESTRICTIVE FOR SELECT TO authenticated USING(public.account_session_open());
CREATE POLICY open_account_users ON public.users AS RESTRICTIVE FOR SELECT TO authenticated USING(public.account_session_open());
CREATE POLICY open_account_storage ON storage.objects AS RESTRICTIVE FOR ALL TO authenticated
 USING(public.account_session_open()) WITH CHECK(public.account_session_open());

-- Auth refresh revocation does not invalidate an already signed JWT instantly.
-- This guard covers legacy SECURITY DEFINER RPCs as well as ordinary RLS reads.
CREATE FUNCTION public.require_open_session() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NOT NULL AND auth.role()<>'service_role'
 AND EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NOT NULL)
 THEN RAISE EXCEPTION '탈퇴 처리된 계정입니다.' USING ERRCODE='42501'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.require_open_session() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.require_open_session() TO anon,authenticated,service_role;
ALTER ROLE authenticator SET pgrst.db_pre_request='public.require_open_session';
NOTIFY pgrst,'reload config';

CREATE TABLE public.service_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, actor_id uuid NOT NULL, action text NOT NULL, target_id uuid NOT NULL,
 reason text, created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.service_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.service_audit FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.service_audit TO service_role;
CREATE FUNCTION public.moderate_service(p_actor uuid,p_action text,p_target uuid,p_value boolean DEFAULT NULL,p_reason text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor AND raw_app_meta_data->>'dolpin_operator'='true') THEN RAISE EXCEPTION 'Operator required' USING ERRCODE='42501'; END IF;
 IF p_action='suspend' THEN
  IF p_actor=p_target OR p_value IS NULL OR (p_value AND (p_reason IS NULL OR length(trim(p_reason)) NOT BETWEEN 2 AND 500)) THEN RAISE EXCEPTION 'Invalid moderation request' USING ERRCODE='22023'; END IF;
  UPDATE public.users SET suspended_at=CASE WHEN p_value THEN clock_timestamp() ELSE NULL END,suspension_reason=CASE WHEN p_value THEN trim(p_reason) ELSE NULL END WHERE id=p_target AND deleted_at IS NULL;
 ELSIF p_action='item' THEN
  IF p_value IS NULL THEN RAISE EXCEPTION 'Invalid moderation request' USING ERRCODE='22023'; END IF;
  UPDATE public.rental_items SET moderated_at=CASE WHEN p_value THEN clock_timestamp() ELSE NULL END,
  status=CASE WHEN p_value THEN 'hidden' ELSE status END WHERE id=p_target;
 ELSIF p_action IN ('resolved','dismissed') THEN
  UPDATE public.reports SET status=p_action,resolved_at=clock_timestamp() WHERE id=p_target;
 ELSIF p_action='retry_notification' THEN
  UPDATE public.notification_deliveries SET status=CASE WHEN receipt_id IS NOT NULL THEN 'receipt' ELSE 'pending' END,
  next_attempt_at=clock_timestamp(),attempt_count=0,lease_token=NULL,lease_until=NULL
  WHERE id=p_target AND status='review' AND (receipt_id IS NOT NULL OR last_code IN ('PROVIDER_REJECTED','RATE_LIMITED'));
 ELSIF p_action='dismiss_notification' THEN
  UPDATE public.notification_deliveries SET status='failed',last_code='OPERATOR_DISMISSED',lease_token=NULL,lease_until=NULL WHERE id=p_target AND status='review';
 ELSE RAISE EXCEPTION 'Invalid moderation request' USING ERRCODE='22023'; END IF;
 IF NOT FOUND THEN RAISE EXCEPTION 'Target not found' USING ERRCODE='22023'; END IF;
 INSERT INTO public.service_audit(actor_id,action,target_id,reason) VALUES(p_actor,p_action,p_target,left(p_reason,500));
END $$;

CREATE TABLE public.service_dispatches(request_id bigint PRIMARY KEY,created_at timestamptz NOT NULL DEFAULT clock_timestamp());
ALTER TABLE public.service_dispatches ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.service_dispatches FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.service_dispatches TO service_role;
CREATE FUNCTION public.invoke_service_delivery() RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE endpoint text;token text;request_id bigint;
BEGIN
 SELECT decrypted_secret INTO endpoint FROM vault.decrypted_secrets WHERE name='dolpin_service_delivery_url';
 SELECT decrypted_secret INTO token FROM vault.decrypted_secrets WHERE name='dolpin_service_delivery_token';
 IF endpoint IS NULL OR token IS NULL THEN RETURN NULL; END IF;
 SELECT net.http_post(url:=endpoint,headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||token),body:='{}'::jsonb,timeout_milliseconds:=60000) INTO request_id;
 INSERT INTO public.service_dispatches VALUES(request_id,clock_timestamp());
 DELETE FROM public.service_dispatches WHERE created_at<clock_timestamp()-interval '7 days';
 RETURN request_id;
END $$;
CREATE FUNCTION public.service_health() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('configured',(SELECT count(*)=2 FROM vault.secrets WHERE name IN ('dolpin_service_delivery_url','dolpin_service_delivery_token')),
 'scheduled',coalesce((SELECT active FROM cron.job WHERE jobname='dolpin-service-delivery'),false),
 'pushNeedsReview',(SELECT count(*) FROM public.notification_deliveries WHERE status='review'),
 'pendingClosures',(SELECT count(*) FROM public.account_closures WHERE auth_deleted_at IS NULL),
 'photoCleanupNeedsReview',(SELECT count(*) FROM public.product_photo_deletions WHERE deleted_at IS NULL AND attempts>=5),
 'pendingReports',(SELECT count(*) FROM public.reports WHERE status='pending'),
 'rentalReviews',(SELECT count(*) FROM public.rental_operator_reviews WHERE closed_at IS NULL),
 'payoutNeedsReview',(SELECT count(*) FROM public.rental_payouts WHERE status='failed' OR (status='processing' AND claimed_at<clock_timestamp()-interval '1 hour')),
 'paymentRecoveryStalled',(SELECT count(*) FROM public.rental_recovery_queue WHERE review_required_at IS NULL AND next_attempt_at<clock_timestamp()-interval '15 minutes'),
 'lastDispatch',(SELECT jsonb_build_object('at',d.created_at,'status',r.status_code,'timedOut',r.timed_out)
 FROM public.service_dispatches d LEFT JOIN net._http_response r ON r.id=d.request_id ORDER BY d.created_at DESC LIMIT 1),
 'payments',public.rental_recovery_health())
$$;
CREATE TABLE public.service_alert_state (
 id boolean PRIMARY KEY DEFAULT true CHECK(id),last_signature text,last_sent_at timestamptz,
 pending_signature text,lease_token uuid,lease_until timestamptz,next_attempt_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
INSERT INTO public.service_alert_state(id) VALUES(true);
ALTER TABLE public.service_alert_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.service_alert_state FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.claim_service_alert(p_signature text,p_lease uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_signature IS NULL OR length(p_signature)>128 OR p_lease IS NULL THEN RAISE EXCEPTION 'Invalid alert claim'; END IF;
 UPDATE public.service_alert_state SET pending_signature=p_signature,lease_token=p_lease,lease_until=clock_timestamp()+interval '1 minute'
 WHERE id AND (lease_until IS NULL OR lease_until<=clock_timestamp()) AND next_attempt_at<=clock_timestamp()
 AND (last_signature IS DISTINCT FROM p_signature OR last_sent_at<clock_timestamp()-interval '24 hours');
 RETURN FOUND;
END $$;
CREATE FUNCTION public.finish_service_alert(p_lease uuid,p_success boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.service_alert_state SET last_signature=CASE WHEN p_success THEN pending_signature ELSE last_signature END,
 last_sent_at=CASE WHEN p_success THEN clock_timestamp() ELSE last_sent_at END,lease_token=NULL,lease_until=NULL,
 next_attempt_at=clock_timestamp()+CASE WHEN p_success THEN interval '5 minutes' ELSE interval '1 hour' END
 WHERE id AND lease_token=p_lease AND lease_until>clock_timestamp();
END $$;
CREATE FUNCTION public.queue_service_reminders() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE rental record;operator record;needs_review boolean;
BEGIN
 PERFORM public.refresh_rental_operator_reviews();
 FOR rental IN SELECT r.id,r.borrower_id,r.lender_id,r.status FROM public.reservations r WHERE
 ((r.status='accepted' AND r.payment_due_at>clock_timestamp() AND r.payment_due_at<=clock_timestamp()+interval '5 minutes') OR
 (r.status='picked_up' AND r.ends_at<clock_timestamp()+interval '2 hours') OR
 (r.status='returned' AND r.return_confirmed_at<clock_timestamp()-interval '24 hours'))
 AND NOT EXISTS(SELECT 1 FROM public.notifications n WHERE n.user_id=r.borrower_id
  AND n.event_key='reminder:'||r.id||':'||r.status||':'||current_date)
 ORDER BY r.created_at,r.id LIMIT 500 LOOP
  PERFORM public.enqueue_notification(rental.borrower_id,'reminder:'||rental.id||':'||rental.status||':'||current_date,'reminder',
   CASE rental.status WHEN 'accepted' THEN '결제 기한이 곧 끝납니다. 거래 내역을 확인해 주세요.' WHEN 'picked_up' THEN '반납 예정 시각을 확인해 주세요.' ELSE '반납 확인을 기다리고 있습니다. 지연되면 거래 문제를 접수해 주세요.' END,rental.id);
  IF rental.status='returned' THEN PERFORM public.enqueue_notification(rental.lender_id,'reminder:'||rental.id||':returned:'||current_date,'reminder','반납 확인이 지연되고 있습니다. 물품 상태를 확인해 주세요.',rental.id); END IF;
 END LOOP;
 needs_review:=EXISTS(SELECT 1 FROM public.rental_recovery_queue WHERE review_required_at IS NOT NULL)
 OR EXISTS(SELECT 1 FROM public.rental_recovery_queue WHERE next_attempt_at<clock_timestamp()-interval '15 minutes')
 OR EXISTS(SELECT 1 FROM public.reports WHERE status='pending')
 OR EXISTS(SELECT 1 FROM public.notification_deliveries WHERE status='review')
 OR EXISTS(SELECT 1 FROM public.product_photo_deletions WHERE deleted_at IS NULL AND attempts>=5)
 OR EXISTS(SELECT 1 FROM public.rental_operator_reviews WHERE closed_at IS NULL)
 OR EXISTS(SELECT 1 FROM public.rental_payouts WHERE status='failed' OR (status='processing' AND claimed_at<clock_timestamp()-interval '1 hour'))
 OR EXISTS(SELECT 1 FROM public.account_closures WHERE auth_deleted_at IS NULL AND requested_at<clock_timestamp()-interval '1 hour');
 IF needs_review THEN
  FOR operator IN SELECT id FROM auth.users WHERE raw_app_meta_data->>'dolpin_operator'='true' LOOP
   PERFORM public.enqueue_notification(operator.id,'operations:'||current_date,'operations','운영 확인이 필요한 항목이 있습니다. 운영 화면을 확인해 주세요.');
  END LOOP;
 END IF;
END $$;
CREATE FUNCTION public.notify_operator_review() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE operator record;
BEGIN
 FOR operator IN SELECT u.id FROM auth.users u JOIN public.users p ON p.id=u.id WHERE u.raw_app_meta_data->>'dolpin_operator'='true' LOOP
  PERFORM public.enqueue_notification(operator.id,'review:'||NEW.id,'operations','운영 검토할 거래가 있습니다.',NEW.reservation_id);
 END LOOP;
 RETURN NEW;
END $$;
CREATE TRIGGER notify_operator_review AFTER INSERT ON public.rental_operator_reviews FOR EACH ROW EXECUTE FUNCTION public.notify_operator_review();
CREATE FUNCTION public.notify_payout_change() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.status='paid' AND OLD.status IS DISTINCT FROM NEW.status THEN
  PERFORM public.enqueue_notification(NEW.lender_id,'payout:'||NEW.id||':paid','payout','대여료 지급 처리가 기록되었습니다. 지급 내역을 확인해 주세요.',NEW.reservation_id);
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER notify_payout_change AFTER UPDATE OF status ON public.rental_payouts FOR EACH ROW EXECUTE FUNCTION public.notify_payout_change();
SELECT cron.schedule('dolpin-service-delivery','* * * * *','select public.invoke_service_delivery()');

-- Every definer is explicitly classified; no accidental default PUBLIC execute.
REVOKE ALL ON FUNCTION public.consent_status(),public.record_consent(text,text),public.update_my_profile(text,text,text),
 public.my_items(),public.update_my_item(uuid,jsonb),public.set_my_item_status(uuid,text),public.item_availability(uuid),
 public.send_rental_message(uuid,text,uuid),public.mark_rental_messages_read(uuid),public.set_user_block(uuid,boolean),public.my_blocked_users(),
 public.submit_report(uuid,uuid,text,text),public.register_push_token(text,boolean),public.mark_notification_read(uuid)
 FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.consent_status(),public.record_consent(text,text),public.update_my_profile(text,text,text),
 public.my_items(),public.update_my_item(uuid,jsonb),public.set_my_item_status(uuid,text),public.item_availability(uuid),
 public.send_rental_message(uuid,text,uuid),public.mark_rental_messages_read(uuid),public.set_user_block(uuid,boolean),public.my_blocked_users(),
 public.submit_report(uuid,uuid,text,text),public.register_push_token(text,boolean),public.mark_notification_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.item_availability(uuid) TO anon;
REVOKE ALL ON FUNCTION public.guard_new_rental(),public.guard_item_authoring(),public.notify_rental_change(),public.notify_rental_message(),public.guard_storage_upload(),public.notify_operator_review(),public.notify_payout_change(),
 public.enqueue_notification(uuid,text,text,text,uuid),public.claim_notification_deliveries(uuid),public.finish_notification_delivery(uuid,uuid,text,text,text),
 public.claim_orphan_product_photos(),public.begin_account_closure(uuid),public.moderate_service(uuid,text,uuid,boolean,text),
 public.invoke_service_delivery(),public.service_health(),public.queue_service_reminders(),public.claim_service_alert(text,uuid),public.finish_service_alert(uuid,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.enqueue_notification(uuid,text,text,text,uuid),public.claim_notification_deliveries(uuid),
 public.finish_notification_delivery(uuid,uuid,text,text,text),public.claim_orphan_product_photos(),public.begin_account_closure(uuid),
 public.moderate_service(uuid,text,uuid,boolean,text),public.invoke_service_delivery(),public.service_health(),public.queue_service_reminders(),public.claim_service_alert(text,uuid),public.finish_service_alert(uuid,boolean) TO service_role;
