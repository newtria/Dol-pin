CREATE TABLE rental_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lender_id UUID REFERENCES users(id) NOT NULL,
  concert_id UUID REFERENCES concerts(id),
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  photos TEXT[] NOT NULL,
  daily_price INTEGER NOT NULL,
  currency TEXT NOT NULL,
  deposit INTEGER NOT NULL,
  condition_grade TEXT,
  vlm_tag TEXT,
  bt_verified BOOLEAN DEFAULT FALSE,
  imei TEXT,
  imei_verified BOOLEAN DEFAULT FALSE,
  pickup_method TEXT NOT NULL,
  pickup_location JSONB,
  available_from DATE,
  available_to DATE,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE rental_items ENABLE ROW LEVEL SECURITY;

-- Active items are publicly readable
CREATE POLICY "Active items are publicly readable"
  ON rental_items FOR SELECT
  USING (status = 'active' OR lender_id = auth.uid());

-- Lenders can insert their own items
CREATE POLICY "Lenders can insert own items"
  ON rental_items FOR INSERT
  WITH CHECK (lender_id = auth.uid());

-- Lenders can update their own items
CREATE POLICY "Lenders can update own items"
  ON rental_items FOR UPDATE
  USING (lender_id = auth.uid());
