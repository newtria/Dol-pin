-- Fraud Flags (rule-based)
CREATE TABLE fraud_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) NOT NULL,
  flag_type TEXT NOT NULL,
  severity TEXT DEFAULT 'warning',
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE fraud_flags ENABLE ROW LEVEL SECURITY;

-- Only admins/service role can read fraud flags

-- Reports (App Store 1.2 required)
CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES users(id) NOT NULL,
  reported_user_id UUID REFERENCES users(id),
  reported_item_id UUID REFERENCES rental_items(id),
  reason TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'pending',
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can create reports"
  ON reports FOR INSERT
  WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "Users can read own reports"
  ON reports FOR SELECT
  USING (reporter_id = auth.uid());

-- User Blocks (App Store 1.2 required)
CREATE TABLE user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID REFERENCES users(id) NOT NULL,
  blocked_id UUID REFERENCES users(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(blocker_id, blocked_id)
);

ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own blocks"
  ON user_blocks FOR ALL
  USING (blocker_id = auth.uid());
