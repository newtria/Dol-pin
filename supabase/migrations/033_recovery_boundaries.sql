-- A fresh install must not repeatedly invoke an unconfigured worker.
SELECT cron.alter_job(jobid,active:=(SELECT count(*)=2 FROM vault.secrets WHERE name IN ('dolpin_recovery_url','dolpin_recovery_token')))
 FROM cron.job WHERE jobname='dolpin-reconcile-rentals';

-- Legacy commands share reservations with the new clients. Only the durable
-- operation that owns a hold may clear it or finish its financial transition.
CREATE FUNCTION public.protect_rental_money_operation() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE operation_id uuid;
BEGIN
 IF NEW.status IS NOT DISTINCT FROM OLD.status AND NEW.payment_action IS NOT DISTINCT FROM OLD.payment_action THEN RETURN NEW; END IF;
 SELECT id INTO operation_id FROM public.rental_money_operations WHERE reservation_id=OLD.id AND status='pending';
 IF operation_id IS NOT NULL AND current_setting('app.rental_money_operation_id',true) IS DISTINCT FROM operation_id::text
 THEN RAISE EXCEPTION '금융 작업의 결과 확인이 진행 중입니다.'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.protect_rental_money_operation() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER protect_rental_money_operation BEFORE UPDATE OF status,payment_action ON public.reservations
 FOR EACH ROW EXECUTE FUNCTION public.protect_rental_money_operation();

CREATE OR REPLACE FUNCTION public.finish_rental_money_operation(p_id uuid,p_lease uuid)
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
 PERFORM set_config('app.rental_money_operation_id',op.id::text,true);
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status=target,payment_action=NULL,payment_action_started_at=NULL WHERE id=r.id;
 UPDATE public.rental_money_operations SET status='complete',lease_token=NULL,lease_until=NULL WHERE id=op.id;
 INSERT INTO public.rental_events(reservation_id,actor_id,command,from_status,to_status) VALUES(r.id,op.actor_id,op.kind||'Rental',r.status,target);
END $$;

CREATE OR REPLACE FUNCTION public.begin_rental_money_operation(p_reservation_id uuid,p_actor uuid,p_kind text)
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
 PERFORM set_config('app.rental_money_operation_id',op.id::text,true);
 UPDATE public.reservations SET payment_action=CASE WHEN p_kind='refund' THEN 'refund_pending' ELSE 'settle_pending' END,
 payment_action_started_at=clock_timestamp() WHERE id=r.id;
 RETURN op;
END $$;
