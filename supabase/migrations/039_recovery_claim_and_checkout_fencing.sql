-- All callers share the same retry clock, including browser confirmation and
-- manual refund retries. A first payment key may start approval after earlier
-- read-only lookups; resending that key never bypasses a persisted backoff.
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
 -- Completed/cancelled reservations are status reads, never fresh PG work.
 IF r.status IS DISTINCT FROM 'accepted' THEN RETURN false; END IF;
 IF c.review_required_at IS NOT NULL THEN RAISE EXCEPTION 'Recovery requires review' USING ERRCODE='PDR01'; END IF;
 IF c.lease_until>clock_timestamp() THEN RETURN false; END IF;
 IF c.attempt_count>0 AND c.next_attempt_at>clock_timestamp()
  AND (p_payment_key IS NULL OR c.payment_key IS NOT NULL) THEN RETURN false; END IF;
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

CREATE OR REPLACE FUNCTION public.claim_rental_money_operation(p_id uuid,p_lease uuid)
RETURNS public.rental_money_operations LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE op public.rental_money_operations;
BEGIN
 IF p_lease IS NULL THEN RAISE EXCEPTION 'Missing recovery lease' USING ERRCODE='22023'; END IF;
 SELECT * INTO op FROM public.rental_money_operations WHERE id=p_id FOR UPDATE;
 IF op.status='pending' AND op.review_required_at IS NOT NULL THEN RAISE EXCEPTION 'Recovery requires review' USING ERRCODE='PDR01'; END IF;
 UPDATE public.rental_money_operations SET attempt_count=attempt_count+1,lease_token=p_lease,
  lease_until=clock_timestamp()+interval '90 seconds',last_checked_at=clock_timestamp()
 WHERE id=p_id AND status='pending' AND review_required_at IS NULL
  AND (attempt_count=0 OR next_attempt_at<=clock_timestamp())
  AND (lease_until IS NULL OR lease_until<=clock_timestamp()) RETURNING * INTO op;
 RETURN op;
END $$;

-- Remove the unfenced service-role entry points rather than leave overloads
-- that an old worker could still use after this migration.
DROP FUNCTION public.finish_toss_confirmation(text,text);
DROP FUNCTION public.fail_toss_confirmation(text);

CREATE FUNCTION public.finish_toss_confirmation(p_order_id text,p_payment_key text,p_lease uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.toss_checkouts; r public.reservations;
BEGIN
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id;
 SELECT * INTO r FROM public.reservations WHERE id=c.reservation_id FOR UPDATE;
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id FOR UPDATE;
 IF p_lease IS NULL OR c.order_id IS NULL OR c.lease_token IS DISTINCT FROM p_lease
  OR c.lease_until IS NULL OR c.lease_until<=clock_timestamp()
 THEN RAISE EXCEPTION '결제 확인 작업의 소유권이 변경되었습니다.'; END IF;
 IF p_payment_key IS NULL OR p_payment_key='' OR (c.payment_key IS NOT NULL AND c.payment_key<>p_payment_key)
 THEN RAISE EXCEPTION '다른 결제 승인 정보입니다.'; END IF;
 IF r.payment_provider='toss' AND r.payment_id=p_payment_key THEN RETURN; END IF;
 IF r.id IS NULL OR r.status<>'accepted' OR r.total_paid<>c.amount OR r.currency<>'KRW'
  OR r.payment_id IS NOT NULL OR (r.payment_attempt_merchant_uid IS NOT NULL AND r.payment_attempt_merchant_uid<>c.order_id)
 THEN RAISE EXCEPTION '예약 결제 상태가 변경되었습니다.'; END IF;
 -- Discovery of a successful payment uses the same fence as its final write.
 -- An overdue order without an existing approval hold cannot be revived.
 PERFORM public.begin_toss_confirmation(p_order_id);
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status='paid',payment_provider='toss',payment_id=p_payment_key,
  payment_attempt_merchant_uid=NULL,payment_attempt_started_at=NULL WHERE id=r.id;
 UPDATE public.toss_checkouts SET payment_key=p_payment_key WHERE order_id=p_order_id;
 INSERT INTO public.rental_events(reservation_id,command,from_status,to_status) VALUES(r.id,'confirmTossPayment','accepted','paid');
END $$;

-- Only the worker that owns the current, unexpired lease may expire the
-- reservation after a terminal provider lookup. A different payment attempt
-- must never be discarded by a late response for this checkout.
CREATE FUNCTION public.fail_toss_confirmation(p_order_id text,p_lease uuid)
RETURNS public.reservation_status LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.toss_checkouts; r public.reservations;
BEGIN
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id;
 SELECT * INTO r FROM public.reservations WHERE id=c.reservation_id FOR UPDATE;
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id FOR UPDATE;
 IF p_lease IS NULL OR c.order_id IS NULL OR c.lease_token IS DISTINCT FROM p_lease
  OR c.lease_until IS NULL OR c.lease_until<=clock_timestamp()
 THEN RAISE EXCEPTION '결제 확인 작업의 소유권이 변경되었습니다.'; END IF;
 IF r.id IS NULL THEN RAISE EXCEPTION '예약 결제 상태가 변경되었습니다.'; END IF;
 IF r.status<>'accepted' OR r.payment_id IS NOT NULL THEN RETURN r.status; END IF;
 IF r.payment_attempt_merchant_uid IS NOT NULL AND r.payment_attempt_merchant_uid<>c.order_id
 THEN RAISE EXCEPTION '예약 결제 상태가 변경되었습니다.'; END IF;
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status='expired',payment_attempt_merchant_uid=NULL,payment_attempt_started_at=NULL WHERE id=r.id;
 INSERT INTO public.rental_events(reservation_id,command,from_status,to_status) VALUES(r.id,'failTossPayment','accepted','expired');
 RETURN 'expired'::public.reservation_status;
END $$;

REVOKE ALL ON FUNCTION public.finish_toss_confirmation(text,text,uuid),public.fail_toss_confirmation(text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.finish_toss_confirmation(text,text,uuid),public.fail_toss_confirmation(text,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.record_rental_recovery_attempt(
 p_kind text,p_key text,p_lease uuid,p_code text,p_review boolean DEFAULT false,p_failed boolean DEFAULT true
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE target text; key_column text; key_type text;
BEGIN
 IF p_kind IS NULL OR p_kind NOT IN ('checkout','money') OR p_code IS NULL OR p_code !~ '^[A-Z_]{1,48}$'
 THEN RAISE EXCEPTION 'Invalid recovery result' USING ERRCODE='22023'; END IF;
 target:=CASE p_kind WHEN 'checkout' THEN 'toss_checkouts' ELSE 'rental_money_operations' END;
 key_column:=CASE p_kind WHEN 'checkout' THEN 'order_id' ELSE 'id' END;
 key_type:=CASE p_kind WHEN 'checkout' THEN 'text' ELSE 'uuid' END;
 EXECUTE format('UPDATE public.%I SET
  failure_count=failure_count+CASE WHEN $4 THEN 1 ELSE 0 END,
  last_error_code=$1,last_error_at=clock_timestamp(),
  review_required_at=CASE WHEN $2 OR ($4 AND failure_count+1>=8) THEN coalesce(review_required_at,clock_timestamp()) ELSE review_required_at END,
  next_attempt_at=clock_timestamp()+make_interval(secs=>CASE WHEN $4 THEN least(3600,30*power(2,least(failure_count,7)))::integer ELSE 60 END)
  WHERE %I=$3::%s AND lease_token=$5 AND lease_until>clock_timestamp()',target,key_column,key_type)
 USING p_code,p_review,p_key,p_failed,p_lease;
END $$;

-- Money completion already checked token ownership; expiration must also
-- fence a paused worker even before another worker acquires the operation.
CREATE OR REPLACE FUNCTION public.finish_rental_money_operation(p_id uuid,p_lease uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE op public.rental_money_operations; r public.reservations; target public.reservation_status;
BEGIN
 SELECT * INTO op FROM public.rental_money_operations WHERE id=p_id;
 SELECT * INTO r FROM public.reservations WHERE id=op.reservation_id FOR UPDATE;
 SELECT * INTO op FROM public.rental_money_operations WHERE id=p_id FOR UPDATE;
 IF op.status='complete' THEN RETURN; END IF;
 IF p_lease IS NULL OR op.id IS NULL OR op.lease_token IS DISTINCT FROM p_lease
  OR op.lease_until IS NULL OR op.lease_until<=clock_timestamp() OR r.payment_id IS DISTINCT FROM op.payment_id
  OR (op.kind='refund' AND (r.status<>'paid' OR r.payment_action IS DISTINCT FROM 'refund_pending'))
  OR (op.kind='settle' AND (r.status<>'returned' OR r.payment_action IS DISTINCT FROM 'settle_pending'))
 THEN RAISE EXCEPTION '금융 작업의 거래 상태가 변경되었습니다.'; END IF;
 target:=CASE WHEN op.kind='refund' THEN 'cancelled'::public.reservation_status ELSE 'settled'::public.reservation_status END;
 PERFORM set_config('app.rental_money_operation_id',op.id::text,true);
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status=target,payment_action=NULL,payment_action_started_at=NULL WHERE id=r.id;
 UPDATE public.rental_money_operations SET status='complete',lease_token=NULL,lease_until=NULL WHERE id=op.id;
 INSERT INTO public.rental_events(reservation_id,actor_id,command,from_status,to_status) VALUES(r.id,op.actor_id,op.kind||'Rental',r.status,target);
END $$;
