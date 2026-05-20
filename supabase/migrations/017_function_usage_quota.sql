-- Per-user daily quota for cost-bearing Edge Functions.
--
-- Today this gates `gemini-analyze` (Gemini billing) and is wired for use
-- by `push-notification` once FCM goes live. The Edge Function calls the
-- `increment_function_usage` RPC exactly once at the start of each request
-- and rejects the call if the new count would exceed the per-user daily
-- limit.
--
-- Design choices:
--   * Day boundary is UTC. Mobile clients should consider clock skew
--     irrelevant — the boundary moves once a day either way.
--   * The table is append-style per (user_id, function_name, day); no
--     historical retention policy yet (rows are tiny). Vacuum if it grows.
--   * The RPC is `SECURITY DEFINER` so functions running under the
--     service-role key can call it without granting blanket write on the
--     underlying table.
--   * Reads of other users' counters are forbidden by RLS. The service-
--     role key bypasses RLS for the RPC itself — direct table access by
--     authenticated users is blocked.

CREATE TABLE IF NOT EXISTS function_usage_quota (
  user_id       UUID    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  function_name TEXT    NOT NULL,
  day           DATE    NOT NULL,
  count         INTEGER NOT NULL DEFAULT 0,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, function_name, day)
);

CREATE INDEX IF NOT EXISTS function_usage_quota_day_idx
  ON function_usage_quota (day);

ALTER TABLE function_usage_quota ENABLE ROW LEVEL SECURITY;

-- Authenticated users may read only their own counters (no other rows
-- ever leak). Writes are blocked from authenticated and anonymous
-- clients entirely — only the RPC may mutate.
DROP POLICY IF EXISTS function_usage_quota_self_read ON function_usage_quota;
CREATE POLICY function_usage_quota_self_read
  ON function_usage_quota
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION increment_function_usage(
  p_user_id       UUID,
  p_function_name TEXT,
  p_limit         INTEGER
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today DATE := (now() AT TIME ZONE 'UTC')::date;
  v_count INTEGER;
  v_allowed BOOLEAN;
BEGIN
  IF p_user_id IS NULL OR p_function_name IS NULL OR p_limit IS NULL THEN
    RAISE EXCEPTION 'increment_function_usage: null argument';
  END IF;
  IF p_limit < 1 THEN
    RAISE EXCEPTION 'increment_function_usage: limit must be >= 1';
  END IF;

  -- Upsert + increment in one statement. The unique PK guarantees only
  -- one row per (user, function, day); concurrent calls serialise via
  -- the row lock obtained by the UPDATE.
  INSERT INTO function_usage_quota (user_id, function_name, day, count)
  VALUES (p_user_id, p_function_name, v_today, 1)
  ON CONFLICT (user_id, function_name, day)
  DO UPDATE SET
    count = function_usage_quota.count + 1,
    updated_at = now()
  RETURNING count INTO v_count;

  v_allowed := v_count <= p_limit;

  RETURN jsonb_build_object('count', v_count, 'allowed', v_allowed);
END;
$$;

REVOKE ALL ON FUNCTION increment_function_usage(UUID, TEXT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION increment_function_usage(UUID, TEXT, INTEGER)
  TO service_role;
