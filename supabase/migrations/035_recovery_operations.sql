-- Operational state is separate from financial status: a review MUST retain
-- the pending operation and reservation hold, including through legacy RPCs.
ALTER TABLE public.toss_checkouts
 ADD COLUMN attempt_count integer NOT NULL DEFAULT 0,
 ADD COLUMN failure_count integer NOT NULL DEFAULT 0,
 ADD COLUMN next_attempt_at timestamptz NOT NULL DEFAULT now(),
 ADD COLUMN last_error_code text,
 ADD COLUMN last_error_at timestamptz,
 ADD COLUMN review_required_at timestamptz;
CREATE INDEX toss_checkouts_recovery_due ON public.toss_checkouts(next_attempt_at)
 WHERE review_required_at IS NULL;
ALTER TABLE public.rental_money_operations
 ADD COLUMN attempt_count integer NOT NULL DEFAULT 0,
 ADD COLUMN failure_count integer NOT NULL DEFAULT 0,
 ADD COLUMN next_attempt_at timestamptz NOT NULL DEFAULT now(),
 ADD COLUMN last_error_code text,
 ADD COLUMN last_error_at timestamptz,
 ADD COLUMN review_required_at timestamptz;
CREATE INDEX rental_money_operations_recovery_due ON public.rental_money_operations(next_attempt_at)
 WHERE review_required_at IS NULL AND status='pending';

CREATE OR REPLACE FUNCTION public.claim_toss_confirmation(p_order_id text,p_lease uuid,p_payment_key text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE c public.toss_checkouts; r public.reservations;
BEGIN
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id;
 SELECT * INTO r FROM public.reservations WHERE id=c.reservation_id FOR UPDATE;
 SELECT * INTO c FROM public.toss_checkouts WHERE order_id=p_order_id FOR UPDATE;
 IF c.order_id IS NULL OR r.status NOT IN ('accepted','paid') THEN RAISE EXCEPTION '결제 가능한 예약이 아닙니다.'; END IF;
 IF c.review_required_at IS NOT NULL THEN RAISE EXCEPTION 'Recovery requires review' USING ERRCODE='PDR01'; END IF;
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
 UPDATE public.toss_checkouts SET attempt_count=attempt_count+1,lease_token=p_lease,lease_until=clock_timestamp()+interval '90 seconds',last_checked_at=clock_timestamp() WHERE order_id=p_order_id;
 RETURN true;
END $$;

CREATE OR REPLACE FUNCTION public.claim_rental_money_operation(p_id uuid,p_lease uuid)
RETURNS public.rental_money_operations LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE op public.rental_money_operations;
BEGIN
 IF EXISTS(SELECT 1 FROM public.rental_money_operations WHERE id=p_id AND status='pending' AND review_required_at IS NOT NULL) THEN RAISE EXCEPTION 'Recovery requires review' USING ERRCODE='PDR01'; END IF;
 UPDATE public.rental_money_operations SET attempt_count=attempt_count+1,lease_token=p_lease,lease_until=clock_timestamp()+interval '90 seconds',last_checked_at=clock_timestamp()
 WHERE id=p_id AND status='pending' AND review_required_at IS NULL AND (lease_until IS NULL OR lease_until<=clock_timestamp()) RETURNING * INTO op;
 RETURN op;
END $$;

CREATE OR REPLACE FUNCTION public.prepare_toss_checkout(p_reservation_id uuid,p_actor uuid,p_token_hash text,p_mobile boolean)
RETURNS public.toss_checkouts LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; c public.toss_checkouts;
BEGIN
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id FOR UPDATE;
 IF p_actor IS NULL OR r.id IS NULL OR r.borrower_id<>p_actor THEN RAISE EXCEPTION '대여자만 결제할 수 있습니다.' USING ERRCODE='42501'; END IF;
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

-- A stale worker cannot overwrite a newer lease's result. Persist only bounded,
-- stable codes, never provider bodies, tokens or arbitrary exception messages.
CREATE FUNCTION public.record_rental_recovery_attempt(
 p_kind text,p_key text,p_lease uuid,p_code text,p_review boolean DEFAULT false,p_failed boolean DEFAULT true
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE target text; key_column text;
BEGIN
 IF p_kind IS NULL OR p_kind NOT IN ('checkout','money') OR p_code IS NULL OR p_code !~ '^[A-Z_]{1,48}$'
 THEN RAISE EXCEPTION 'Invalid recovery result' USING ERRCODE='22023'; END IF;
 target:=CASE p_kind WHEN 'checkout' THEN 'toss_checkouts' ELSE 'rental_money_operations' END;
 key_column:=CASE p_kind WHEN 'checkout' THEN 'order_id' ELSE 'id' END;
 EXECUTE format('UPDATE public.%I SET
  failure_count=failure_count+CASE WHEN $4 THEN 1 ELSE 0 END,
  last_error_code=$1,last_error_at=clock_timestamp(),
  review_required_at=CASE WHEN $2 OR ($4 AND failure_count+1>=8) THEN coalesce(review_required_at,clock_timestamp()) ELSE review_required_at END,
  next_attempt_at=clock_timestamp()+make_interval(secs=>CASE WHEN $4 THEN least(3600,30*power(2,least(failure_count,7)))::integer ELSE 60 END)
  WHERE %I::text=$3 AND lease_token=$5',target,key_column)
 USING p_code,p_review,p_key,p_failed,p_lease;
END $$;

-- Operator retry only resumes reconciliation; it never clears a money hold,
-- payment key, dispatch timestamp or provider idempotency key.
CREATE FUNCTION public.retry_rental_recovery(p_kind text,p_key text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_kind='money' THEN
  UPDATE public.rental_money_operations SET review_required_at=NULL,failure_count=0,next_attempt_at=clock_timestamp()
  WHERE id::text=p_key AND status='pending' AND (lease_until IS NULL OR lease_until<=clock_timestamp());
 ELSIF p_kind='checkout' THEN
  UPDATE public.toss_checkouts c SET review_required_at=NULL,failure_count=0,next_attempt_at=clock_timestamp()
  WHERE order_id=p_key AND (lease_until IS NULL OR lease_until<=clock_timestamp())
   AND EXISTS(SELECT 1 FROM public.reservations r WHERE r.id=c.reservation_id AND r.status='accepted');
 ELSE RAISE EXCEPTION 'Invalid recovery kind' USING ERRCODE='22023'; END IF;
 RETURN FOUND;
END $$;

CREATE VIEW public.rental_recovery_queue AS
 SELECT 'money'::text AS kind,id::text AS key,reservation_id,attempt_count,failure_count,next_attempt_at,last_error_code,last_error_at,review_required_at,created_at
 FROM public.rental_money_operations WHERE status='pending'
 UNION ALL
 SELECT 'checkout',c.order_id,c.reservation_id,c.attempt_count,c.failure_count,c.next_attempt_at,c.last_error_code,c.last_error_at,c.review_required_at,r.created_at
 FROM public.toss_checkouts c JOIN public.reservations r ON r.id=c.reservation_id WHERE r.status='accepted';
REVOKE ALL ON public.rental_recovery_queue FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.rental_recovery_queue TO service_role;

CREATE TABLE public.rental_recovery_dispatches (
 request_id bigint PRIMARY KEY,created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.rental_recovery_dispatches ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rental_recovery_dispatches FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.rental_recovery_dispatches TO service_role;
CREATE OR REPLACE FUNCTION public.invoke_rental_recovery() RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE endpoint text; token text; request_id bigint;
BEGIN
 SELECT decrypted_secret INTO endpoint FROM vault.decrypted_secrets WHERE name='dolpin_recovery_url';
 SELECT decrypted_secret INTO token FROM vault.decrypted_secrets WHERE name='dolpin_recovery_token';
 IF endpoint IS NULL OR token IS NULL THEN RAISE EXCEPTION 'Recovery is not configured'; END IF;
 SELECT net.http_post(url:=endpoint,headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||token),body:='{}'::jsonb,timeout_milliseconds:=60000) INTO request_id;
 INSERT INTO public.rental_recovery_dispatches(request_id) VALUES(request_id);
 DELETE FROM public.rental_recovery_dispatches WHERE created_at<now()-interval '7 days';
 RETURN request_id;
END $$;
CREATE FUNCTION public.rental_recovery_health() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object(
  'configured',(SELECT count(*)=2 FROM vault.secrets WHERE name IN ('dolpin_recovery_url','dolpin_recovery_token')),
  'scheduled',coalesce((SELECT active FROM cron.job WHERE jobname='dolpin-reconcile-rentals'),false),
  'pending',(SELECT count(*) FROM public.rental_recovery_queue),
  'needsReview',(SELECT count(*) FROM public.rental_recovery_queue WHERE review_required_at IS NOT NULL),
  'lastDispatch',(SELECT jsonb_build_object('at',d.created_at,'status',r.status_code,'timedOut',r.timed_out)
   FROM public.rental_recovery_dispatches d LEFT JOIN net._http_response r ON r.id=d.request_id ORDER BY d.created_at DESC LIMIT 1)
 );
$$;
REVOKE ALL ON FUNCTION public.record_rental_recovery_attempt(text,text,uuid,text,boolean,boolean),public.retry_rental_recovery(text,text),public.rental_recovery_health() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_rental_recovery_attempt(text,text,uuid,text,boolean,boolean),public.retry_rental_recovery(text,text),public.rental_recovery_health() TO service_role;
