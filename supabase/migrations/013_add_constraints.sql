-- Fix database integrity: date validation, double-booking prevention,
-- amount validation, and missing indexes.

-- ============================================================
-- 1. Reservation date validation
-- ============================================================

-- rental_date must not be in the past
ALTER TABLE reservations
  ADD CONSTRAINT chk_reservations_rental_date_not_past
  CHECK (rental_date >= CURRENT_DATE);

-- return_date must be strictly after rental_date
ALTER TABLE reservations
  ADD CONSTRAINT chk_reservations_return_after_rental
  CHECK (return_date > rental_date);

-- ============================================================
-- 2. Double-booking prevention (exclusion constraint)
--    Prevents overlapping date ranges for the same item
--    among active reservations (not cancelled/completed/disputed).
-- ============================================================

-- btree_gist is required for combining btree (uuid =) with
-- range overlap (daterange &&) in an exclusion constraint.
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Partial exclusion constraint: two active reservations for the
-- same item_id must not have overlapping [rental_date, return_date).
ALTER TABLE reservations
  ADD CONSTRAINT excl_reservations_no_overlap
  EXCLUDE USING gist (
    item_id WITH =,
    daterange(rental_date, return_date, '[)') WITH &&
  )
  WHERE (status NOT IN ('cancelled', 'completed', 'disputed'));

-- ============================================================
-- 3. Missing indexes for performance
--    Using IF NOT EXISTS so the migration is idempotent for indexes
--    that may already exist from 009_indexes.sql.
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_rental_items_lender_id
  ON rental_items(lender_id);

CREATE INDEX IF NOT EXISTS idx_rental_items_status
  ON rental_items(status);

CREATE INDEX IF NOT EXISTS idx_reservations_status
  ON reservations(status);

CREATE INDEX IF NOT EXISTS idx_reservations_borrower_id
  ON reservations(borrower_id);

-- Composite index for the double-booking exclusion fast path
CREATE INDEX IF NOT EXISTS idx_reservations_item_dates_active
  ON reservations(item_id, rental_date, return_date)
  WHERE status NOT IN ('cancelled', 'completed', 'disputed');

-- ============================================================
-- 4. Reservation amount validation
-- ============================================================

ALTER TABLE reservations
  ADD CONSTRAINT chk_reservations_rental_fee_non_negative
  CHECK (rental_fee >= 0);

ALTER TABLE reservations
  ADD CONSTRAINT chk_reservations_deposit_non_negative
  CHECK (deposit >= 0);

ALTER TABLE reservations
  ADD CONSTRAINT chk_reservations_total_paid_non_negative
  CHECK (total_paid >= 0);
