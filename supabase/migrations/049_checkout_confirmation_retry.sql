-- Read-only workers cannot approve a payment. Their successful unpaid lookups
-- must not continually postpone a browser that still has the approval key.
-- Failed provider work and browser approval outcomes retain the shared backoff.
CREATE OR REPLACE FUNCTION public.claim_toss_confirmation(p_order_id text,p_lease uuid,p_payment_key text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.toss_checkouts; r public.reservations;
BEGIN
 IF p_lease IS NULL THEN RAISE EXCEPTION 'Missing recovery lease' USING ERRCODE='22023'; END IF;
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id;
 SELECT * INTO r FROM public.reservations WHERE id=c.reservation_id FOR UPDATE;
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id FOR UPDATE;
 IF c.order_id IS NULL OR r.id IS NULL THEN RAISE EXCEPTION '결제 가능한 예약이 아닙니다.'; END IF;
 IF p_payment_key IS NOT NULL AND (p_payment_key='' OR (c.payment_key IS NOT NULL AND c.payment_key<>p_payment_key))
 THEN RAISE EXCEPTION '다른 결제 승인 정보입니다.'; END IF;
 IF r.status IS DISTINCT FROM 'accepted' THEN RETURN false; END IF;
 IF c.review_required_at IS NOT NULL THEN RAISE EXCEPTION 'Recovery requires review' USING ERRCODE='PDR01'; END IF;
 IF c.lease_until>clock_timestamp() THEN RETURN false; END IF;
 IF c.attempt_count>0 AND c.next_attempt_at>clock_timestamp()
  AND (p_payment_key IS NULL OR (c.payment_key IS NOT NULL AND c.last_error_code IS DISTINCT FROM 'CHECKOUT_LOOKUP_PENDING'))
 THEN RETURN false; END IF;
 IF r.payment_attempt_merchant_uid IS NOT NULL AND r.payment_attempt_merchant_uid<>c.order_id
 THEN RAISE EXCEPTION '예약 결제 상태가 변경되었습니다.'; END IF;
 IF p_payment_key IS NOT NULL THEN
  IF r.payment_attempt_merchant_uid IS NULL AND r.status='accepted' AND r.payment_due_at<=clock_timestamp()
  THEN RAISE EXCEPTION '결제 기한이 지났습니다.'; END IF;
  UPDATE public.toss_checkouts SET payment_key=p_payment_key WHERE order_id=p_order_id;
  IF r.status='accepted' THEN PERFORM public.begin_toss_confirmation(p_order_id); END IF;
 END IF;
 UPDATE public.toss_checkouts SET attempt_count=attempt_count+1,lease_token=p_lease,
  lease_until=clock_timestamp()+interval '90 seconds',last_checked_at=clock_timestamp() WHERE order_id=p_order_id;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.claim_toss_confirmation(text,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_toss_confirmation(text,uuid,text) TO service_role;
