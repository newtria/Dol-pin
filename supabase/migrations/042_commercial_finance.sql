-- Participant custody and claims; money remains under the existing durable lease.
CREATE TABLE public.rental_pickup_confirmations (
 reservation_id uuid PRIMARY KEY REFERENCES public.reservations(id),
 borrower_confirmed_at timestamptz,
 lender_confirmed_at timestamptz
);
ALTER TABLE public.rental_pickup_confirmations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rental_pickup_confirmations FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.rental_pickup_confirmations TO service_role;

CREATE FUNCTION public.rental_pickup_status(p_reservation_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; c public.rental_pickup_confirmations;
BEGIN
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id AND auth.uid() IN (borrower_id,lender_id);
 IF EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NOT NULL)
 THEN RAISE EXCEPTION '탈퇴한 계정입니다.' USING ERRCODE='42501'; END IF;
 IF r.id IS NULL THEN RAISE EXCEPTION '거래 접근 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 SELECT * INTO c FROM public.rental_pickup_confirmations WHERE reservation_id=r.id;
 RETURN jsonb_build_object('status',r.status,'borrowerConfirmed',c.borrower_confirmed_at IS NOT NULL,
 'lenderConfirmed',c.lender_confirmed_at IS NOT NULL);
END $$;

CREATE FUNCTION public.confirm_rental_pickup(p_reservation_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; c public.rental_pickup_confirmations; actor uuid:=auth.uid();
BEGIN
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM public.users WHERE id=actor AND deleted_at IS NOT NULL)
 THEN RAISE EXCEPTION '탈퇴한 계정입니다.' USING ERRCODE='42501'; END IF;
 IF actor IS NULL OR r.id IS NULL OR actor NOT IN (r.borrower_id,r.lender_id)
 THEN RAISE EXCEPTION '인수 확인 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 IF r.status='picked_up' THEN RETURN public.rental_pickup_status(r.id); END IF;
 IF r.status<>'paid' OR r.payment_action IS NOT NULL THEN RAISE EXCEPTION '인수 확인 가능한 거래가 아닙니다.'; END IF;
 INSERT INTO public.rental_pickup_confirmations(reservation_id) VALUES(r.id) ON CONFLICT DO NOTHING;
 UPDATE public.rental_pickup_confirmations SET
 borrower_confirmed_at=CASE WHEN actor=r.borrower_id THEN coalesce(borrower_confirmed_at,clock_timestamp()) ELSE borrower_confirmed_at END,
 lender_confirmed_at=CASE WHEN actor=r.lender_id THEN coalesce(lender_confirmed_at,clock_timestamp()) ELSE lender_confirmed_at END
 WHERE reservation_id=r.id RETURNING * INTO c;
 IF c.borrower_confirmed_at IS NOT NULL AND c.lender_confirmed_at IS NOT NULL THEN
  PERFORM set_config('app.reservation_status_rpc','on',true);
  UPDATE public.reservations SET status='picked_up',pickup_confirmed_at=clock_timestamp() WHERE id=r.id;
 END IF;
 RETURN public.rental_pickup_status(r.id);
END $$;

CREATE FUNCTION public.require_mutual_rental_pickup() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.status='picked_up' AND OLD.status IS DISTINCT FROM NEW.status AND NOT EXISTS(
  SELECT 1 FROM public.rental_pickup_confirmations WHERE reservation_id=NEW.id
   AND borrower_confirmed_at IS NOT NULL AND lender_confirmed_at IS NOT NULL)
 THEN RAISE EXCEPTION '양측의 인수 확인이 필요합니다.'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER require_mutual_rental_pickup BEFORE UPDATE OF status ON public.reservations
 FOR EACH ROW EXECUTE FUNCTION public.require_mutual_rental_pickup();

-- Once either participant attests to handover, a refund needs a dispute
-- decision. Otherwise a party could take possession and cancel before the
-- second participant taps their confirmation.
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
 IF p_kind='refund' AND EXISTS(SELECT 1 FROM public.rental_pickup_confirmations WHERE reservation_id=r.id
  AND (borrower_confirmed_at IS NOT NULL OR lender_confirmed_at IS NOT NULL))
 THEN RAISE EXCEPTION '인수 확인 후에는 분쟁 접수로 환불을 요청해 주세요.'; END IF;
 INSERT INTO public.rental_money_operations(reservation_id,kind,actor_id,provider,payment_id,amount,total)
 VALUES(r.id,p_kind,p_actor,r.payment_provider,r.payment_id,CASE WHEN p_kind='refund' THEN r.total_paid ELSE r.deposit END,r.total_paid)
 RETURNING * INTO op;
 PERFORM set_config('app.rental_money_operation_id',op.id::text,true);
 UPDATE public.reservations SET payment_action=CASE WHEN p_kind='refund' THEN 'refund_pending' ELSE 'settle_pending' END,
 payment_action_started_at=clock_timestamp() WHERE id=r.id;
 RETURN op;
END $$;

CREATE TABLE public.rental_disputes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 reservation_id uuid NOT NULL REFERENCES public.reservations(id),
 reporter_id uuid REFERENCES public.users(id),
 operator_id uuid,
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 5 AND 2000),
 evidence_paths text[] NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL DEFAULT now(),
 resolved_at timestamptz,
 UNIQUE(reservation_id,reporter_id),
 CHECK(cardinality(evidence_paths)<=10),
 CHECK((reporter_id IS NOT NULL AND operator_id IS NULL) OR (reporter_id IS NULL AND operator_id IS NOT NULL))
);
ALTER TABLE public.rental_disputes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rental_disputes FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.rental_disputes TO authenticated;
GRANT ALL ON public.rental_disputes TO service_role;
CREATE POLICY rental_dispute_participants ON public.rental_disputes FOR SELECT TO authenticated USING(
 EXISTS(SELECT 1 FROM public.reservations r WHERE r.id=reservation_id AND auth.uid() IN (r.borrower_id,r.lender_id)));
CREATE INDEX rental_disputes_open ON public.rental_disputes(created_at) WHERE resolved_at IS NULL;
CREATE UNIQUE INDEX rental_disputes_operator_case ON public.rental_disputes(reservation_id) WHERE reporter_id IS NULL;
REVOKE ALL ON public.reservation_dispute_resolutions FROM PUBLIC,anon,authenticated;
GRANT SELECT(reservation_id,refund_amount,reason,created_at) ON public.reservation_dispute_resolutions TO authenticated;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES('dispute-evidence','dispute-evidence',false,5242880,ARRAY['image/jpeg','image/png','image/webp']);
CREATE POLICY dispute_evidence_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(
 bucket_id='dispute-evidence' AND (storage.foldername(name))[2]=auth.uid()::text
 AND EXISTS(SELECT 1 FROM public.reservations r WHERE r.id::text=(storage.foldername(name))[1]
  AND auth.uid() IN (r.borrower_id,r.lender_id) AND r.status IN ('paid','picked_up','returned','disputed') AND r.payment_action IS NULL));
CREATE POLICY dispute_evidence_read ON storage.objects FOR SELECT TO authenticated USING(
 bucket_id='dispute-evidence' AND EXISTS(SELECT 1 FROM public.reservations r
 WHERE r.id::text=(storage.foldername(name))[1] AND auth.uid() IN (r.borrower_id,r.lender_id)));

CREATE FUNCTION public.open_rental_dispute(p_reservation_id uuid,p_reason text,p_evidence_paths text[] DEFAULT '{}')
RETURNS public.rental_disputes LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; d public.rental_disputes; actor uuid:=auth.uid(); path text;
BEGIN
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id FOR UPDATE;
 IF actor IS NULL OR r.id IS NULL OR actor NOT IN (r.borrower_id,r.lender_id)
 THEN RAISE EXCEPTION '분쟁 접수 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 IF p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 2000 OR p_evidence_paths IS NULL OR cardinality(p_evidence_paths)>10
 THEN RAISE EXCEPTION '분쟁 내용을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 SELECT * INTO d FROM public.rental_disputes WHERE reservation_id=r.id AND reporter_id=actor;
 IF FOUND THEN RETURN d; END IF;
 IF r.status NOT IN ('paid','picked_up','returned','disputed') OR r.payment_action IS NOT NULL
 THEN RAISE EXCEPTION '분쟁 접수 가능한 거래가 아닙니다.'; END IF;
 FOREACH path IN ARRAY p_evidence_paths LOOP
  IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='dispute-evidence' AND name=path
   AND (storage.foldername(name))[1]=r.id::text AND (storage.foldername(name))[2]=actor::text)
  THEN RAISE EXCEPTION '거래에 속한 증빙 사진이 필요합니다.' USING ERRCODE='22023'; END IF;
 END LOOP;
 INSERT INTO public.rental_disputes(reservation_id,reporter_id,reason,evidence_paths)
 VALUES(r.id,actor,btrim(p_reason),p_evidence_paths) RETURNING * INTO d;
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status='disputed' WHERE id=r.id;
 RETURN d;
END $$;

CREATE FUNCTION public.add_rental_dispute_evidence(p_reservation_id uuid,p_path text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; d public.rental_disputes;
BEGIN
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id FOR UPDATE;
 IF auth.uid() IS NULL OR r.id IS NULL OR auth.uid() NOT IN (r.borrower_id,r.lender_id)
 THEN RAISE EXCEPTION '분쟁 접근 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 IF r.status<>'disputed' OR r.payment_action IS NOT NULL THEN RAISE EXCEPTION '증빙을 추가할 수 없는 상태입니다.'; END IF;
 SELECT * INTO d FROM public.rental_disputes WHERE reservation_id=r.id AND reporter_id=auth.uid() FOR UPDATE;
 IF d.id IS NULL THEN RAISE EXCEPTION '먼저 분쟁 내용을 접수해 주세요.'; END IF;
 IF p_path=ANY(d.evidence_paths) THEN RETURN; END IF;
 IF cardinality(d.evidence_paths)>=10 OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='dispute-evidence' AND name=p_path
  AND (storage.foldername(name))[1]=r.id::text AND (storage.foldername(name))[2]=auth.uid()::text)
 THEN RAISE EXCEPTION '증빙 사진을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 UPDATE public.rental_disputes SET evidence_paths=array_append(evidence_paths,p_path) WHERE id=d.id;
END $$;

-- Remove the older participant path which accepted a dispute with no case record.
DELETE FROM public.reservation_transitions WHERE to_status='disputed' AND actor_kind IN ('borrower','lender');

CREATE FUNCTION public.assert_finance_operator(p_actor uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_actor IS NULL OR NOT EXISTS(SELECT 1 FROM auth.users WHERE id=p_actor
  AND raw_app_meta_data->'dolpin_operator'='true'::jsonb)
 OR EXISTS(SELECT 1 FROM public.users WHERE id=p_actor AND deleted_at IS NOT NULL)
 THEN RAISE EXCEPTION '운영 권한이 없습니다.' USING ERRCODE='42501'; END IF;
END $$;

ALTER TABLE public.rental_money_operations DROP CONSTRAINT rental_money_operations_kind_check;
ALTER TABLE public.rental_money_operations ADD CONSTRAINT rental_money_operations_kind_check CHECK(kind IN ('refund','settle','dispute'));
ALTER TABLE public.rental_money_operations ADD COLUMN resolution_reason text;
ALTER TABLE public.rental_money_operations ADD CONSTRAINT rental_money_amount_bounds CHECK(amount<=total);
-- Operators may have an auth identity before creating a marketplace profile.
ALTER TABLE public.rental_money_operations DROP CONSTRAINT rental_money_operations_actor_id_fkey;

CREATE FUNCTION public.begin_rental_dispute_resolution(p_reservation_id uuid,p_actor uuid,p_refund_amount integer,p_reason text)
RETURNS public.rental_money_operations LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.reservations; op public.rental_money_operations;
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 IF p_refund_amount IS NULL OR p_refund_amount<0 OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 2000
 THEN RAISE EXCEPTION '처리 내용을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 SELECT * INTO r FROM public.reservations WHERE id=p_reservation_id FOR UPDATE;
 SELECT * INTO op FROM public.rental_money_operations WHERE reservation_id=r.id AND kind='dispute';
 IF FOUND THEN
  IF op.amount<>p_refund_amount OR op.resolution_reason<>btrim(p_reason)
  THEN RAISE EXCEPTION '이미 접수된 환불 결정을 변경할 수 없습니다.'; END IF;
  RETURN op;
 END IF;
 IF r.id IS NULL OR r.status<>'disputed' OR r.payment_action IS NOT NULL OR r.payment_id IS NULL
  OR r.payment_provider NOT IN ('toss','portone') OR r.currency<>'KRW' OR p_refund_amount>r.total_paid
 THEN RAISE EXCEPTION '처리 가능한 분쟁이 아닙니다.'; END IF;
 INSERT INTO public.rental_money_operations(reservation_id,kind,actor_id,provider,payment_id,amount,total,resolution_reason)
 VALUES(r.id,'dispute',p_actor,r.payment_provider,r.payment_id,p_refund_amount,r.total_paid,btrim(p_reason)) RETURNING * INTO op;
 PERFORM set_config('app.rental_money_operation_id',op.id::text,true);
 UPDATE public.reservations SET payment_action='dispute_pending',payment_action_started_at=clock_timestamp() WHERE id=r.id;
 RETURN op;
END $$;

CREATE TABLE public.payout_accounts (
 user_id uuid PRIMARY KEY REFERENCES public.users(id),
 bank_name text NOT NULL CHECK(length(btrim(bank_name)) BETWEEN 2 AND 60),
 account_number text NOT NULL CHECK(account_number ~ '^[0-9]{6,30}$'),
 holder_name text NOT NULL CHECK(length(btrim(holder_name)) BETWEEN 2 AND 80),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.rental_payouts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 reservation_id uuid NOT NULL UNIQUE REFERENCES public.reservations(id),
 lender_id uuid NOT NULL REFERENCES public.users(id),
 amount integer NOT NULL CHECK(amount>=0),
 fee_amount integer NOT NULL DEFAULT 0 CHECK(fee_amount>=0 AND fee_amount<=amount),
 net_amount integer GENERATED ALWAYS AS (amount-fee_amount) STORED,
 currency text NOT NULL DEFAULT 'KRW' CHECK(currency='KRW'),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','processing','paid','failed')),
 claimed_by uuid,
 claim_token uuid,
 claimed_at timestamptz,
 transfer_reference text UNIQUE,
 paid_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK((status='paid')=(paid_at IS NOT NULL))
);
CREATE TABLE public.payout_claim_accounts (
 payout_id uuid PRIMARY KEY REFERENCES public.rental_payouts(id),
 bank_name text NOT NULL,
 account_number text NOT NULL,
 holder_name text NOT NULL
);
CREATE TABLE public.payout_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 payout_id uuid NOT NULL REFERENCES public.rental_payouts(id),
 actor_id uuid,
 action text NOT NULL CHECK(action IN ('claim','paid','failed','verified_not_sent','legacy_review')),
 note text,
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.payout_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rental_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payout_claim_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payout_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.payout_accounts,public.rental_payouts,public.payout_claim_accounts,public.payout_audit FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.payout_accounts,public.rental_payouts,public.payout_claim_accounts TO service_role;
GRANT SELECT,INSERT ON public.payout_audit TO service_role;
REVOKE UPDATE,DELETE,TRUNCATE ON public.payout_audit FROM service_role;
GRANT USAGE ON SEQUENCE public.payout_audit_id_seq TO service_role;
CREATE INDEX rental_payouts_queue ON public.rental_payouts(created_at) WHERE status<>'paid';
CREATE INDEX rental_payouts_lender ON public.rental_payouts(lender_id,created_at DESC);

CREATE FUNCTION public.save_payout_account(p_bank_name text,p_account_number text,p_holder_name text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NULL FOR SHARE;
 IF auth.uid() IS NULL OR NOT FOUND THEN RAISE EXCEPTION '로그인이 필요합니다.' USING ERRCODE='42501'; END IF;
 INSERT INTO public.payout_accounts(user_id,bank_name,account_number,holder_name)
 VALUES(auth.uid(),btrim(p_bank_name),regexp_replace(p_account_number,'[- ]','','g'),btrim(p_holder_name))
 ON CONFLICT(user_id) DO UPDATE SET bank_name=EXCLUDED.bank_name,account_number=EXCLUDED.account_number,
 holder_name=EXCLUDED.holder_name,updated_at=clock_timestamp();
END $$;
CREATE FUNCTION public.own_payout_account() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('bankName',bank_name,'accountNumber',account_number,'holderName',holder_name)
 FROM public.payout_accounts WHERE user_id=auth.uid();
$$;
CREATE FUNCTION public.own_rental_payouts(p_before timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(to_jsonb(p)),'[]'::jsonb) FROM (
  SELECT id,reservation_id,lender_id,amount,fee_amount,net_amount,currency,status,paid_at,created_at
  FROM public.rental_payouts WHERE lender_id=auth.uid()
  AND EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND deleted_at IS NULL)
  AND (p_before IS NULL OR (created_at,id)<(p_before,p_before_id))
  ORDER BY created_at DESC,id DESC LIMIT 100
 ) p;
$$;

CREATE OR REPLACE FUNCTION public.finish_rental_money_operation(p_id uuid,p_lease uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE op public.rental_money_operations; r public.reservations; target public.reservation_status; payout_amount integer;
BEGIN
 SELECT * INTO op FROM public.rental_money_operations WHERE id=p_id;
 SELECT * INTO r FROM public.reservations WHERE id=op.reservation_id FOR UPDATE;
 SELECT * INTO op FROM public.rental_money_operations WHERE id=p_id FOR UPDATE;
 IF op.status='complete' THEN RETURN; END IF;
 IF p_lease IS NULL OR op.id IS NULL OR op.lease_token IS DISTINCT FROM p_lease OR op.lease_until IS NULL
  OR op.lease_until<=clock_timestamp() OR r.payment_id IS DISTINCT FROM op.payment_id
  OR (op.kind='refund' AND (r.status<>'paid' OR r.payment_action IS DISTINCT FROM 'refund_pending'))
  OR (op.kind='settle' AND (r.status<>'returned' OR r.payment_action IS DISTINCT FROM 'settle_pending'))
  OR (op.kind='dispute' AND (r.status<>'disputed' OR r.payment_action IS DISTINCT FROM 'dispute_pending'))
 THEN RAISE EXCEPTION '금융 작업의 거래 상태가 변경되었습니다.'; END IF;
 target:=CASE op.kind WHEN 'refund' THEN 'cancelled'::public.reservation_status
 WHEN 'settle' THEN 'settled'::public.reservation_status ELSE 'resolved'::public.reservation_status END;
 IF op.kind='dispute' THEN
  INSERT INTO public.reservation_dispute_resolutions(reservation_id,actor_id,refund_amount,reason,idempotency_key,provider_refund_id)
  VALUES(r.id,op.actor_id,op.amount,op.resolution_reason,op.id::text,CASE WHEN op.amount>0 THEN op.payment_id END);
  UPDATE public.rental_disputes SET resolved_at=clock_timestamp() WHERE reservation_id=r.id;
 END IF;
 PERFORM set_config('app.rental_money_operation_id',op.id::text,true);
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status=target,payment_action=NULL,payment_action_started_at=NULL WHERE id=r.id;
 UPDATE public.rental_money_operations SET status='complete',lease_token=NULL,lease_until=NULL WHERE id=op.id;
 -- No commission policy is configured: the captured fee is exactly zero.
 IF op.kind IN ('settle','dispute') THEN
  payout_amount:=op.total-op.amount;
  INSERT INTO public.rental_payouts(reservation_id,lender_id,amount,status,paid_at)
  VALUES(r.id,r.lender_id,payout_amount,CASE WHEN payout_amount=0 THEN 'paid' ELSE 'pending' END,
   CASE WHEN payout_amount=0 THEN clock_timestamp() END);
 END IF;
 INSERT INTO public.rental_events(reservation_id,actor_id,command,from_status,to_status)
 VALUES(r.id,CASE WHEN EXISTS(SELECT 1 FROM public.users WHERE id=op.actor_id) THEN op.actor_id END,op.kind||'Rental',r.status,target);
END $$;

-- Historical terminal rows might already have been paid by hand. Reconcile
-- them before releasing them; a deployment must never cause another transfer.
INSERT INTO public.rental_payouts(reservation_id,lender_id,amount,status,paid_at)
 SELECT r.id,r.lender_id,
 CASE WHEN r.status='settled' THEN r.rental_fee ELSE greatest(0,r.total_paid-d.refund_amount) END,
 'failed',NULL
 FROM public.reservations r LEFT JOIN LATERAL (
  SELECT refund_amount FROM public.reservation_dispute_resolutions WHERE reservation_id=r.id ORDER BY created_at DESC LIMIT 1
 ) d ON true WHERE r.status='settled' OR (r.status='resolved' AND d.refund_amount IS NOT NULL);
INSERT INTO public.payout_audit(payout_id,action,note)
 SELECT id,'legacy_review','기존 지급 여부 및 종결 금액 대조 필요' FROM public.rental_payouts;

CREATE FUNCTION public.claim_rental_payout(p_id uuid,p_actor uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.rental_payouts; a public.payout_accounts;
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 SELECT * INTO p FROM public.rental_payouts WHERE id=p_id FOR UPDATE;
 IF p.id IS NULL OR p.net_amount<=0 THEN RAISE EXCEPTION '지급 대상이 아닙니다.'; END IF;
 IF p.status IN ('processing','failed') AND p.claimed_by=p_actor THEN
  RETURN jsonb_build_object('payout',to_jsonb(p)-'claim_token','claimToken',p.claim_token,'account',
   (SELECT jsonb_build_object('bankName',bank_name,'accountNumber',account_number,'holderName',holder_name)
    FROM public.payout_claim_accounts WHERE payout_id=p.id));
 END IF;
 IF p.status<>'pending' THEN RAISE EXCEPTION '이미 처리 중이거나 확인이 필요한 지급입니다.'; END IF;
 SELECT * INTO a FROM public.payout_accounts WHERE user_id=p.lender_id;
 IF a.user_id IS NULL THEN RAISE EXCEPTION '수취 계좌가 등록되지 않았습니다.'; END IF;
 UPDATE public.rental_payouts SET status='processing',claimed_by=p_actor,claim_token=gen_random_uuid(),claimed_at=clock_timestamp()
 WHERE id=p.id RETURNING * INTO p;
 INSERT INTO public.payout_claim_accounts(payout_id,bank_name,account_number,holder_name)
 VALUES(p.id,a.bank_name,a.account_number,a.holder_name)
 ON CONFLICT(payout_id) DO UPDATE SET bank_name=EXCLUDED.bank_name,account_number=EXCLUDED.account_number,holder_name=EXCLUDED.holder_name;
 INSERT INTO public.payout_audit(payout_id,actor_id,action) VALUES(p.id,p_actor,'claim');
 RETURN jsonb_build_object('payout',to_jsonb(p)-'claim_token','claimToken',p.claim_token,
 'account',jsonb_build_object('bankName',a.bank_name,'accountNumber',a.account_number,'holderName',a.holder_name));
END $$;

CREATE FUNCTION public.finish_rental_payout(p_id uuid,p_actor uuid,p_claim_token uuid,p_reference text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.rental_payouts;
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 IF p_reference IS NULL OR length(btrim(p_reference)) NOT BETWEEN 4 AND 160
 THEN RAISE EXCEPTION '송금 증빙 번호가 필요합니다.' USING ERRCODE='22023'; END IF;
 SELECT * INTO p FROM public.rental_payouts WHERE id=p_id FOR UPDATE;
 IF p.id IS NULL OR p.claimed_by IS DISTINCT FROM p_actor OR p_claim_token IS NULL OR p.claim_token IS DISTINCT FROM p_claim_token
 THEN RAISE EXCEPTION '지급 처리 권한이 변경되었습니다.' USING ERRCODE='42501'; END IF;
 IF p.status='paid' AND p.transfer_reference=btrim(p_reference) THEN RETURN to_jsonb(p)-'claim_token'; END IF;
 IF p.status NOT IN ('processing','failed') THEN RAISE EXCEPTION '이미 처리된 지급입니다.'; END IF;
 UPDATE public.rental_payouts SET status='paid',transfer_reference=btrim(p_reference),paid_at=clock_timestamp()
 WHERE id=p.id RETURNING * INTO p;
 INSERT INTO public.payout_audit(payout_id,actor_id,action,note) VALUES(p.id,p_actor,'paid',btrim(p_reference));
 RETURN to_jsonb(p)-'claim_token';
END $$;

CREATE FUNCTION public.fail_rental_payout(p_id uuid,p_actor uuid,p_claim_token uuid,p_reason text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.rental_payouts;
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 IF p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 1000
 THEN RAISE EXCEPTION '보류 사유가 필요합니다.' USING ERRCODE='22023'; END IF;
 SELECT * INTO p FROM public.rental_payouts WHERE id=p_id FOR UPDATE;
 IF p.id IS NULL OR p.claimed_by IS DISTINCT FROM p_actor OR p_claim_token IS NULL OR p.claim_token IS DISTINCT FROM p_claim_token
 THEN RAISE EXCEPTION '지급 처리 권한이 변경되었습니다.' USING ERRCODE='42501'; END IF;
 IF p.status='failed' THEN RETURN to_jsonb(p)-'claim_token'; END IF;
 IF p.status<>'processing' THEN RAISE EXCEPTION '보류할 수 없는 지급입니다.'; END IF;
 UPDATE public.rental_payouts SET status='failed' WHERE id=p.id RETURNING * INTO p;
 INSERT INTO public.payout_audit(payout_id,actor_id,action,note) VALUES(p.id,p_actor,'failed',btrim(p_reason));
 RETURN to_jsonb(p)-'claim_token';
END $$;

CREATE FUNCTION public.retry_rental_payout(p_id uuid,p_actor uuid,p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 IF p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 1000
 THEN RAISE EXCEPTION '은행에서 미송금을 확인한 근거가 필요합니다.' USING ERRCODE='22023'; END IF;
 UPDATE public.rental_payouts SET status=CASE WHEN net_amount=0 THEN 'paid' ELSE 'pending' END,
  paid_at=CASE WHEN net_amount=0 THEN clock_timestamp() END,claim_token=NULL,claimed_by=NULL,claimed_at=NULL
 WHERE id=p_id AND status='failed';
 IF NOT FOUND THEN RAISE EXCEPTION '재개 가능한 지급이 아닙니다.'; END IF;
 INSERT INTO public.payout_audit(payout_id,actor_id,action,note) VALUES(p_id,p_actor,'verified_not_sent',btrim(p_reason));
END $$;

CREATE TABLE public.rental_operator_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 reservation_id uuid NOT NULL REFERENCES public.reservations(id),
 kind text NOT NULL CHECK(kind IN ('pickup_overdue','return_overdue','settlement_overdue','dispute_unresolved','untracked_payment','legacy_finance')),
 created_at timestamptz NOT NULL DEFAULT now(),
 closed_at timestamptz,
 closed_by uuid,
 resolution_note text,
 UNIQUE(reservation_id,kind)
);
ALTER TABLE public.rental_operator_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rental_operator_reviews FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.rental_operator_reviews TO service_role;
CREATE INDEX rental_operator_reviews_open ON public.rental_operator_reviews(created_at) WHERE closed_at IS NULL;
CREATE INDEX rental_pickup_review_due ON public.reservations(starts_at) WHERE status='paid';
CREATE INDEX rental_return_review_due ON public.reservations(ends_at) WHERE status='picked_up';
CREATE INDEX rental_settlement_review_due ON public.reservations(return_confirmed_at) WHERE status='returned';

CREATE TABLE public.finance_operator_audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 reservation_id uuid NOT NULL REFERENCES public.reservations(id),
 actor_id uuid NOT NULL,
 action text NOT NULL CHECK(action IN ('escalate','close_review','retry_recovery')),
 note text,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.finance_operator_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.finance_operator_audit FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT,INSERT ON public.finance_operator_audit TO service_role;
GRANT USAGE ON SEQUENCE public.finance_operator_audit_id_seq TO service_role;

CREATE FUNCTION public.escalate_rental_operator_review(p_id uuid,p_actor uuid,p_note text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE review public.rental_operator_reviews; r public.reservations;
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 IF p_note IS NULL OR length(btrim(p_note)) NOT BETWEEN 5 AND 2000
 THEN RAISE EXCEPTION '운영 접수 근거가 필요합니다.' USING ERRCODE='22023'; END IF;
 SELECT * INTO review FROM public.rental_operator_reviews WHERE id=p_id;
 SELECT * INTO r FROM public.reservations WHERE id=review.reservation_id FOR UPDATE;
 SELECT * INTO review FROM public.rental_operator_reviews WHERE id=p_id FOR UPDATE;
 IF review.id IS NULL OR r.id IS NULL THEN RAISE EXCEPTION '검토할 거래가 없습니다.'; END IF;
 IF review.closed_at IS NOT NULL THEN
  IF review.resolution_note=btrim(p_note) AND EXISTS(SELECT 1 FROM public.finance_operator_audit
   WHERE reservation_id=r.id AND actor_id=p_actor AND action='escalate' AND note=btrim(p_note)) THEN RETURN; END IF;
  RAISE EXCEPTION '이미 처리된 검토입니다.';
 END IF;
 IF r.status NOT IN ('paid','picked_up','returned','disputed') OR r.payment_action IS NOT NULL
  OR r.payment_attempt_merchant_uid IS NOT NULL THEN RAISE EXCEPTION '금융 확인 중이거나 종결된 거래입니다.'; END IF;
 INSERT INTO public.rental_disputes(reservation_id,operator_id,reason)
 VALUES(r.id,p_actor,btrim(p_note)) ON CONFLICT(reservation_id) WHERE reporter_id IS NULL DO NOTHING;
 PERFORM set_config('app.reservation_status_rpc','on',true);
 UPDATE public.reservations SET status='disputed' WHERE id=r.id;
 UPDATE public.rental_operator_reviews SET closed_at=clock_timestamp(),closed_by=p_actor,resolution_note=btrim(p_note) WHERE id=review.id;
 INSERT INTO public.finance_operator_audit(reservation_id,actor_id,action,note) VALUES(r.id,p_actor,'escalate',btrim(p_note));
END $$;

CREATE FUNCTION public.retry_rental_recovery_as_operator(p_kind text,p_key text,p_actor uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE rental_id uuid; changed boolean;
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 changed:=public.retry_rental_recovery(p_kind,p_key);
 IF changed THEN
  IF p_kind='money' THEN SELECT reservation_id INTO rental_id FROM public.rental_money_operations WHERE id=p_key::uuid;
  ELSE SELECT reservation_id INTO rental_id FROM public.toss_checkouts WHERE order_id=p_key; END IF;
  INSERT INTO public.finance_operator_audit(reservation_id,actor_id,action,note) VALUES(rental_id,p_actor,'retry_recovery',p_kind||':'||p_key);
 END IF;
 RETURN changed;
END $$;

CREATE FUNCTION public.refresh_rental_operator_reviews() RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 INSERT INTO public.rental_operator_reviews(reservation_id,kind)
 SELECT id,CASE
 WHEN status='resolved' THEN 'legacy_finance'
 WHEN payment_action IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.rental_money_operations o WHERE o.reservation_id=r.id AND o.status='pending') THEN 'untracked_payment'
 WHEN status='paid' THEN 'pickup_overdue'
 WHEN status='picked_up' THEN 'return_overdue'
 WHEN status='returned' THEN 'settlement_overdue'
 ELSE 'dispute_unresolved' END
 FROM public.reservations r WHERE
 (status='paid' AND coalesce(starts_at,rental_date::timestamp AT TIME ZONE 'Asia/Seoul')<now()-interval '24 hours')
 OR (status='picked_up' AND coalesce(ends_at,return_date::timestamp AT TIME ZONE 'Asia/Seoul')<now()-interval '24 hours')
 OR (status='returned' AND return_confirmed_at<now()-interval '72 hours')
 OR (status='disputed' AND coalesce((SELECT min(d.created_at) FROM public.rental_disputes d WHERE d.reservation_id=r.id),r.created_at)<now()-interval '72 hours')
 OR (payment_action IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.rental_money_operations o WHERE o.reservation_id=r.id AND o.status='pending'))
 OR (status='resolved' AND NOT EXISTS(SELECT 1 FROM public.reservation_dispute_resolutions d WHERE d.reservation_id=r.id))
 ON CONFLICT DO NOTHING;
$$;
CREATE FUNCTION public.close_rental_operator_review(p_id uuid,p_actor uuid,p_note text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM public.assert_finance_operator(p_actor);
 IF p_note IS NULL OR length(btrim(p_note)) NOT BETWEEN 5 AND 1000
 THEN RAISE EXCEPTION '처리 내용이 필요합니다.' USING ERRCODE='22023'; END IF;
 WITH closed AS (UPDATE public.rental_operator_reviews SET closed_at=clock_timestamp(),closed_by=p_actor,resolution_note=btrim(p_note)
 WHERE id=p_id AND closed_at IS NULL
 RETURNING reservation_id)
 INSERT INTO public.finance_operator_audit(reservation_id,actor_id,action,note)
 SELECT reservation_id,p_actor,'close_review',btrim(p_note) FROM closed;
END $$;

CREATE FUNCTION public.finance_reservation_summaries(p_ids uuid[]) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) FROM (
  SELECT id,status,total_paid,deposit,rental_fee,borrower_id,lender_id,payment_action
  FROM public.reservations WHERE id=ANY(p_ids) AND cardinality(p_ids)<=404
 ) r;
$$;

REVOKE ALL ON FUNCTION public.require_mutual_rental_pickup(),public.assert_finance_operator(uuid),
 public.begin_rental_dispute_resolution(uuid,uuid,integer,text),public.claim_rental_payout(uuid,uuid),
 public.finish_rental_payout(uuid,uuid,uuid,text),public.fail_rental_payout(uuid,uuid,uuid,text),
 public.retry_rental_payout(uuid,uuid,text),public.refresh_rental_operator_reviews(),public.close_rental_operator_review(uuid,uuid,text),public.finance_reservation_summaries(uuid[]),
 public.escalate_rental_operator_review(uuid,uuid,text),public.retry_rental_recovery_as_operator(text,text,uuid)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.assert_finance_operator(uuid),public.begin_rental_dispute_resolution(uuid,uuid,integer,text),
 public.claim_rental_payout(uuid,uuid),public.finish_rental_payout(uuid,uuid,uuid,text),public.fail_rental_payout(uuid,uuid,uuid,text),
 public.retry_rental_payout(uuid,uuid,text),public.refresh_rental_operator_reviews(),public.close_rental_operator_review(uuid,uuid,text),public.finance_reservation_summaries(uuid[]),
 public.escalate_rental_operator_review(uuid,uuid,text),public.retry_rental_recovery_as_operator(text,text,uuid) TO service_role;
REVOKE ALL ON FUNCTION public.rental_pickup_status(uuid),public.confirm_rental_pickup(uuid),public.open_rental_dispute(uuid,text,text[]),
 public.add_rental_dispute_evidence(uuid,text),public.save_payout_account(text,text,text),public.own_payout_account(),public.own_rental_payouts(timestamptz,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.rental_pickup_status(uuid),public.confirm_rental_pickup(uuid),public.open_rental_dispute(uuid,text,text[]),
 public.add_rental_dispute_evidence(uuid,text),public.save_payout_account(text,text,text),public.own_payout_account(),public.own_rental_payouts(timestamptz,uuid) TO authenticated;

-- Database-only scheduling still works before provider recovery is configured.
SELECT cron.schedule('dolpin-commercial-review','*/15 * * * *','SELECT public.refresh_rental_operator_reviews()');
