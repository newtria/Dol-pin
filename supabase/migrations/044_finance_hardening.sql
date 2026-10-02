-- Operator reads are privileged commands as well: current Auth authority and
-- an active marketplace account are both required, even with an older JWT.
CREATE OR REPLACE FUNCTION public.assert_finance_operator(p_actor uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_actor IS NULL OR NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor
  AND raw_app_meta_data->'dolpin_operator'='true'::jsonb)
 OR NOT EXISTS(SELECT 1 FROM public.users WHERE id=p_actor AND deleted_at IS NULL AND suspended_at IS NULL)
 THEN RAISE EXCEPTION '운영 권한이 없습니다.' USING ERRCODE='42501'; END IF;
END $$;

ALTER TABLE public.finance_operator_audit DROP CONSTRAINT finance_operator_audit_action_check;
ALTER TABLE public.finance_operator_audit ADD CONSTRAINT finance_operator_audit_action_check
 CHECK(action IN ('escalate','close_review','retry_recovery','view_rental','view_dispute_evidence','view_return_evidence'));
CREATE INDEX finance_operator_audit_rental ON public.finance_operator_audit(reservation_id,created_at DESC);
INSERT INTO public.api_usage_limits VALUES('payment-verify',20,200)
 ON CONFLICT(feature) DO UPDATE SET per_minute=excluded.per_minute,per_day=excluded.per_day;

CREATE TABLE public.legacy_payment_verifications (
 payment_reference text PRIMARY KEY CHECK(length(payment_reference) BETWEEN 1 AND 200),
 reservation_id uuid NOT NULL REFERENCES public.reservations(id),
 amount integer NOT NULL CHECK(amount>0),refunded integer NOT NULL CHECK(refunded>=0 AND refunded<=amount),
 currency text NOT NULL CHECK(currency ~ '^[A-Z]{3}$'),
 status text NOT NULL CHECK(status IN ('paid','ready','failed','cancelled')),
 reason_code text NOT NULL CHECK(reason_code IN ('amount_currency_mismatch','different_payment','different_attempt','external_refund','verification_rejected')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),resolved_at timestamptz
);
ALTER TABLE public.legacy_payment_verifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.legacy_payment_verifications FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.legacy_payment_verifications TO service_role;
CREATE INDEX legacy_payment_verification_rental ON public.legacy_payment_verifications(reservation_id);

CREATE FUNCTION public.record_legacy_payment_review(
 p_reservation_id uuid,p_actor uuid,p_payment_id text,p_amount integer,p_refunded integer,p_currency text,p_status text,p_reason text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM 1 FROM public.users WHERE id=p_actor AND deleted_at IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION '이 계정은 현재 이용할 수 없습니다.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.reservations WHERE id=p_reservation_id AND p_actor IN (borrower_id,lender_id))
 THEN RAISE EXCEPTION '거래에 접근할 수 없습니다.' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.reservations WHERE id=p_reservation_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '거래를 찾을 수 없습니다.' USING ERRCODE='P0002'; END IF;
 INSERT INTO public.legacy_payment_verifications(payment_reference,reservation_id,amount,refunded,currency,status,reason_code)
 VALUES(p_payment_id,p_reservation_id,p_amount,p_refunded,p_currency,p_status,p_reason)
 ON CONFLICT(payment_reference) DO UPDATE SET amount=excluded.amount,refunded=excluded.refunded,currency=excluded.currency,
  status=excluded.status,reason_code=excluded.reason_code,updated_at=clock_timestamp(),resolved_at=NULL
 WHERE legacy_payment_verifications.reservation_id=excluded.reservation_id;
 IF NOT FOUND THEN RAISE EXCEPTION '다른 거래에 속한 결제입니다.'; END IF;
 INSERT INTO public.rental_operator_reviews(reservation_id,kind) VALUES(p_reservation_id,'legacy_finance')
 ON CONFLICT(reservation_id,kind) DO UPDATE SET closed_at=NULL,closed_by=NULL,resolution_note=NULL;
END $$;

CREATE FUNCTION public.resolve_legacy_payment_verification(p_reservation_id uuid,p_payment_id text) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 UPDATE public.legacy_payment_verifications SET resolved_at=coalesce(resolved_at,clock_timestamp()),updated_at=clock_timestamp()
 WHERE reservation_id=p_reservation_id AND payment_reference=p_payment_id
  AND EXISTS(SELECT 1 FROM public.reservations r WHERE r.id=p_reservation_id AND r.payment_id=p_payment_id
   AND r.payment_provider='portone' AND r.status IN ('paid','picked_up','returned','disputed','settled','resolved','cancelled'));
$$;
REVOKE ALL ON FUNCTION public.record_legacy_payment_review(uuid,uuid,text,integer,integer,text,text,text),public.resolve_legacy_payment_verification(uuid,text)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_legacy_payment_review(uuid,uuid,text,integer,integer,text,text,text),public.resolve_legacy_payment_verification(uuid,text)
 TO service_role;

-- Never return payment keys, leases, checkout bearer tokens or bank accounts
-- with an investigation. Those retain their own narrowly scoped commands.
CREATE FUNCTION public.finance_rental_detail(
 p_reservation_id uuid,p_actor uuid,p_before timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; messages jsonb; more boolean;
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 IF (p_before IS NULL)<>(p_before_id IS NULL) THEN RAISE EXCEPTION '메시지 조회 위치가 올바르지 않습니다.' USING ERRCODE='22023'; END IF;
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id;
 IF r.id IS NULL THEN RAISE EXCEPTION '거래를 찾을 수 없습니다.' USING ERRCODE='P0002'; END IF;
 WITH page AS (
  SELECT id,sender_id,message,coalesce(created_at,'epoch'::timestamptz) AS created_at,read_at
  FROM public.chat_messages WHERE reservation_id=r.id
   AND (p_before IS NULL OR (coalesce(created_at,'epoch'::timestamptz),id)<(p_before,p_before_id))
  ORDER BY coalesce(created_at,'epoch'::timestamptz) DESC,id DESC LIMIT 101
 ), visible AS (SELECT * FROM page ORDER BY created_at DESC,id DESC LIMIT 100)
 SELECT (SELECT coalesce(jsonb_agg(to_jsonb(v) ORDER BY v.created_at DESC,v.id DESC),'[]'::jsonb) FROM visible v),
  (SELECT count(*)>100 FROM page) INTO messages,more;
 INSERT INTO public.finance_operator_audit(reservation_id,actor_id,action)
 VALUES(r.id,p_actor,'view_rental');
 RETURN jsonb_build_object(
  'reservation',jsonb_build_object('id',r.id,'status',r.status,'total_paid',r.total_paid,'deposit',r.deposit,
   'rental_fee',r.rental_fee,'borrower_id',r.borrower_id,'lender_id',r.lender_id,'payment_action',r.payment_action,
   'item_id',r.item_id,'rental_date',r.rental_date,'return_date',r.return_date,'starts_at',r.starts_at,'ends_at',r.ends_at,
   'pickup_confirmed_at',r.pickup_confirmed_at,'return_confirmed_at',r.return_confirmed_at,'return_photo',r.return_photo,
   'payment_provider',r.payment_provider,'created_at',r.created_at,'terms_snapshot',r.terms_snapshot),
  'item',(SELECT jsonb_build_object('id',i.id,'title',i.title) FROM public.rental_items i WHERE i.id=r.item_id),
  'participants',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',u.id,'nickname',u.nickname)),'[]'::jsonb)
   FROM public.users u WHERE u.id IN (r.borrower_id,r.lender_id)),
  'pickup',jsonb_build_object(
   'borrowerConfirmed',EXISTS(SELECT 1 FROM public.rental_pickup_confirmations WHERE reservation_id=r.id AND borrower_confirmed_at IS NOT NULL),
   'lenderConfirmed',EXISTS(SELECT 1 FROM public.rental_pickup_confirmations WHERE reservation_id=r.id AND lender_confirmed_at IS NOT NULL)),
  'disputes',(SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY d.created_at,d.id),'[]'::jsonb) FROM public.rental_disputes d WHERE d.reservation_id=r.id),
  'resolutions',(SELECT coalesce(jsonb_agg(jsonb_build_object('refund_amount',d.refund_amount,'reason',d.reason,'created_at',d.created_at)
   ORDER BY d.created_at DESC,d.id DESC),'[]'::jsonb) FROM public.reservation_dispute_resolutions d WHERE d.reservation_id=r.id),
  'operations',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',o.id,'kind',o.kind,'amount',o.amount,'total',o.total,
   'status',o.status,'created_at',o.created_at,'dispatched_at',o.dispatched_at,'last_error_code',o.last_error_code,
   'review_required_at',o.review_required_at) ORDER BY o.created_at,o.id),'[]'::jsonb)
   FROM public.rental_money_operations o WHERE o.reservation_id=r.id),
  'payouts',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'reservation_id',p.reservation_id,'lender_id',p.lender_id,
   'amount',p.amount,'fee_amount',p.fee_amount,'net_amount',p.net_amount,'currency',p.currency,'status',p.status,
   'claimed_by',p.claimed_by,'claimed_at',p.claimed_at,'paid_at',p.paid_at,'created_at',p.created_at)),'[]'::jsonb)
   FROM public.rental_payouts p WHERE p.reservation_id=r.id),
  'events',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',e.id,'actor_id',e.actor_id,'command',e.command,
   'from_status',e.from_status,'to_status',e.to_status,'created_at',e.created_at) ORDER BY e.id),'[]'::jsonb)
   FROM public.rental_events e WHERE e.reservation_id=r.id),
  'messages',messages,'messagesHasMore',more,
  'legacyPayments',(SELECT coalesce(jsonb_agg(jsonb_build_object('payment_reference',v.payment_reference,
   'amount',v.amount,'refunded',v.refunded,'currency',v.currency,'status',v.status,'reason_code',v.reason_code,
   'created_at',v.created_at,'resolved_at',v.resolved_at) ORDER BY v.created_at DESC),'[]'::jsonb)
   FROM public.legacy_payment_verifications v WHERE v.reservation_id=r.id));
END $$;

-- Validate association in the same transaction as the access audit. An
-- operator cannot use the signing route to browse arbitrary storage objects.
CREATE FUNCTION public.finance_evidence_access(p_reservation_id uuid,p_actor uuid,p_kind text,p_path text DEFAULT NULL)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; path text; bucket text;
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id;
 IF r.id IS NULL THEN RAISE EXCEPTION '거래를 찾을 수 없습니다.' USING ERRCODE='P0002'; END IF;
 IF p_kind='dispute' THEN
  IF p_path IS NULL OR NOT EXISTS(SELECT 1 FROM public.rental_disputes d WHERE d.reservation_id=r.id AND p_path=ANY(d.evidence_paths))
  THEN RAISE EXCEPTION '거래에 제출된 증빙이 아닙니다.' USING ERRCODE='P0002'; END IF;
  path:=p_path; bucket:='dispute-evidence';
 ELSIF p_kind='return' THEN
  path:=r.return_photo; bucket:='rental-evidence';
 ELSE RAISE EXCEPTION '증빙 종류가 올바르지 않습니다.' USING ERRCODE='22023'; END IF;
 IF path IS NULL OR split_part(path,'/',1)<>r.id::text
 OR NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id=bucket AND o.name=path)
 THEN RAISE EXCEPTION '거래 증빙을 찾을 수 없습니다.' USING ERRCODE='P0002'; END IF;
 INSERT INTO public.finance_operator_audit(reservation_id,actor_id,action)
 VALUES(r.id,p_actor,CASE p_kind WHEN 'dispute' THEN 'view_dispute_evidence' ELSE 'view_return_evidence' END);
 RETURN path;
END $$;

-- Closing an obsolete row must not report success for a missing/already
-- modified review. Retrying an identical close by its actor is idempotent.
CREATE OR REPLACE FUNCTION public.close_rental_operator_review(p_id uuid,p_actor uuid,p_note text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE review public.rental_operator_reviews;
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 IF p_note IS NULL OR length(btrim(p_note)) NOT BETWEEN 5 AND 1000
 THEN RAISE EXCEPTION '처리 내용이 필요합니다.' USING ERRCODE='22023'; END IF;
 SELECT * INTO review FROM public.rental_operator_reviews WHERE id=p_id;
 PERFORM 1 FROM public.reservations WHERE id=review.reservation_id FOR UPDATE;
 SELECT * INTO review FROM public.rental_operator_reviews WHERE id=p_id FOR UPDATE;
 IF review.id IS NULL THEN RAISE EXCEPTION '검토할 거래가 없습니다.' USING ERRCODE='P0002'; END IF;
 IF review.closed_at IS NOT NULL THEN
  IF review.closed_by=p_actor AND review.resolution_note=btrim(p_note) THEN RETURN; END IF;
  RAISE EXCEPTION '이미 처리된 검토입니다.';
 END IF;
 UPDATE public.rental_operator_reviews SET closed_at=clock_timestamp(),closed_by=p_actor,resolution_note=btrim(p_note) WHERE id=p_id;
 IF review.kind='legacy_finance' THEN
  UPDATE public.legacy_payment_verifications SET resolved_at=coalesce(resolved_at,clock_timestamp()) WHERE reservation_id=review.reservation_id;
 END IF;
 INSERT INTO public.finance_operator_audit(reservation_id,actor_id,action,note)
 VALUES(review.reservation_id,p_actor,'close_review',btrim(p_note));
END $$;

REVOKE ALL ON FUNCTION public.finance_rental_detail(uuid,uuid,timestamptz,uuid),public.finance_evidence_access(uuid,uuid,text,text)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.finance_rental_detail(uuid,uuid,timestamptz,uuid),public.finance_evidence_access(uuid,uuid,text,text)
 TO service_role;

ALTER TABLE public.payout_audit DROP CONSTRAINT payout_audit_action_check;
ALTER TABLE public.payout_audit ADD CONSTRAINT payout_audit_action_check
 CHECK(action IN ('claim','paid','failed','verified_not_sent','legacy_review','reconciled_paid'));

-- A departed operator must not permanently strand a bank transfer. This is a
-- manual bank reconciliation, never an automatic transfer or timed retry.
CREATE FUNCTION public.reconcile_rental_payout(
 p_id uuid,p_actor uuid,p_claimed_at timestamptz,p_outcome text,p_reason text,p_reference text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.rental_payouts;
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 IF p_outcome IS NULL OR p_outcome NOT IN ('paid','not_sent') OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 1000
 OR (p_outcome='paid' AND (p_reference IS NULL OR length(btrim(p_reference)) NOT BETWEEN 4 AND 160))
 THEN RAISE EXCEPTION '은행 확인 근거와 송금 결과가 필요합니다.' USING ERRCODE='22023'; END IF;
 SELECT * INTO p FROM public.rental_payouts WHERE id=p_id FOR UPDATE;
 IF p.id IS NULL THEN RAISE EXCEPTION '지급 대상을 찾을 수 없습니다.' USING ERRCODE='P0002'; END IF;
 IF p.claimed_at IS DISTINCT FROM p_claimed_at THEN RAISE EXCEPTION '지급 담당 상태가 변경되었습니다.'; END IF;
 IF p.status='paid' AND p_outcome='paid' AND p.transfer_reference=btrim(p_reference) THEN RETURN to_jsonb(p)-'claim_token'; END IF;
 IF p.status NOT IN ('processing','failed') THEN RAISE EXCEPTION '은행 확인 대기 중인 지급이 아닙니다.'; END IF;
 IF p.status='processing' AND p.claimed_by IS DISTINCT FROM p_actor AND p.claimed_at>clock_timestamp()-interval '1 hour'
 AND EXISTS(SELECT 1 FROM auth.users u JOIN public.users profile ON profile.id=u.id WHERE u.id=p.claimed_by
  AND u.raw_app_meta_data->'dolpin_operator'='true'::jsonb AND profile.deleted_at IS NULL AND profile.suspended_at IS NULL)
 THEN RAISE EXCEPTION '다른 운영자가 지급 중입니다. 담당자의 처리를 먼저 확인해 주세요.'; END IF;
 IF p_outcome='paid' THEN
  UPDATE public.rental_payouts SET status='paid',transfer_reference=btrim(p_reference),paid_at=clock_timestamp()
  WHERE id=p.id RETURNING * INTO p;
 ELSE
  UPDATE public.rental_payouts SET status=CASE WHEN net_amount=0 THEN 'paid' ELSE 'pending' END,
   paid_at=CASE WHEN net_amount=0 THEN clock_timestamp() END,claim_token=NULL,claimed_by=NULL,claimed_at=NULL
  WHERE id=p.id RETURNING * INTO p;
 END IF;
 INSERT INTO public.payout_audit(payout_id,actor_id,action,note)
 VALUES(p.id,p_actor,CASE p_outcome WHEN 'paid' THEN 'reconciled_paid' ELSE 'verified_not_sent' END,btrim(p_reason));
 RETURN to_jsonb(p)-'claim_token';
END $$;
REVOKE ALL ON FUNCTION public.reconcile_rental_payout(uuid,uuid,timestamptz,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_rental_payout(uuid,uuid,timestamptz,text,text,text) TO service_role;
