-- Escrow state machine for reservations.
--
-- Replaces the free-text `status TEXT` column with a Postgres ENUM and
-- forces all transitions through a SECURITY DEFINER RPC that validates
-- the move against a fixed legal-transition table + actor authority.
--
-- See docs/escrow-state-machine.md for the state diagram, transition
-- table, and rationale. This migration encodes that table exactly —
-- changes to either side require changes to both.
--
-- KRW launch only. Xendit / Stripe paths reuse the state values but
-- their refund helpers are separate.

-- ---------------------------------------------------------------------------
-- 1. ENUM type
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reservation_status') THEN
    CREATE TYPE reservation_status AS ENUM (
      'pending',
      'paid',
      'picked_up',
      'returned',
      'settled',
      'cancelled',
      'disputed',
      'resolved'
    );
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. In-place migration of existing TEXT data
--
-- Map the historical free-text values that previous code might have
-- written. Anything unrecognised aborts the migration; money-state data must
-- be reviewed explicitly instead of being silently coerced into `pending`.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Users can create reviews for completed reservations" ON reviews;
DROP POLICY IF EXISTS "Borrowers can create reservations" ON reservations;
DROP POLICY IF EXISTS "Participants can update own reservations" ON reservations;
DROP POLICY IF EXISTS "rental_photos_insert_own" ON storage.objects;
DROP POLICY IF EXISTS "rental_photos_update_own" ON storage.objects;
DROP POLICY IF EXISTS "rental_photos_delete_own" ON storage.objects;

ALTER TABLE reservations
  DROP CONSTRAINT IF EXISTS excl_reservations_no_overlap;

-- 013 used a `CHECK (rental_date >= CURRENT_DATE)`. PostgreSQL rechecks it on
-- every later row UPDATE, so a normal pickup/return transition after the rental
-- date can fail. Creation-time validation now lives in create_reservation_intent.
ALTER TABLE reservations
  DROP CONSTRAINT IF EXISTS chk_reservations_rental_date_not_past;

DROP INDEX IF EXISTS idx_reservations_item_dates_active;

DO $$
DECLARE
  v_status_udt TEXT;
BEGIN
  SELECT udt_name INTO v_status_udt
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name = 'reservations'
     AND column_name = 'status';

  IF v_status_udt IS DISTINCT FROM 'reservation_status' THEN
    IF EXISTS (
      SELECT 1
      FROM reservations
      WHERE status IS NULL
        OR lower(trim(status)) NOT IN (
        'pending',
        'confirmed',
        'paid',
        'picked_up',
        'returned',
        'completed',
        'settled',
        'refunded',
        'refund_partial',
        'cancelled',
        'disputed',
        'resolved'
      )
    ) THEN
      RAISE EXCEPTION
        'Unknown reservation.status value found. Review/backfill before applying reservation_status enum.';
    END IF;

    ALTER TABLE reservations
      ALTER COLUMN status DROP DEFAULT;

    ALTER TABLE reservations
      ALTER COLUMN status TYPE reservation_status
      USING (
        CASE lower(trim(status))
          WHEN 'pending'        THEN 'pending'::reservation_status
          WHEN 'confirmed'      THEN 'paid'::reservation_status      -- old verify-payment value
          WHEN 'paid'           THEN 'paid'::reservation_status
          WHEN 'picked_up'      THEN 'picked_up'::reservation_status
          WHEN 'returned'       THEN 'returned'::reservation_status
          WHEN 'completed'      THEN 'settled'::reservation_status   -- legacy
          WHEN 'settled'        THEN 'settled'::reservation_status
          WHEN 'refunded'       THEN 'cancelled'::reservation_status -- pre-state-machine refund
          WHEN 'refund_partial' THEN 'disputed'::reservation_status  -- partial refund without state machine = needs review
          WHEN 'cancelled'      THEN 'cancelled'::reservation_status
          WHEN 'disputed'       THEN 'disputed'::reservation_status
          WHEN 'resolved'       THEN 'resolved'::reservation_status
        END
      );
  END IF;

  ALTER TABLE reservations
    ALTER COLUMN status SET DEFAULT 'pending'::reservation_status;
END;
$$;

CREATE POLICY "rental_photos_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'rental-photos'
    AND (
      (
        (storage.foldername(name))[1] = 'items'
        AND (storage.foldername(name))[2] = auth.uid()::text
      )
      OR (
        (storage.foldername(name))[1] = 'returns'
        AND (storage.foldername(name))[3] = auth.uid()::text
        AND EXISTS (
          SELECT 1 FROM reservations r
          WHERE r.id::text = (storage.foldername(name))[2]
            AND r.borrower_id = auth.uid()
            AND r.status = 'picked_up'::reservation_status
        )
      )
    )
  );

CREATE POLICY "rental_photos_update_own"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'rental-photos'
    AND (
      (
        (storage.foldername(name))[1] = 'items'
        AND (storage.foldername(name))[2] = auth.uid()::text
      )
      OR (
        (storage.foldername(name))[1] = 'returns'
        AND (storage.foldername(name))[3] = auth.uid()::text
        AND EXISTS (
          SELECT 1 FROM reservations r
          WHERE r.id::text = (storage.foldername(name))[2]
            AND r.borrower_id = auth.uid()
            AND r.status = 'picked_up'::reservation_status
        )
      )
    )
  );

CREATE POLICY "rental_photos_delete_own"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'rental-photos'
    AND (
      (
        (storage.foldername(name))[1] = 'items'
        AND (storage.foldername(name))[2] = auth.uid()::text
      )
      OR (
        (storage.foldername(name))[1] = 'returns'
        AND (storage.foldername(name))[3] = auth.uid()::text
        AND EXISTS (
          SELECT 1 FROM reservations r
          WHERE r.id::text = (storage.foldername(name))[2]
            AND r.borrower_id = auth.uid()
            AND r.status = 'picked_up'::reservation_status
        )
      )
    )
  );

ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS payment_action TEXT,
  ADD COLUMN IF NOT EXISTS payment_action_started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_attempt_merchant_uid TEXT,
  ADD COLUMN IF NOT EXISTS payment_attempt_started_at TIMESTAMPTZ;

ALTER TABLE reservations
  DROP CONSTRAINT IF EXISTS chk_reservations_payment_action;

ALTER TABLE reservations
  ADD CONSTRAINT chk_reservations_payment_action
  CHECK (
    payment_action IS NULL
    OR payment_action IN ('refund_pending', 'settle_pending', 'dispute_pending')
  );

CREATE UNIQUE INDEX IF NOT EXISTS idx_reservations_payment_id_unique
  ON reservations(payment_id)
  WHERE payment_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_reservations_payment_attempt_uid_unique
  ON reservations(payment_attempt_merchant_uid)
  WHERE payment_attempt_merchant_uid IS NOT NULL;

CREATE TABLE IF NOT EXISTS reservation_dispute_resolutions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID NOT NULL REFERENCES reservations(id),
  actor_id UUID,
  refund_amount INTEGER NOT NULL CHECK (refund_amount >= 0),
  reason TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  provider_refund_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (reservation_id, idempotency_key)
);

ALTER TABLE reservation_dispute_resolutions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Participants can read dispute resolutions"
  ON reservation_dispute_resolutions;

CREATE POLICY "Participants can read dispute resolutions"
  ON reservation_dispute_resolutions FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM reservations r
      WHERE r.id = reservation_dispute_resolutions.reservation_id
        AND (r.borrower_id = auth.uid() OR r.lender_id = auth.uid())
    )
  );

ALTER TABLE reservations
  ADD CONSTRAINT excl_reservations_no_overlap
  EXCLUDE USING gist (
    item_id WITH =,
    daterange(rental_date, return_date, '[)') WITH &&
  )
  WHERE (status IN (
    'pending',
    'paid',
    'picked_up',
    'returned',
    'disputed'
  ));

CREATE INDEX IF NOT EXISTS idx_reservations_item_dates_active
  ON reservations(item_id, rental_date, return_date)
  WHERE status IN (
    'pending',
    'paid',
    'picked_up',
    'returned',
    'disputed'
  );

CREATE POLICY "Users can create reviews for completed reservations"
  ON reviews FOR INSERT
  WITH CHECK (
    reviewer_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM reservations r
      WHERE r.id = reviews.reservation_id
        AND r.status IN ('settled', 'resolved')
        AND (r.borrower_id = auth.uid() OR r.lender_id = auth.uid())
        AND reviews.reviewee_id IN (r.borrower_id, r.lender_id)
        AND reviews.reviewee_id <> auth.uid()
    )
  );

CREATE OR REPLACE FUNCTION protect_user_trust_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_setting('role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF NEW.identity_verified IS DISTINCT FROM OLD.identity_verified
     OR NEW.lender_grade IS DISTINCT FROM OLD.lender_grade
     OR NEW.response_rate IS DISTINCT FROM OLD.response_rate THEN
    RAISE EXCEPTION 'trust fields are service-role managed';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_user_trust_fields ON users;
CREATE TRIGGER trg_protect_user_trust_fields
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION protect_user_trust_fields();

CREATE OR REPLACE FUNCTION protect_rental_item_trust_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_setting('role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF NEW.bt_verified IS DISTINCT FROM OLD.bt_verified
     OR NEW.imei_verified IS DISTINCT FROM OLD.imei_verified THEN
    RAISE EXCEPTION 'item verification fields are service-role managed';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_rental_item_trust_fields ON rental_items;
CREATE TRIGGER trg_protect_rental_item_trust_fields
  BEFORE UPDATE ON rental_items
  FOR EACH ROW
  EXECUTE FUNCTION protect_rental_item_trust_fields();

-- ---------------------------------------------------------------------------
-- 3. Block direct UPDATE on `status` from the Flutter client
--
-- A column-level trigger that rejects any UPDATE where the status column moves
-- unless the caller is service_role or the transition RPC has set the local
-- `app.reservation_status_rpc` guard. The RPC is the only Flutter-reachable
-- path the column may move.
--
-- We do not use a column-level RLS policy because Postgres RLS only
-- gates rows, not columns; the simplest way to gate a single column is
-- a trigger that aborts on the disallowed mutation.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION reservations_block_status_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status
     AND current_setting('app.reservation_status_rpc', true) IS DISTINCT FROM 'on'
     AND current_setting('role', true) <> 'service_role'
     AND NOT pg_has_role('service_role', 'USAGE') THEN
    RAISE EXCEPTION
      'reservations.status must be changed via transition_reservation_status RPC, not direct UPDATE'
      USING HINT = 'Call select transition_reservation_status(id, target) instead.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reservations_block_status_update ON reservations;
CREATE TRIGGER reservations_block_status_update
  BEFORE UPDATE OF status ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION reservations_block_status_update();

-- ---------------------------------------------------------------------------
-- 4. Legal transition table
--
-- (from_status, to_status, actor_kind) — actor_kind ∈ {'borrower',
-- 'lender', 'system', 'admin'}. The RPC joins on this to authorise.
--
-- Maintained in the same module as docs/escrow-state-machine.md;
-- changes need to land in both.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS reservation_transitions (
  from_status reservation_status NOT NULL,
  to_status   reservation_status NOT NULL,
  actor_kind  TEXT               NOT NULL CHECK (
    actor_kind IN ('borrower', 'lender', 'system', 'admin')
  ),
  PRIMARY KEY (from_status, to_status, actor_kind)
);

DELETE FROM reservation_transitions;

INSERT INTO reservation_transitions (from_status, to_status, actor_kind) VALUES
  -- pending → paid : system only (verify-payment)
  ('pending',   'paid',      'system'),
  -- pending → cancelled : borrower or lender (mutual cancel before pay)
  ('pending',   'cancelled', 'borrower'),
  ('pending',   'cancelled', 'lender'),
  -- paid → picked_up : lender confirms handover
  ('paid',      'picked_up', 'lender'),
  -- paid → cancelled : refund-payment runs after provider refund succeeds
  ('paid',      'cancelled', 'system'),
  -- picked_up → returned : borrower reports return
  ('picked_up', 'returned',  'borrower'),
  -- picked_up → disputed : either party raises mid-rental issue
  ('picked_up', 'disputed',  'borrower'),
  ('picked_up', 'disputed',  'lender'),
  -- returned → settled : settle-reservation runs after deposit refund succeeds
  ('returned',  'settled',   'system'),
  -- returned → disputed : lender rejects condition
  ('returned',  'disputed',  'lender'),
  -- disputed → resolved : admin only
  ('disputed',  'resolved',  'admin'),
  ('disputed',  'resolved',  'system');

-- ---------------------------------------------------------------------------
-- 5. Transition RPC
--
-- Returns:
--   { ok: true,  status: <new>, already: false }  — transitioned
--   { ok: true,  status: <new>, already: true  }  — was already at target (idempotent)
--   { ok: false, error: '...' }                   — invalid; row unchanged
-- ---------------------------------------------------------------------------

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

  IF v_row.payment_action IS NOT NULL
     AND COALESCE(v_row.payment_action_started_at, '-infinity'::timestamptz)
       < now() - interval '10 minutes' THEN
    UPDATE reservations
       SET payment_action = NULL,
           payment_action_started_at = NULL
     WHERE id = p_reservation_id;
    v_row.payment_action := NULL;
    v_row.payment_action_started_at := NULL;
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

REVOKE ALL ON FUNCTION transition_reservation_status(
  UUID, reservation_status, TEXT, UUID, TEXT
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION transition_reservation_status(
  UUID, reservation_status, TEXT, UUID, TEXT
) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION expire_stale_pending_reservations()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  PERFORM set_config('app.reservation_status_rpc', 'on', true);

  UPDATE reservations
     SET status = 'cancelled',
         payment_action = NULL,
         payment_action_started_at = NULL,
         payment_attempt_merchant_uid = NULL,
         payment_attempt_started_at = NULL
   WHERE status = 'pending'
     AND COALESCE(created_at, now()) < now() - interval '20 minutes'
     AND (
       payment_attempt_started_at IS NULL
       OR payment_attempt_started_at < now() - interval '30 minutes'
     );

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION expire_stale_pending_reservations() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION expire_stale_pending_reservations() TO service_role;

CREATE OR REPLACE FUNCTION start_reservation_payment_attempt(
  p_reservation_id UUID,
  p_merchant_uid TEXT
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row reservations%ROWTYPE;
  v_uid UUID;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no actor');
  END IF;

  IF p_reservation_id IS NULL OR p_merchant_uid IS NULL OR trim(p_merchant_uid) = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'null argument');
  END IF;

  IF NOT starts_with(
    p_merchant_uid,
    'dolpin_' || p_reservation_id::text || '_'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'merchant_uid mismatch');
  END IF;

  SELECT * INTO v_row
    FROM reservations
   WHERE id = p_reservation_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'reservation not found');
  END IF;

  IF v_row.borrower_id <> v_uid THEN
    RETURN jsonb_build_object('ok', false, 'error', 'only borrower may start payment');
  END IF;

  IF v_row.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false, 'error', format('cannot pay status %s', v_row.status)
    );
  END IF;

  IF v_row.payment_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'reservation already paid');
  END IF;

  IF v_row.payment_attempt_merchant_uid IS NOT NULL
     AND v_row.payment_attempt_merchant_uid <> p_merchant_uid
     AND COALESCE(v_row.payment_attempt_started_at, now())
       >= now() - interval '30 minutes' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'payment attempt already in progress');
  END IF;

  UPDATE reservations
     SET payment_attempt_merchant_uid = p_merchant_uid,
         payment_attempt_started_at = now()
   WHERE id = p_reservation_id;

  RETURN jsonb_build_object('ok', true, 'status', v_row.status);
END;
$$;

REVOKE ALL ON FUNCTION start_reservation_payment_attempt(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION start_reservation_payment_attempt(UUID, TEXT)
  TO authenticated;

CREATE OR REPLACE FUNCTION mark_reservation_paid(
  p_reservation_id UUID,
  p_payment_id TEXT,
  p_provider TEXT DEFAULT 'portone'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row reservations%ROWTYPE;
BEGIN
  IF p_reservation_id IS NULL OR p_payment_id IS NULL OR p_payment_id = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'null argument');
  END IF;

  SELECT * INTO v_row
    FROM reservations
   WHERE id = p_reservation_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'reservation not found');
  END IF;

  IF v_row.payment_id IS NOT NULL AND v_row.payment_id <> p_payment_id THEN
    RETURN jsonb_build_object(
      'ok', false, 'error', 'reservation already has a different payment_id'
    );
  END IF;

  IF v_row.payment_id = p_payment_id AND v_row.status <> 'pending' THEN
    RETURN jsonb_build_object('ok', true, 'status', v_row.status, 'already', true);
  END IF;

  IF v_row.status <> 'pending' THEN
    RETURN jsonb_build_object(
      'ok', false, 'error', format('cannot mark status %s as paid', v_row.status)
    );
  END IF;

  PERFORM set_config('app.reservation_status_rpc', 'on', true);

  UPDATE reservations
     SET status = 'paid',
         payment_provider = p_provider,
         payment_id = p_payment_id,
         payment_attempt_merchant_uid = NULL,
         payment_attempt_started_at = NULL
   WHERE id = p_reservation_id;

  RETURN jsonb_build_object('ok', true, 'status', 'paid', 'already', false);
END;
$$;

REVOKE ALL ON FUNCTION mark_reservation_paid(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION mark_reservation_paid(UUID, TEXT, TEXT) TO service_role;

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
    IF COALESCE(v_row.payment_action_started_at, '-infinity'::timestamptz)
       < now() - interval '10 minutes' THEN
      UPDATE reservations
         SET payment_action = NULL,
             payment_action_started_at = NULL
       WHERE id = p_reservation_id;
      v_row.payment_action := NULL;
      v_row.payment_action_started_at := NULL;
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

REVOKE ALL ON FUNCTION begin_reservation_payment_action(UUID, TEXT, TEXT, UUID)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION begin_reservation_payment_action(UUID, TEXT, TEXT, UUID)
  TO service_role;

CREATE OR REPLACE FUNCTION clear_reservation_payment_action(
  p_reservation_id UUID,
  p_action TEXT
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE reservations
     SET payment_action = NULL,
         payment_action_started_at = NULL
   WHERE id = p_reservation_id
     AND payment_action = p_action;

  RETURN jsonb_build_object('ok', true);
END;
$$;

REVOKE ALL ON FUNCTION clear_reservation_payment_action(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION clear_reservation_payment_action(UUID, TEXT)
  TO service_role;

CREATE OR REPLACE FUNCTION confirm_reservation_return(
  p_reservation_id UUID,
  p_return_photo TEXT
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row reservations%ROWTYPE;
  v_uid UUID;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'no actor');
  END IF;

  IF p_return_photo IS NULL OR trim(p_return_photo) = '' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'return photo is required');
  END IF;

  SELECT * INTO v_row
    FROM reservations
   WHERE id = p_reservation_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'reservation not found');
  END IF;

  IF v_row.borrower_id <> v_uid THEN
    RETURN jsonb_build_object('ok', false, 'error', 'only borrower may confirm return');
  END IF;

  IF v_row.status <> 'picked_up' THEN
    RETURN jsonb_build_object(
      'ok', false, 'error', format('cannot return status %s', v_row.status)
    );
  END IF;

  IF v_row.payment_action IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'payment action in progress');
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM storage.objects o
     WHERE o.bucket_id = 'rental-photos'
       AND o.name LIKE format(
         'returns/%s/%s/%%',
         p_reservation_id::text,
         v_uid::text
       )
       AND (
         p_return_photo = o.name
         OR position(
           '/storage/v1/object/public/rental-photos/' || o.name
           IN p_return_photo
         ) > 0
       )
  ) THEN
    RETURN jsonb_build_object(
      'ok', false, 'error', 'return photo object not found'
    );
  END IF;

  PERFORM set_config('app.reservation_status_rpc', 'on', true);

  UPDATE reservations
     SET status = 'returned',
         return_confirmed_at = now(),
         return_photo = p_return_photo
   WHERE id = p_reservation_id;

  RETURN jsonb_build_object('ok', true, 'status', 'returned', 'already', false);
END;
$$;

REVOKE ALL ON FUNCTION confirm_reservation_return(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION confirm_reservation_return(UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. Server-authoritative reservation creation
--
-- The Flutter client must not provide lender_id, rental_fee, deposit,
-- total_paid, currency, or status. This RPC computes those values from the
-- active rental_items row under lock and lets the exclusion constraint reject
-- overlapping bookings.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION create_reservation_intent(
  p_item_id UUID,
  p_rental_date DATE,
  p_return_date DATE
) RETURNS reservations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item rental_items%ROWTYPE;
  v_borrower_id UUID;
  v_days INTEGER;
  v_reservation reservations%ROWTYPE;
BEGIN
  v_borrower_id := auth.uid();
  IF v_borrower_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_item_id IS NULL OR p_rental_date IS NULL OR p_return_date IS NULL THEN
    RAISE EXCEPTION 'item_id, rental_date, and return_date are required';
  END IF;

  IF p_rental_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'rental_date must not be in the past';
  END IF;

  IF p_return_date <= p_rental_date THEN
    RAISE EXCEPTION 'return_date must be after rental_date';
  END IF;

  PERFORM expire_stale_pending_reservations();

  SELECT * INTO v_item
    FROM rental_items
   WHERE id = p_item_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rental item not found';
  END IF;

  IF v_item.status <> 'active' THEN
    RAISE EXCEPTION 'Rental item is not active';
  END IF;

  IF v_item.lender_id = v_borrower_id THEN
    RAISE EXCEPTION 'Lender cannot reserve their own item';
  END IF;

  IF v_item.available_from IS NOT NULL AND p_rental_date < v_item.available_from THEN
    RAISE EXCEPTION 'rental_date is outside item availability';
  END IF;

  IF v_item.available_to IS NOT NULL AND p_return_date > v_item.available_to THEN
    RAISE EXCEPTION 'return_date is outside item availability';
  END IF;

  v_days := p_return_date - p_rental_date;

  INSERT INTO reservations (
    item_id,
    borrower_id,
    lender_id,
    rental_date,
    return_date,
    rental_fee,
    deposit,
    total_paid,
    currency,
    status
  ) VALUES (
    v_item.id,
    v_borrower_id,
    v_item.lender_id,
    p_rental_date,
    p_return_date,
    v_item.daily_price * v_days,
    v_item.deposit,
    (v_item.daily_price * v_days) + v_item.deposit,
    v_item.currency,
    'pending'
  )
  RETURNING * INTO v_reservation;

  RETURN v_reservation;
END;
$$;

REVOKE ALL ON FUNCTION create_reservation_intent(UUID, DATE, DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_reservation_intent(UUID, DATE, DATE) TO authenticated;
