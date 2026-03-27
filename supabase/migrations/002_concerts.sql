CREATE TABLE concerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  venue TEXT NOT NULL,
  city TEXT NOT NULL,
  country TEXT NOT NULL,
  concert_date DATE NOT NULL,
  poster_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE concerts ENABLE ROW LEVEL SECURITY;

-- Concerts are publicly readable
CREATE POLICY "Concerts are publicly readable"
  ON concerts FOR SELECT
  USING (true);
