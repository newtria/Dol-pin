-- Resolve only an object's submitted storage identity. Historical public URLs
-- never become fetch targets: readers sign the verified object on this project.
CREATE FUNCTION public.resolve_rental_return_evidence(p_reservation_id uuid,p_reference text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; path text:=p_reference; bucket text;
BEGIN
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id;
 IF r.id IS NULL OR path IS NULL OR length(path)>2000 THEN
  RAISE EXCEPTION '거래 증빙을 찾을 수 없습니다.' USING ERRCODE='P0002';
 END IF;
 IF path ~ '^https?://[A-Za-z0-9.-]+(:[0-9]+)?/storage/v1/object/public/rental-photos/returns/[^?#[:space:]]+$' THEN
  path:=regexp_replace(path,'^https?://[^/]+/storage/v1/object/public/rental-photos/','');
 END IF;
 IF path LIKE r.id::text||'/'||r.borrower_id::text||'/%' THEN
  bucket:='rental-evidence';
 ELSIF path LIKE 'returns/'||r.id::text||'/'||r.borrower_id::text||'/%' THEN
  bucket:='rental-photos';
 ELSE
  RAISE EXCEPTION '거래에 속한 반납 증빙이 아닙니다.' USING ERRCODE='P0002';
 END IF;
 IF path ~ '[%?#[:space:]]' OR position(chr(92) IN path)>0 OR path LIKE '%//%'
  OR path ~ '(^|/)\.{1,2}(/|$)' OR right(path,1)='/'
  OR NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id=bucket AND o.name=path
   AND coalesce(to_jsonb(o)->>'owner_id',to_jsonb(o)->>'owner')=r.borrower_id::text)
 THEN RAISE EXCEPTION '거래 증빙을 찾을 수 없습니다.' USING ERRCODE='P0002'; END IF;
 RETURN jsonb_build_object('bucket',bucket,'path',path);
END $$;
REVOKE ALL ON FUNCTION public.resolve_rental_return_evidence(uuid,text) FROM PUBLIC,anon,authenticated,service_role;

-- The participant supplies a reservation, never a bucket or a replacement URL.
CREATE FUNCTION public.rental_return_evidence(p_reservation_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations;
BEGIN
 PERFORM 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NULL FOR SHARE;
 IF auth.uid() IS NULL OR NOT FOUND THEN RAISE EXCEPTION '거래 접근 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id AND auth.uid() IN (borrower_id,lender_id);
 IF r.id IS NULL THEN RAISE EXCEPTION '거래 접근 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 RETURN public.resolve_rental_return_evidence(r.id,r.return_photo);
END $$;
REVOKE ALL ON FUNCTION public.rental_return_evidence(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.rental_return_evidence(uuid) TO authenticated;

-- Submission and reads use the same object check, so an accepted private
-- reference can always be resolved by the participant and operator readers.
CREATE OR REPLACE FUNCTION public.return_rental(p_reservation_id uuid,p_photo_path text)
RETURNS public.reservations LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; evidence jsonb;
BEGIN
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id FOR UPDATE;
 IF auth.uid() IS NULL OR r.id IS NULL OR r.borrower_id<>auth.uid() THEN RAISE EXCEPTION '반납 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 IF r.status='returned' AND r.return_photo=p_photo_path THEN RETURN r; END IF;
 IF r.status<>'picked_up' OR r.payment_action IS NOT NULL THEN RAISE EXCEPTION '반납 가능한 거래가 아닙니다.'; END IF;
 evidence:=public.resolve_rental_return_evidence(r.id,p_photo_path);
 IF evidence->>'bucket'<>'rental-evidence' THEN RAISE EXCEPTION '거래에 속한 비공개 반납 사진이 필요합니다.'; END IF;
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status='returned',return_photo=evidence->>'path',return_confirmed_at=clock_timestamp()
 WHERE id=r.id RETURNING * INTO r;
 RETURN r;
END $$;

-- Keep the old RPC's response contract, but new timestamp contracts can only
-- submit private evidence through the current command. Legacy rows retain their
-- old upload format and now store its canonical path rather than a caller URL.
CREATE OR REPLACE FUNCTION public.confirm_reservation_return(p_reservation_id uuid,p_return_photo text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; evidence jsonb; already boolean;
BEGIN
 PERFORM 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NULL FOR SHARE;
 IF auth.uid() IS NULL OR NOT FOUND THEN RAISE EXCEPTION '반납 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id FOR UPDATE;
 IF r.id IS NULL OR r.borrower_id<>auth.uid() THEN RAISE EXCEPTION '반납 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 already:=r.status='returned';
 IF r.starts_at IS NOT NULL OR p_return_photo LIKE r.id::text||'/%' THEN
  PERFORM public.return_rental(p_reservation_id,p_return_photo);
  RETURN jsonb_build_object('ok',true,'status','returned','already',already);
 END IF;
 evidence:=public.resolve_rental_return_evidence(r.id,p_return_photo);
 IF already AND public.resolve_rental_return_evidence(r.id,r.return_photo)=evidence THEN
  RETURN jsonb_build_object('ok',true,'status','returned','already',true);
 END IF;
 IF r.status<>'picked_up' OR r.payment_action IS NOT NULL THEN RAISE EXCEPTION '반납 가능한 거래가 아닙니다.'; END IF;
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status='returned',return_photo=evidence->>'path',return_confirmed_at=clock_timestamp() WHERE id=r.id;
 RETURN jsonb_build_object('ok',true,'status','returned','already',false);
END $$;

-- Preserve the service RPC's text result for already deployed callers. The
-- normalized prefix determines the bucket; no arbitrary URL is ever returned.
CREATE OR REPLACE FUNCTION public.finance_evidence_access(p_reservation_id uuid,p_actor uuid,p_kind text,p_path text DEFAULT NULL)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; path text; evidence jsonb;
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id;
 IF r.id IS NULL THEN RAISE EXCEPTION '거래를 찾을 수 없습니다.' USING ERRCODE='P0002'; END IF;
 IF p_kind='dispute' THEN
  IF p_path IS NULL OR NOT EXISTS(SELECT 1 FROM public.rental_disputes d WHERE d.reservation_id=r.id AND p_path=ANY(d.evidence_paths))
   OR split_part(p_path,'/',1)<>r.id::text
   OR NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='dispute-evidence' AND o.name=p_path)
  THEN RAISE EXCEPTION '거래에 제출된 증빙이 아닙니다.' USING ERRCODE='P0002'; END IF;
  path:=p_path;
 ELSIF p_kind='return' THEN
  evidence:=public.resolve_rental_return_evidence(r.id,r.return_photo);
  path:=evidence->>'path';
 ELSE RAISE EXCEPTION '증빙 종류가 올바르지 않습니다.' USING ERRCODE='22023'; END IF;
 INSERT INTO public.finance_operator_audit(reservation_id,actor_id,action)
 VALUES(r.id,p_actor,CASE p_kind WHEN 'dispute' THEN 'view_dispute_evidence' ELSE 'view_return_evidence' END);
 RETURN path;
END $$;
