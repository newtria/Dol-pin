-- Requested rentals do not hold inventory. Acceptance owns the half-open
-- timestamp range; PostgreSQL remains the final concurrency boundary.
ALTER TABLE public.reservations
  ADD COLUMN starts_at timestamptz,
  ADD COLUMN ends_at timestamptz,
  ADD COLUMN client_request_id uuid,
  ADD COLUMN quoted_item_version timestamptz,
  ADD COLUMN accepted_at timestamptz,
  ADD COLUMN payment_due_at timestamptz,
  ADD COLUMN terms_snapshot jsonb;

ALTER TABLE public.reservations
  DROP CONSTRAINT chk_reservations_return_after_rental,
  ADD CONSTRAINT chk_reservations_return_after_rental CHECK (return_date >= rental_date),
  ADD CONSTRAINT rental_time_pair CHECK (
    (starts_at IS NULL AND ends_at IS NULL) OR
    (starts_at IS NOT NULL AND ends_at IS NOT NULL AND isfinite(starts_at)
      AND isfinite(ends_at) AND ends_at > starts_at)),
  ADD CONSTRAINT requested_rental_contract CHECK (
    status NOT IN ('requested', 'accepted', 'rejected', 'expired') OR
    (starts_at IS NOT NULL AND client_request_id IS NOT NULL AND quoted_item_version IS NOT NULL)),
  ADD CONSTRAINT accepted_rental_terms CHECK (
    status <> 'accepted' OR
    (accepted_at IS NOT NULL AND payment_due_at IS NOT NULL AND terms_snapshot IS NOT NULL)),
  ADD CONSTRAINT rental_request_identity UNIQUE (borrower_id, client_request_id);

ALTER TABLE public.reservations DROP CONSTRAINT excl_reservations_no_overlap;
ALTER TABLE public.reservations ADD CONSTRAINT excl_reservations_no_overlap
  EXCLUDE USING gist (
    item_id WITH =,
    tstzrange(
      coalesce(starts_at, rental_date::timestamp AT TIME ZONE 'Asia/Seoul'),
      coalesce(ends_at, return_date::timestamp AT TIME ZONE 'Asia/Seoul'), '[)') WITH &&
  ) WHERE (status IN ('pending', 'accepted', 'paid', 'picked_up', 'returned', 'disputed'));

CREATE TABLE public.rental_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reservation_id uuid NOT NULL REFERENCES public.reservations(id),
  actor_id uuid REFERENCES public.users(id),
  command text NOT NULL,
  from_status public.reservation_status,
  to_status public.reservation_status NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX rental_events_reservation ON public.rental_events(reservation_id, id);
ALTER TABLE public.rental_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY rental_event_participant_read ON public.rental_events FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.reservations r WHERE r.id = reservation_id
  AND (r.borrower_id = (SELECT auth.uid()) OR r.lender_id = (SELECT auth.uid()))));
REVOKE ALL ON public.rental_events FROM anon, authenticated;
GRANT SELECT ON public.rental_events TO authenticated, service_role;

CREATE FUNCTION public.request_rental(
  p_item_id uuid, p_starts_at timestamptz, p_ends_at timestamptz,
  p_item_version timestamptz, p_request_id uuid
) RETURNS public.reservations
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor uuid := auth.uid(); item public.rental_items%ROWTYPE;
  rental public.reservations%ROWTYPE; days numeric; fee numeric;
BEGIN
  IF actor IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.' USING ERRCODE = '42501'; END IF;
  IF p_item_id IS NULL OR p_request_id IS NULL OR p_item_version IS NULL
     OR p_starts_at IS NULL OR p_ends_at IS NULL
     OR NOT isfinite(p_starts_at) OR NOT isfinite(p_ends_at) THEN
    RAISE EXCEPTION '물품과 대여 기간이 필요합니다.';
  END IF;
  -- Every inventory command locks item before reservation.
  SELECT * INTO item FROM public.rental_items WHERE id = p_item_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '물품을 찾을 수 없습니다.'; END IF;
  SELECT * INTO rental FROM public.reservations
    WHERE borrower_id = actor AND client_request_id = p_request_id;
  IF FOUND THEN
    IF rental.item_id IS DISTINCT FROM p_item_id OR rental.starts_at IS DISTINCT FROM p_starts_at
       OR rental.ends_at IS DISTINCT FROM p_ends_at OR rental.quoted_item_version IS DISTINCT FROM p_item_version THEN
      RAISE EXCEPTION '같은 요청 식별자로 조건을 변경할 수 없습니다.';
    END IF;
    RETURN rental;
  END IF;
  IF item.lender_id = actor OR item.status <> 'active' OR item.currency <> 'KRW' THEN
    RAISE EXCEPTION '예약할 수 없는 물품입니다.';
  END IF;
  IF item.updated_at IS DISTINCT FROM p_item_version THEN
    RAISE EXCEPTION '상품 조건이 변경되었습니다. 상세를 새로 확인해 주세요.';
  END IF;
  IF p_starts_at <= clock_timestamp() OR p_ends_at <= p_starts_at THEN
    RAISE EXCEPTION '시작은 현재 이후, 반납은 시작 이후여야 합니다.';
  END IF;
  IF (item.available_from IS NOT NULL AND (p_starts_at AT TIME ZONE 'Asia/Seoul')::date < item.available_from)
     OR (item.available_to IS NOT NULL AND (p_ends_at AT TIME ZONE 'Asia/Seoul')::date > item.available_to) THEN
    RAISE EXCEPTION '대여 가능한 기간을 벗어났습니다.';
  END IF;
  days := ceil(extract(epoch FROM p_ends_at - p_starts_at) / 86400);
  fee := days * item.daily_price;
  IF fee + item.deposit > 2147483647 THEN RAISE EXCEPTION '대여 금액 범위를 초과했습니다.'; END IF;
  INSERT INTO public.reservations(item_id, borrower_id, lender_id, rental_date, return_date,
    starts_at, ends_at, client_request_id, quoted_item_version, rental_fee, deposit, total_paid, currency, status)
  VALUES(item.id, actor, item.lender_id, (p_starts_at AT TIME ZONE 'Asia/Seoul')::date,
    (p_ends_at AT TIME ZONE 'Asia/Seoul')::date, p_starts_at, p_ends_at, p_request_id,
    item.updated_at, fee::integer, item.deposit, (fee + item.deposit)::integer, 'KRW', 'requested')
  RETURNING * INTO rental;
  INSERT INTO public.rental_events(reservation_id, actor_id, command, to_status)
    VALUES(rental.id, actor, 'requestRental', rental.status);
  RETURN rental;
END $$;

CREATE FUNCTION public.respond_to_rental(p_reservation_id uuid, p_action text)
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
      'version', 1, 'item_id', item.id, 'title', item.title, 'category', item.category,
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

-- Explicitly invoked by scheduler/operations. No payment attempt is abandoned.
CREATE FUNCTION public.expire_unpaid_rentals() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE count_expired integer;
BEGIN
  PERFORM set_config('app.reservation_status_rpc', 'on', true);
  WITH expired AS (
    UPDATE public.reservations SET status = 'expired'
    WHERE status = 'accepted' AND payment_due_at <= clock_timestamp()
      AND payment_id IS NULL AND payment_action IS NULL AND payment_attempt_merchant_uid IS NULL
    RETURNING id
  ), events AS (
    INSERT INTO public.rental_events(reservation_id, command, from_status, to_status)
      SELECT id, 'expireRental', 'accepted', 'expired' FROM expired RETURNING id
  ) SELECT count(*) INTO count_expired FROM events;
  RETURN count_expired;
END $$;

REVOKE ALL ON FUNCTION public.request_rental(uuid,timestamptz,timestamptz,timestamptz,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.respond_to_rental(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.expire_unpaid_rentals() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.request_rental(uuid,timestamptz,timestamptz,timestamptz,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_rental(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_unpaid_rentals() TO service_role;
-- Retain legacy implementation for migration verification, prevent new clients
-- bypassing lender acceptance with the historical pending->paid path.
REVOKE EXECUTE ON FUNCTION public.create_reservation_intent(uuid,date,date) FROM PUBLIC, anon, authenticated;
