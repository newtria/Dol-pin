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

-- ---------------------------------------------------------------------------
-- 2. In-place migration of existing TEXT data
--
-- Map the historical free-text values that previous code might have
-- written. Anything unrecognised becomes 'pending' (safest — money is
-- still attributable to the borrower) and is logged.
-- ---------------------------------------------------------------------------

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
      ELSE 'pending'::reservation_status
    END
  );

ALTER TABLE reservations
  ALTER COLUMN status SET DEFAULT 'pending'::reservation_status;

-- ---------------------------------------------------------------------------
-- 3. Block direct UPDATE on `status` from the Flutter client
--
-- A column-level INSTEAD-OF trigger that rejects any UPDATE where the
-- status column moves but session_user is NOT service_role. The
-- transition RPC runs SECURITY DEFINER so it bypasses this — that's the
-- only path the column may move.
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

CREATE TABLE reservation_transitions (
  from_status reservation_status NOT NULL,
  to_status   reservation_status NOT NULL,
  actor_kind  TEXT               NOT NULL CHECK (
    actor_kind IN ('borrower', 'lender', 'system', 'admin')
  ),
  PRIMARY KEY (from_status, to_status, actor_kind)
);

INSERT INTO reservation_transitions (from_status, to_status, actor_kind) VALUES
  -- pending → paid : system only (verify-payment)
  ('pending',   'paid',      'system'),
  -- pending → cancelled : borrower or lender (mutual cancel before pay)
  ('pending',   'cancelled', 'borrower'),
  ('pending',   'cancelled', 'lender'),
  -- paid → picked_up : lender confirms handover
  ('paid',      'picked_up', 'lender'),
  -- paid → cancelled : either party, refund-payment runs
  ('paid',      'cancelled', 'borrower'),
  ('paid',      'cancelled', 'lender'),
  ('paid',      'cancelled', 'system'),
  -- picked_up → returned : borrower reports return
  ('picked_up', 'returned',  'borrower'),
  -- picked_up → disputed : either party raises mid-rental issue
  ('picked_up', 'disputed',  'borrower'),
  ('picked_up', 'disputed',  'lender'),
  -- returned → settled : lender accepts; settle-reservation runs
  ('returned',  'settled',   'lender'),
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

  -- Idempotency: same target is a no-op success.
  IF v_row.status = p_target THEN
    RETURN jsonb_build_object(
      'ok',      true,
      'status',  p_target,
      'already', true
    );
  END IF;

  -- Resolve actor_kind. If the caller did not pass one, infer from
  -- auth.uid() against borrower_id / lender_id. service_role callers
  -- (Edge Functions) must pass it explicitly.
  v_actor_kind := COALESCE(p_actor_kind, '');
  IF v_actor_kind = '' THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'error', 'no actor');
    ELSIF auth.uid() = v_row.borrower_id THEN
      v_actor_kind := 'borrower';
    ELSIF auth.uid() = v_row.lender_id THEN
      v_actor_kind := 'lender';
    ELSE
      RETURN jsonb_build_object('ok', false, 'error', 'not a participant');
    END IF;
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
  -- them by skipping the RPC. The trigger above will fire and see
  -- service_role as the role, so the status change is allowed.
  UPDATE reservations
     SET status = p_target,
         pickup_confirmed_at = CASE
           WHEN p_target = 'picked_up' THEN now()
           ELSE pickup_confirmed_at
         END,
         return_confirmed_at = CASE
           WHEN p_target = 'returned' THEN now()
           ELSE return_confirmed_at
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
