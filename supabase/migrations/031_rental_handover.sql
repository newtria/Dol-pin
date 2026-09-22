ALTER TABLE public.rental_items ADD COLUMN pickup_note text;
ALTER TABLE public.rental_items ADD CONSTRAINT pickup_note_length CHECK(length(pickup_note) BETWEEN 2 AND 300);
GRANT INSERT(pickup_note),UPDATE(pickup_note) ON public.rental_items TO authenticated;

CREATE OR REPLACE FUNCTION public.respond_to_rental(p_reservation_id uuid, p_action text)
RETURNS public.reservations
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor uuid := auth.uid(); rental public.reservations%ROWTYPE;
  item public.rental_items%ROWTYPE; item_id uuid; target public.reservation_status;
BEGIN
  IF actor IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.' USING ERRCODE = '42501'; END IF;
  IF p_action IS NULL OR p_action NOT IN ('accept', 'reject', 'cancel') THEN RAISE EXCEPTION '허용되지 않은 명령입니다.'; END IF;
  SELECT r.item_id INTO item_id FROM public.reservations r WHERE r.id = p_reservation_id
    AND (r.borrower_id = actor OR r.lender_id = actor);
  IF NOT FOUND THEN RAISE EXCEPTION '거래에 접근할 수 없습니다.' USING ERRCODE = '42501'; END IF;
  SELECT * INTO item FROM public.rental_items i WHERE i.id = item_id FOR UPDATE;
  SELECT * INTO rental FROM public.reservations WHERE id = p_reservation_id FOR UPDATE;
  IF (p_action IN ('accept', 'reject') AND actor <> rental.lender_id)
    OR (p_action = 'cancel' AND actor <> rental.borrower_id) THEN
    RAISE EXCEPTION '이 작업을 수행할 권한이 없습니다.' USING ERRCODE = '42501';
  END IF;
  target := CASE p_action WHEN 'accept' THEN 'accepted'::public.reservation_status
    WHEN 'reject' THEN 'rejected'::public.reservation_status ELSE 'cancelled'::public.reservation_status END;
  IF rental.status = target THEN RETURN rental; END IF;
  IF rental.status <> 'requested' THEN RAISE EXCEPTION '현재 거래 상태에서 처리할 수 없습니다.'; END IF;
  IF p_action = 'accept' THEN
    IF item.updated_at IS DISTINCT FROM rental.quoted_item_version OR item.status <> 'active' THEN
      RAISE EXCEPTION '요청 이후 상품 조건이 변경되었습니다. 새 예약 요청이 필요합니다.';
    END IF;
    IF rental.starts_at <= clock_timestamp() THEN RAISE EXCEPTION '대여 시작 시각이 지났습니다.'; END IF;
  END IF;
  PERFORM set_config('app.reservation_status_rpc', 'on', true);
  UPDATE public.reservations SET status = target,
    accepted_at = CASE WHEN p_action = 'accept' THEN clock_timestamp() ELSE accepted_at END,
    payment_due_at = CASE WHEN p_action = 'accept' THEN least(clock_timestamp() + interval '20 minutes', starts_at) ELSE payment_due_at END,
    terms_snapshot = CASE WHEN p_action = 'accept' THEN jsonb_build_object(
      'version', 2, 'description', item.description, 'pickup_note', item.pickup_note, 'item_id', item.id, 'title', item.title, 'category', item.category,
      'photos', item.photos, 'daily_price', item.daily_price, 'deposit', rental.deposit,
      'rental_fee', rental.rental_fee, 'total', rental.total_paid, 'currency', rental.currency,
      'starts_at', rental.starts_at, 'ends_at', rental.ends_at, 'timezone', 'Asia/Seoul',
      'billing', 'ceil_24h', 'pickup_method', item.pickup_method, 'pickup_location', item.pickup_location)
      ELSE terms_snapshot END
    WHERE id = rental.id RETURNING * INTO rental;
  INSERT INTO public.rental_events(reservation_id, actor_id, command, from_status, to_status)
    VALUES(rental.id, actor, CASE p_action WHEN 'accept' THEN 'acceptRental' WHEN 'reject' THEN 'rejectRental' ELSE 'cancelRental' END, 'requested', target);
  RETURN rental;
END $$;

-- New return evidence is private and immutable once uploaded. Old public
-- evidence is retained for legacy transactions, never used by the new clients.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES('rental-evidence','rental-evidence',false,5242880,ARRAY['image/jpeg','image/png','image/webp']);
CREATE POLICY rental_evidence_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(
 bucket_id='rental-evidence' AND (storage.foldername(name))[2]=auth.uid()::text
 AND EXISTS(SELECT 1 FROM public.reservations r WHERE r.id::text=(storage.foldername(name))[1] AND r.borrower_id=auth.uid() AND r.status='picked_up' AND r.payment_action IS NULL));
CREATE POLICY rental_evidence_read ON storage.objects FOR SELECT TO authenticated USING(
 bucket_id='rental-evidence' AND EXISTS(SELECT 1 FROM public.reservations r WHERE r.id::text=(storage.foldername(name))[1] AND auth.uid() IN (r.borrower_id,r.lender_id)));

CREATE FUNCTION public.return_rental(p_reservation_id uuid,p_photo_path text)
RETURNS public.reservations LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations;
BEGIN
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id FOR UPDATE;
 IF auth.uid() IS NULL OR r.id IS NULL OR r.borrower_id<>auth.uid() THEN RAISE EXCEPTION '반납 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 IF r.status='returned' AND r.return_photo=p_photo_path THEN RETURN r; END IF;
 IF r.status<>'picked_up' OR r.payment_action IS NOT NULL THEN RAISE EXCEPTION '반납 가능한 거래가 아닙니다.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='rental-evidence' AND name=p_photo_path
 AND (storage.foldername(name))[1]=r.id::text AND (storage.foldername(name))[2]=auth.uid()::text)
 THEN RAISE EXCEPTION '거래에 속한 반납 사진이 필요합니다.'; END IF;
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status='returned',return_photo=p_photo_path,return_confirmed_at=clock_timestamp() WHERE id=r.id RETURNING * INTO r;
 RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.return_rental(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.return_rental(uuid,text) TO authenticated;

-- These transitions previously skipped rental_events entirely.
CREATE FUNCTION public.record_custody_event() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status IN ('picked_up','returned','disputed') THEN
 INSERT INTO public.rental_events(reservation_id,actor_id,command,from_status,to_status)
 VALUES(NEW.id,auth.uid(),CASE NEW.status WHEN 'picked_up' THEN 'pickupRental' WHEN 'returned' THEN 'returnRental' ELSE 'disputeRental' END,OLD.status,NEW.status);
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER rental_custody_event AFTER UPDATE OF status ON public.reservations FOR EACH ROW EXECUTE FUNCTION public.record_custody_event();
