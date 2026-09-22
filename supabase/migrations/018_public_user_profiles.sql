-- Public profile read surface
--
-- RLS policies are row-scoped, not column-scoped. Keeping a public SELECT
-- policy on `users` can expose contact or push-token columns when a caller
-- selects the table directly. Public/partner profile reads now go through this
-- sanitized view; the base table remains readable only through the existing
-- "Users can read own profile" policy.

DROP POLICY IF EXISTS "Public can read active user profiles" ON users;
DROP POLICY IF EXISTS "Public can read active lenders and reservation partners"
  ON users;

CREATE OR REPLACE VIEW public_user_profiles
WITH (security_barrier = true)
AS
SELECT
  id,
  nickname,
  profile_image,
  is_lender,
  lender_grade,
  response_rate,
  created_at
FROM users
WHERE deleted_at IS NULL;

REVOKE ALL ON public_user_profiles FROM PUBLIC;
GRANT SELECT ON public_user_profiles TO anon, authenticated;
