-- RLS controls ownership; column privileges restrict which profile attributes
-- the owner may edit. Phone and verification come from trusted commands.
REVOKE UPDATE ON public.users FROM anon, authenticated;
GRANT UPDATE(nickname,profile_image,fav_groups,region,locale) ON public.users TO authenticated;
