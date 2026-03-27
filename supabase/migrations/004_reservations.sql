CREATE TABLE reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id UUID REFERENCES rental_items(id) NOT NULL,
  borrower_id UUID REFERENCES users(id) NOT NULL,
  lender_id UUID REFERENCES users(id) NOT NULL,
  rental_date DATE NOT NULL,
  return_date DATE NOT NULL,
  rental_fee INTEGER NOT NULL,
  deposit INTEGER NOT NULL,
  total_paid INTEGER NOT NULL,
  currency TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  pickup_confirmed_at TIMESTAMPTZ,
  return_confirmed_at TIMESTAMPTZ,
  return_photo TEXT,
  payment_provider TEXT,
  payment_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;

-- Participants can read their reservations
CREATE POLICY "Participants can read own reservations"
  ON reservations FOR SELECT
  USING (borrower_id = auth.uid() OR lender_id = auth.uid());

-- Borrowers can create reservations
CREATE POLICY "Borrowers can create reservations"
  ON reservations FOR INSERT
  WITH CHECK (borrower_id = auth.uid());

-- Participants can update reservations
CREATE POLICY "Participants can update own reservations"
  ON reservations FOR UPDATE
  USING (borrower_id = auth.uid() OR lender_id = auth.uid());
