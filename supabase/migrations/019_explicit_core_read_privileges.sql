-- RLS filters rows but does not grant table privileges. Fresh local Supabase
-- does not inherit the permissive grants assumed by the original migrations.
-- Start with the read surface needed by the existing reservation flow. Client
-- writes remain command-only until each feature's field grants are audited.
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

GRANT SELECT ON public.concerts, public.rental_items,
  public.public_user_profiles TO anon, authenticated;
GRANT SELECT ON public.users, public.reservations TO authenticated;

-- An installation may already have historical grants. Explicitly remove
-- direct reservation writes instead of relying solely on the removed policy.
REVOKE INSERT, UPDATE, DELETE ON public.reservations FROM anon, authenticated;

-- Existing trusted payment functions read reservations and write the separate
-- dispute resolution record. Bypass-RLS alone does not confer table access.
GRANT SELECT ON public.users, public.concerts, public.rental_items,
  public.reservations, public.reservation_dispute_resolutions TO service_role;
GRANT INSERT ON public.reservation_dispute_resolutions TO service_role;
