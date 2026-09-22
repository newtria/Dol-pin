-- OAuth accounts may have a confirmed email and no phone. Absence of a phone
-- must remain NULL, not a forged placeholder or an identity-verification flag.
ALTER TABLE public.users ALTER COLUMN phone DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.ensure_profile(p_nickname text)
RETURNS public.users
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  actor uuid := auth.uid(); verified_phone text; account_verified boolean;
  profile public.users%ROWTYPE;
BEGIN
  IF actor IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_nickname IS NULL OR length(trim(p_nickname)) NOT BETWEEN 2 AND 30 THEN
    RAISE EXCEPTION 'Nickname must be between 2 and 30 characters';
  END IF;
  SELECT CASE WHEN phone_confirmed_at IS NOT NULL THEN nullif(phone,'') END,
    NOT coalesce(is_anonymous,false) AND (
      (phone_confirmed_at IS NOT NULL AND nullif(phone,'') IS NOT NULL) OR
      (email_confirmed_at IS NOT NULL AND nullif(email,'') IS NOT NULL))
    INTO verified_phone, account_verified FROM auth.users WHERE id=actor;
  IF account_verified IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Verified authentication required' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.users(id,phone,nickname,country,locale,currency)
    VALUES(actor,verified_phone,trim(p_nickname),'KR','ko','KRW') ON CONFLICT(id) DO NOTHING;
  SELECT * INTO STRICT profile FROM public.users WHERE id=actor;
  IF profile.deleted_at IS NOT NULL THEN RAISE EXCEPTION 'Account unavailable' USING ERRCODE='42501'; END IF;
  RETURN profile;
END $$;
REVOKE ALL ON FUNCTION public.ensure_profile(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_profile(text) TO authenticated;
