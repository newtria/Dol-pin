CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL UNIQUE,
  nickname TEXT NOT NULL,
  profile_image TEXT,
  is_lender BOOLEAN DEFAULT FALSE,
  identity_verified BOOLEAN DEFAULT FALSE,
  lender_grade TEXT DEFAULT 'newbie',
  fav_groups TEXT[],
  country TEXT NOT NULL,
  region TEXT,
  locale TEXT DEFAULT 'en',
  currency TEXT DEFAULT 'USD',
  response_rate DECIMAL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Public read for lender profiles (other users need to see them)
CREATE POLICY "Public can read active user profiles"
  ON users FOR SELECT
  USING (deleted_at IS NULL);
