-- Status reads never invoke a provider or expose provider keys/errors.
CREATE FUNCTION public.rental_recovery_status(p_reservation_id uuid)
RETURNS TABLE(state text, next_retry_at timestamptz, reference text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  r public.reservations;
  due_at timestamptz;
  lease_end timestamptz;
  review_at timestamptz;
BEGIN
  SELECT * INTO r FROM public.reservations WHERE id = p_reservation_id
    AND auth.uid() IN (borrower_id, lender_id);
  IF auth.uid() IS NULL OR NOT FOUND THEN
    RAISE EXCEPTION 'Rental access denied' USING ERRCODE = '42501';
  END IF;
  reference := r.id::text;
  IF r.payment_action IS NOT NULL THEN
    SELECT o.next_attempt_at, o.lease_until, o.review_required_at
      INTO due_at, lease_end, review_at FROM public.rental_money_operations o
      WHERE o.reservation_id = r.id AND o.status = 'pending'
      ORDER BY o.created_at DESC LIMIT 1;
  ELSIF r.status = 'accepted' AND r.payment_attempt_merchant_uid IS NOT NULL THEN
    SELECT c.next_attempt_at, c.lease_until, c.review_required_at
      INTO due_at, lease_end, review_at FROM public.toss_checkouts c
      WHERE c.reservation_id = r.id AND c.order_id = r.payment_attempt_merchant_uid;
  ELSE
    state := 'idle'; next_retry_at := NULL; RETURN NEXT; RETURN;
  END IF;
  -- A legacy/untracked financial hold must not be advertised as automatic work.
  IF due_at IS NULL OR review_at IS NOT NULL THEN
    state := 'needs_review'; next_retry_at := NULL;
  ELSIF lease_end > clock_timestamp() THEN
    state := 'processing'; next_retry_at := NULL;
  ELSIF due_at > clock_timestamp() THEN
    state := 'retry_scheduled'; next_retry_at := due_at;
  ELSE
    state := 'processing'; next_retry_at := NULL;
  END IF;
  RETURN NEXT;
END $$;
REVOKE ALL ON FUNCTION public.rental_recovery_status(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rental_recovery_status(uuid) TO authenticated;
