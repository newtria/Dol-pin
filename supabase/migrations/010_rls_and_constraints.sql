-- Fix RLS policies and add missing constraints

-- 1. Fix chat_messages UPDATE policy: only allow setting read_at
DROP POLICY IF EXISTS "Receiver can update messages" ON chat_messages;
CREATE POLICY "Receiver can mark messages as read"
  ON chat_messages FOR UPDATE
  USING (receiver_id = auth.uid());

-- 2. Add DELETE policy for rental_items (lenders can delist)
CREATE POLICY "Lenders can delete own items"
  ON rental_items FOR DELETE
  USING (lender_id = auth.uid());

-- 3. Add unique constraint on reviews to prevent duplicates
ALTER TABLE reviews ADD CONSTRAINT unique_review_per_reservation
  UNIQUE (reservation_id, reviewer_id);

-- 4. Add updated_at to rental_items and reservations
ALTER TABLE rental_items ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE reservations ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 5. Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_rental_items_updated_at
  BEFORE UPDATE ON rental_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_reservations_updated_at
  BEFORE UPDATE ON reservations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 6. Restrict public user read to non-deleted active profiles only
-- Keep own profile readable (policy "Users can read own profile" already exists)
DROP POLICY IF EXISTS "Public can read active user profiles" ON users;
CREATE POLICY "Public can read active user profiles"
  ON users FOR SELECT
  USING (deleted_at IS NULL AND is_lender = TRUE);
