-- Never erase an unknown financial outcome because time has passed.
CREATE OR REPLACE FUNCTION transition_reservation_status(
  p_reservation_id UUID,
  p_target         reservation_status,
  p_actor_kind     TEXT DEFAULT NULL,
  p_actor_id       UUID DEFAULT NULL,
  p_reason         TEXT DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row reservations%ROWTYPE;
  v_actor_kind TEXT;
  v_role TEXT;
  v_uid UUID;
  v_legal BOOLEAN;
BEGIN
  IF p_reservation_id IS NULL OR p_target IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'null argument');
  END IF;

  -- Load the row, lock it for the duration of the transaction so two
  -- concurrent transitions on the same reservation serialise.
  SELECT * INTO v_row
    FROM reservations
   WHERE id = p_reservation_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'reservation not found');
  END IF;

  -- Resolve actor_kind. Authenticated clients cannot claim `system` or
  -- `admin`; they are always inferred from auth.uid(). service_role callers
  -- (Edge Functions) must pass an explicit system/admin actor.
  v_role := current_setting('role', true);
  v_uid := auth.uid();

  IF v_role = 'service_role' THEN
    v_actor_kind := COALESCE(p_actor_kind, '');
    IF v_actor_kind NOT IN ('system', 'admin') THEN
      RETURN jsonb_build_object(
        'ok', false, 'error', 'service_role actor must be system or admin'
      );
    END IF;
  ELSE
    IF v_uid IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', 'no actor');
    ELSIF p_actor_id IS NOT NULL AND p_actor_id <> v_uid THEN
      RETURN jsonb_build_object('ok', false, 'error', 'actor mismatch');
    ELSIF v_uid = v_row.borrower_id THEN
      v_actor_kind := 'borrower';
    ELSIF v_uid = v_row.lender_id THEN
      v_actor_kind := 'lender';
    ELSE
      RETURN jsonb_build_object('ok', false, 'error', 'not a participant');
    END IF;
  END IF;

  -- Idempotency: same target is a no-op success, but only after actor
  -- authorization so callers cannot probe reservation existence/status.
  IF v_row.status = p_target THEN
    RETURN jsonb_build_object(
      'ok',      true,
      'status',  p_target,
      'already', true
    );
  END IF;

  IF p_target = 'returned' AND v_actor_kind = 'borrower' THEN
    RETURN jsonb_build_object(
      'ok', false, 'error', 'use confirm_reservation_return with return photo'
    );
  END IF;

  IF v_row.payment_action IS NOT NULL
     AND v_actor_kind NOT IN ('system', 'admin') THEN
    RETURN jsonb_build_object(
      'ok', false, 'error', 'payment action in progress'
    );
  END IF;

  IF v_row.payment_action = 'refund_pending'
     AND (v_actor_kind <> 'system' OR p_target <> 'cancelled') THEN
    RETURN jsonb_build_object(
      'ok', false, 'error', 'refund is already in progress'
    );
  END IF;

  IF v_row.payment_action = 'settle_pending'
     AND (v_actor_kind <> 'system' OR p_target <> 'settled') THEN
    RETURN jsonb_build_object(
      'ok', false, 'error', 'settlement is already in progress'
    );
  END IF;

  IF v_row.payment_action = 'dispute_pending'
     AND (v_actor_kind <> 'admin' OR p_target <> 'resolved') THEN
    RETURN jsonb_build_object(
      'ok', false, 'error', 'dispute resolution is already in progress'
    );
  END IF;

  -- Authorise: check the transition is in the legal table.
  SELECT EXISTS (
    SELECT 1 FROM reservation_transitions
     WHERE from_status = v_row.status
       AND to_status   = p_target
       AND actor_kind  = v_actor_kind
  ) INTO v_legal;

  IF NOT v_legal THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'error', format(
        'illegal transition: %s → %s by %s',
        v_row.status, p_target, v_actor_kind
      )
    );
  END IF;

  -- Apply the transition. Side-effect columns (pickup_confirmed_at,
  -- return_confirmed_at) are stamped here so the client cannot forge
  -- them by skipping the RPC. The local GUC lets the status trigger
  -- distinguish this validated path from direct client UPDATEs.
  PERFORM set_config('app.reservation_status_rpc', 'on', true);

  UPDATE reservations
     SET status = p_target,
         pickup_confirmed_at = CASE
           WHEN p_target = 'picked_up' THEN now()
           ELSE pickup_confirmed_at
         END,
         return_confirmed_at = CASE
           WHEN p_target = 'returned' THEN now()
           ELSE return_confirmed_at
         END,
         payment_action = CASE
           WHEN p_target IN ('cancelled', 'settled', 'resolved') THEN NULL
           ELSE payment_action
         END,
         payment_action_started_at = CASE
           WHEN p_target IN ('cancelled', 'settled', 'resolved') THEN NULL
           ELSE payment_action_started_at
         END,
         payment_attempt_merchant_uid = CASE
           WHEN p_target IN ('cancelled', 'settled', 'resolved') THEN NULL
           ELSE payment_attempt_merchant_uid
         END,
         payment_attempt_started_at = CASE
           WHEN p_target IN ('cancelled', 'settled', 'resolved') THEN NULL
           ELSE payment_attempt_started_at
         END
   WHERE id = p_reservation_id;

  RETURN jsonb_build_object(
    'ok',      true,
    'status',  p_target,
    'already', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION begin_reservation_payment_action(
  p_reservation_id UUID,
  p_action TEXT,
  p_payment_id TEXT,
  p_actor_id UUID
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row reservations%ROWTYPE;
BEGIN
  IF p_action NOT IN ('refund_pending', 'settle_pending', 'dispute_pending') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid payment action');
  END IF;

  SELECT * INTO v_row
    FROM reservations
   WHERE id = p_reservation_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'reservation not found');
  END IF;

  IF v_row.payment_id IS NULL OR v_row.payment_id <> p_payment_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'payment_id mismatch');
  END IF;

  IF p_action = 'refund_pending' THEN
    IF v_row.status <> 'paid' THEN
      RETURN jsonb_build_object(
        'ok', false, 'error', format('cannot refund status %s', v_row.status)
      );
    END IF;
    IF p_actor_id NOT IN (v_row.borrower_id, v_row.lender_id) THEN
      RETURN jsonb_build_object('ok', false, 'error', 'not a participant');
    END IF;
  ELSIF p_action = 'settle_pending' THEN
    IF v_row.status <> 'returned' THEN
      RETURN jsonb_build_object(
        'ok', false, 'error', format('cannot settle status %s', v_row.status)
      );
    END IF;
    IF p_actor_id <> v_row.lender_id THEN
      RETURN jsonb_build_object('ok', false, 'error', 'only lender may settle');
    END IF;
  ELSE
    IF v_row.status <> 'disputed' THEN
      RETURN jsonb_build_object(
        'ok', false, 'error', format('cannot resolve dispute status %s', v_row.status)
      );
    END IF;
  END IF;

  IF v_row.payment_action IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok',
      false,
      'error',
      CASE
        WHEN v_row.payment_action = p_action THEN
          'payment action already in progress'
        ELSE
          'different payment action already in progress'
      END
    );
  END IF;

  UPDATE reservations
     SET payment_action = p_action,
         payment_action_started_at = now()
   WHERE id = p_reservation_id;

  RETURN jsonb_build_object('ok', true, 'status', v_row.status, 'action', p_action);
END;
$$;


-- Independent browser capabilities do not revoke another in-flight checkout.
CREATE TABLE public.toss_checkout_sessions (
 token_hash text PRIMARY KEY,
 order_id text NOT NULL REFERENCES public.toss_checkouts(order_id),
 mobile boolean NOT NULL,
 expires_at timestamptz NOT NULL DEFAULT (now()+interval '7 days')
);
INSERT INTO public.toss_checkout_sessions(token_hash,order_id,mobile)
 SELECT token_hash,order_id,mobile FROM public.toss_checkouts;
ALTER TABLE public.toss_checkout_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.toss_checkout_sessions FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.toss_checkout_sessions TO service_role;
ALTER TABLE public.toss_checkouts ADD COLUMN payment_key text,
 ADD COLUMN lease_token uuid, ADD COLUMN lease_until timestamptz, ADD COLUMN last_checked_at timestamptz;

CREATE OR REPLACE FUNCTION public.prepare_toss_checkout(p_reservation_id uuid,p_actor uuid,p_token_hash text,p_mobile boolean)
RETURNS public.toss_checkouts LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; c public.toss_checkouts;
BEGIN
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id FOR UPDATE;
 IF p_actor IS NULL OR r.id IS NULL OR r.borrower_id<>p_actor THEN RAISE EXCEPTION '대여자만 결제할 수 있습니다.'; END IF;
 IF r.status<>'accepted' OR r.payment_id IS NOT NULL OR r.currency<>'KRW' OR r.total_paid<=0
 OR (r.payment_due_at<=clock_timestamp() AND r.payment_attempt_merchant_uid IS NULL)
 THEN RAISE EXCEPTION '결제 가능한 예약이 아닙니다.'; END IF;
 INSERT INTO public.toss_checkouts(reservation_id,order_id,token_hash,amount,customer_key,expires_at,mobile)
 VALUES(r.id,'dolpin_'||replace(r.id::text,'-',''),p_token_hash,r.total_paid,r.borrower_id,r.payment_due_at,p_mobile)
 ON CONFLICT(reservation_id) DO NOTHING;
 SELECT * INTO c FROM public.toss_checkouts WHERE reservation_id=r.id;
 INSERT INTO public.toss_checkout_sessions(token_hash,order_id,mobile) VALUES(p_token_hash,c.order_id,p_mobile);
 RETURN c;
END $$;

-- Claim before HTTP; serialize approval/recovery. Time expiry permits LOOKUP,
-- never another first approval after the reservation payment deadline.
CREATE FUNCTION public.claim_toss_confirmation(p_order_id text,p_lease uuid,p_payment_key text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.toss_checkouts; r public.reservations;
BEGIN
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id;
 SELECT * INTO r FROM public.reservations WHERE id=c.reservation_id FOR UPDATE;
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id FOR UPDATE;
 IF c.order_id IS NULL OR r.status NOT IN ('accepted','paid') THEN RAISE EXCEPTION '결제 가능한 예약이 아닙니다.'; END IF;
 IF c.lease_until>clock_timestamp() THEN RETURN false; END IF;
 IF p_payment_key IS NOT NULL THEN
  IF r.payment_attempt_merchant_uid IS NULL AND r.status='accepted' AND r.payment_due_at<=clock_timestamp()
  THEN RAISE EXCEPTION '결제 기한이 지났습니다.'; END IF;
  IF c.payment_key IS NOT NULL AND c.payment_key<>p_payment_key THEN RAISE EXCEPTION '다른 결제 승인 정보입니다.'; END IF;
  UPDATE public.toss_checkouts SET payment_key=p_payment_key WHERE order_id=p_order_id;
  IF r.status='accepted' THEN
   PERFORM public.begin_toss_confirmation(p_order_id);
  END IF;
 END IF;
 UPDATE public.toss_checkouts SET lease_token=p_lease,lease_until=clock_timestamp()+interval '90 seconds',last_checked_at=clock_timestamp() WHERE order_id=p_order_id;
 RETURN true;
END $$;

CREATE FUNCTION public.release_toss_confirmation(p_order_id text,p_lease uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 UPDATE public.toss_checkouts SET lease_token=NULL,lease_until=NULL WHERE order_id=p_order_id AND lease_token=p_lease;
$$;

-- Called only after a provider lookup confirms a terminal unpaid state.
CREATE FUNCTION public.fail_toss_confirmation(p_order_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.toss_checkouts; r public.reservations;
BEGIN
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id;
 SELECT * INTO r FROM public.reservations WHERE id=c.reservation_id FOR UPDATE;
 IF r.status<>'accepted' OR r.payment_id IS NOT NULL THEN RETURN; END IF;
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status='expired',payment_attempt_merchant_uid=NULL,payment_attempt_started_at=NULL WHERE id=r.id;
 INSERT INTO public.rental_events(reservation_id,command,from_status,to_status) VALUES(r.id,'failTossPayment','accepted','expired');
END $$;

-- Refund/settlement intent survives worker crashes and lost responses.
CREATE TABLE public.rental_money_operations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 reservation_id uuid NOT NULL REFERENCES public.reservations(id),
 kind text NOT NULL CHECK(kind IN ('refund','settle')),
 actor_id uuid NOT NULL REFERENCES public.users(id),
 provider text NOT NULL CHECK(provider IN ('toss','portone')),
 payment_id text NOT NULL,
 amount integer NOT NULL CHECK(amount>=0),
 total integer NOT NULL CHECK(total>0),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','complete')),
 dispatched_at timestamptz,
 lease_token uuid,
 lease_until timestamptz,
 last_checked_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(reservation_id,kind)
);
ALTER TABLE public.rental_money_operations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rental_money_operations FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.rental_money_operations TO service_role;
CREATE INDEX money_recovery_pending ON public.rental_money_operations(last_checked_at NULLS FIRST) WHERE status='pending';

CREATE FUNCTION public.begin_rental_money_operation(p_reservation_id uuid,p_actor uuid,p_kind text)
RETURNS public.rental_money_operations LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; op public.rental_money_operations;
BEGIN
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id FOR UPDATE;
 IF p_actor IS NULL OR r.id IS NULL OR p_kind IS NULL OR p_kind NOT IN ('refund','settle')
 OR (p_kind='refund' AND p_actor NOT IN (r.borrower_id,r.lender_id))
 OR (p_kind='settle' AND p_actor<>r.lender_id) THEN RAISE EXCEPTION '권한이 없습니다.' USING ERRCODE='42501'; END IF;
 SELECT * INTO op FROM public.rental_money_operations WHERE reservation_id=r.id AND kind=p_kind;
 IF FOUND THEN RETURN op; END IF;
 IF r.payment_id IS NULL OR r.payment_provider IS NULL OR r.payment_provider NOT IN ('toss','portone') OR r.currency<>'KRW'
 OR r.payment_action IS NOT NULL OR (p_kind='refund' AND r.status<>'paid') OR (p_kind='settle' AND r.status<>'returned')
 THEN RAISE EXCEPTION '처리 가능한 거래가 아닙니다.'; END IF;
 INSERT INTO public.rental_money_operations(reservation_id,kind,actor_id,provider,payment_id,amount,total)
 VALUES(r.id,p_kind,p_actor,r.payment_provider,r.payment_id,CASE WHEN p_kind='refund' THEN r.total_paid ELSE r.deposit END,r.total_paid)
 RETURNING * INTO op;
 UPDATE public.reservations SET payment_action=CASE WHEN p_kind='refund' THEN 'refund_pending' ELSE 'settle_pending' END,
 payment_action_started_at=clock_timestamp() WHERE id=r.id;
 RETURN op;
END $$;

CREATE FUNCTION public.claim_rental_money_operation(p_id uuid,p_lease uuid)
RETURNS public.rental_money_operations LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE op public.rental_money_operations;
BEGIN
 UPDATE public.rental_money_operations SET lease_token=p_lease,lease_until=clock_timestamp()+interval '90 seconds',last_checked_at=clock_timestamp()
 WHERE id=p_id AND status='pending' AND (lease_until IS NULL OR lease_until<=clock_timestamp()) RETURNING * INTO op;
 RETURN op;
END $$;
CREATE FUNCTION public.dispatch_rental_money_operation(p_id uuid,p_lease uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.rental_money_operations SET dispatched_at=coalesce(dispatched_at,clock_timestamp())
 WHERE id=p_id AND lease_token=p_lease AND lease_until>clock_timestamp() AND status='pending';
 RETURN FOUND;
END $$;
CREATE FUNCTION public.release_rental_money_operation(p_id uuid,p_lease uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 UPDATE public.rental_money_operations SET lease_token=NULL,lease_until=NULL WHERE id=p_id AND lease_token=p_lease;
$$;
CREATE FUNCTION public.finish_rental_money_operation(p_id uuid,p_lease uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE op public.rental_money_operations; r public.reservations; target public.reservation_status;
BEGIN
 SELECT * INTO op FROM public.rental_money_operations WHERE id=p_id;
 SELECT * INTO r FROM public.reservations WHERE id=op.reservation_id FOR UPDATE;
 SELECT * INTO op FROM public.rental_money_operations WHERE id=p_id FOR UPDATE;
 IF op.status='complete' THEN RETURN; END IF;
 IF op.id IS NULL OR op.lease_token IS DISTINCT FROM p_lease OR r.payment_id<>op.payment_id
 OR (op.kind='refund' AND (r.status<>'paid' OR r.payment_action IS DISTINCT FROM 'refund_pending'))
 OR (op.kind='settle' AND (r.status<>'returned' OR r.payment_action IS DISTINCT FROM 'settle_pending'))
 THEN RAISE EXCEPTION '금융 작업의 거래 상태가 변경되었습니다.'; END IF;
 target:=CASE WHEN op.kind='refund' THEN 'cancelled'::public.reservation_status ELSE 'settled'::public.reservation_status END;
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status=target,payment_action=NULL,payment_action_started_at=NULL WHERE id=r.id;
 UPDATE public.rental_money_operations SET status='complete',lease_token=NULL,lease_until=NULL WHERE id=op.id;
 INSERT INTO public.rental_events(reservation_id,actor_id,command,from_status,to_status) VALUES(r.id,op.actor_id,op.kind||'Rental',r.status,target);
END $$;

REVOKE ALL ON FUNCTION public.claim_toss_confirmation(text,uuid,text),public.release_toss_confirmation(text,uuid),public.fail_toss_confirmation(text),
 public.begin_rental_money_operation(uuid,uuid,text),public.claim_rental_money_operation(uuid,uuid),public.dispatch_rental_money_operation(uuid,uuid),
 public.release_rental_money_operation(uuid,uuid),public.finish_rental_money_operation(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_toss_confirmation(text,uuid,text),public.release_toss_confirmation(text,uuid),public.fail_toss_confirmation(text),
 public.begin_rental_money_operation(uuid,uuid,text),public.claim_rental_money_operation(uuid,uuid),public.dispatch_rental_money_operation(uuid,uuid),
 public.release_rental_money_operation(uuid,uuid),public.finish_rental_money_operation(uuid,uuid) TO service_role;
