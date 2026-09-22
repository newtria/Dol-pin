-- Checkout capabilities contain no login token and authorize only one reservation.
CREATE TABLE IF NOT EXISTS public.toss_checkouts (
 reservation_id uuid PRIMARY KEY REFERENCES public.reservations(id),
 order_id text NOT NULL UNIQUE,
 token_hash text NOT NULL,
 amount bigint NOT NULL CHECK(amount > 0),
 customer_key uuid NOT NULL,
 expires_at timestamptz NOT NULL,
 mobile boolean NOT NULL DEFAULT false
);
ALTER TABLE public.toss_checkouts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.toss_checkouts FROM anon, authenticated;
GRANT ALL ON public.toss_checkouts TO service_role;

CREATE OR REPLACE FUNCTION public.prepare_toss_checkout(p_reservation_id uuid, p_actor uuid, p_token_hash text, p_mobile boolean)
RETURNS public.toss_checkouts LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.reservations; checkout public.toss_checkouts;
BEGIN
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id FOR UPDATE;
 IF r.id IS NULL OR r.borrower_id <> p_actor THEN RAISE EXCEPTION '대여자만 결제할 수 있습니다.'; END IF;
 IF r.status <> 'accepted' OR r.payment_due_at <= clock_timestamp() OR r.payment_id IS NOT NULL
 OR r.currency <> 'KRW' OR r.total_paid <= 0 THEN RAISE EXCEPTION '결제 가능한 예약이 아닙니다.'; END IF;
 INSERT INTO public.toss_checkouts VALUES(r.id, 'dolpin_' || replace(r.id::text,'-',''),p_token_hash,r.total_paid,r.borrower_id,r.payment_due_at,p_mobile)
 ON CONFLICT(reservation_id) DO UPDATE SET token_hash=excluded.token_hash, mobile=excluded.mobile
 RETURNING * INTO checkout;
 RETURN checkout;
END $$;

-- Reserve the attempt before contacting Toss. Expiry jobs must not discard an
-- approval whose network outcome is unknown. Retrying reconciles the same order.
CREATE OR REPLACE FUNCTION public.begin_toss_confirmation(p_order_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE c public.toss_checkouts; r public.reservations;
BEGIN
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id;
 SELECT * INTO r FROM public.reservations WHERE id=c.reservation_id FOR UPDATE;
 IF r.status = 'paid' AND r.payment_provider='toss' THEN RETURN; END IF;
 IF r.id IS NULL OR c.order_id IS NULL OR r.status <> 'accepted' OR r.total_paid <> c.amount OR r.currency <> 'KRW' OR
 (r.payment_due_at <= clock_timestamp() AND r.payment_attempt_merchant_uid IS DISTINCT FROM c.order_id)
 THEN RAISE EXCEPTION '결제 가능한 예약이 아닙니다.'; END IF;
 UPDATE public.reservations SET payment_attempt_merchant_uid=c.order_id,
 payment_attempt_started_at=coalesce(payment_attempt_started_at,clock_timestamp()) WHERE id=r.id;
END $$;

CREATE OR REPLACE FUNCTION public.finish_toss_confirmation(p_order_id text, p_payment_key text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE c public.toss_checkouts; r public.reservations;
BEGIN
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id;
 SELECT * INTO r FROM public.reservations WHERE id=c.reservation_id FOR UPDATE;
 IF r.payment_provider='toss' AND r.payment_id=p_payment_key THEN RETURN; END IF;
 IF r.id IS NULL OR c.order_id IS NULL OR r.status <> 'accepted' OR r.payment_attempt_merchant_uid IS DISTINCT FROM c.order_id
 OR r.total_paid <> c.amount OR r.payment_id IS NOT NULL THEN RAISE EXCEPTION '예약 결제 상태가 변경되었습니다.'; END IF;
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status='paid', payment_provider='toss', payment_id=p_payment_key,
 payment_attempt_merchant_uid=NULL, payment_attempt_started_at=NULL WHERE id=r.id;
 INSERT INTO public.rental_events(reservation_id,command,from_status,to_status) VALUES(r.id,'confirmTossPayment','accepted','paid');
END $$;
REVOKE ALL ON FUNCTION public.prepare_toss_checkout(uuid,uuid,text,boolean), public.begin_toss_confirmation(text), public.finish_toss_confirmation(text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_toss_checkout(uuid,uuid,text,boolean), public.begin_toss_confirmation(text), public.finish_toss_confirmation(text,text) TO service_role;
