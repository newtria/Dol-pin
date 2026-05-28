-- Rewrites the per-user daily quota RPC from migration 017 to fix two
-- second-pass-audit findings:
--
--   * The original RPC unconditionally INSERT/UPDATE-d before checking the
--     limit, so `count` grew unbounded after the cap. The "requests left
--     today" UI use case mentioned in 017's header would have shown
--     misleading values (effectively negative).
--   * No paired DECREMENT path existed for the case where the cost-bearing
--     work (Gemini call) fails AFTER the increment — a Gemini outage would
--     silently drain a user's daily quota for zero successful analyses.
--
-- The new `increment_function_usage` does the limit check inside the upsert
-- (`ON CONFLICT DO UPDATE WHERE ...`) so a row stops being mutated once it
-- reaches the cap. Callers detect the rejection via `allowed: false` in the
-- jsonb return — same outer contract as v1, so the Deno-side helper does
-- not change.
--
-- `decrement_function_usage` is a paired RPC that walks a counter back by
-- 1 (floor 0). Edge Functions call it on upstream-failure paths so a
-- failed request does not consume a slot.

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
BEGIN
  IF p_user_id IS NULL OR p_function_name IS NULL OR p_limit IS NULL THEN
    RAISE EXCEPTION 'increment_function_usage: null argument';
  END IF;
  IF p_limit < 1 THEN
    RAISE EXCEPTION 'increment_function_usage: limit must be >= 1';
  END IF;

  -- Gated upsert: insert at 1, or bump only when still under the cap.
  -- RETURNING runs only for the affected row, so when the WHERE clause
  -- on the DO UPDATE filters the row out we get no return value here.
  INSERT INTO function_usage_quota (user_id, function_name, day, count)
  VALUES (p_user_id, p_function_name, v_today, 1)
  ON CONFLICT (user_id, function_name, day)
  DO UPDATE SET
    count = function_usage_quota.count + 1,
    updated_at = now()
    WHERE function_usage_quota.count < p_limit
  RETURNING count INTO v_count;

  IF v_count IS NOT NULL THEN
    -- Allowed: the row was inserted (v_count = 1) or bumped to v_count.
    RETURN jsonb_build_object('count', v_count, 'allowed', TRUE);
  END IF;

  -- Rejected: read the existing count for the caller's "requests left"
  -- UI without mutating it further.
  SELECT count INTO v_count
    FROM function_usage_quota
   WHERE user_id = p_user_id
     AND function_name = p_function_name
     AND day = v_today;

  RETURN jsonb_build_object('count', COALESCE(v_count, p_limit), 'allowed', FALSE);
END;
$$;

CREATE OR REPLACE FUNCTION decrement_function_usage(
  p_user_id       UUID,
  p_function_name TEXT
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today DATE := (now() AT TIME ZONE 'UTC')::date;
  v_count INTEGER;
BEGIN
  IF p_user_id IS NULL OR p_function_name IS NULL THEN
    RAISE EXCEPTION 'decrement_function_usage: null argument';
  END IF;

  -- GREATEST clamps to 0 so a buggy double-decrement cannot push the
  -- counter negative (which would let the user effectively exceed the
  -- daily cap by alternating success/failure paths).
  UPDATE function_usage_quota
     SET count = GREATEST(count - 1, 0),
         updated_at = now()
   WHERE user_id = p_user_id
     AND function_name = p_function_name
     AND day = v_today
  RETURNING count INTO v_count;

  RETURN jsonb_build_object('count', COALESCE(v_count, 0));
END;
$$;

REVOKE ALL ON FUNCTION decrement_function_usage(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION decrement_function_usage(UUID, TEXT)
  TO service_role;
