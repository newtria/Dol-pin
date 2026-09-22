-- Only Auth's confirmed phone may become a profile identity. Clients cannot
-- supply a different id/phone or grant themselves trust/operations privileges.
CREATE OR REPLACE FUNCTION public.ensure_profile(p_nickname text)
RETURNS public.users
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid uuid := auth.uid(); v_phone text; v_profile public.users;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501'; END IF;
  IF p_nickname IS NULL OR length(trim(p_nickname)) NOT BETWEEN 2 AND 30 THEN
    RAISE EXCEPTION 'Nickname must be between 2 and 30 characters';
  END IF;
  SELECT phone INTO v_phone FROM auth.users
    WHERE id = v_uid AND phone_confirmed_at IS NOT NULL;
  IF v_phone IS NULL OR v_phone = '' THEN
    RAISE EXCEPTION 'Verified phone required' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.users (id, phone, nickname, country, locale, currency)
    VALUES (v_uid, v_phone, trim(p_nickname), 'KR', 'ko', 'KRW')
    ON CONFLICT (id) DO NOTHING;
  SELECT * INTO STRICT v_profile FROM public.users WHERE id = v_uid;
  RETURN v_profile;
END $$;
REVOKE ALL ON FUNCTION public.ensure_profile(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_profile(text) TO authenticated;

-- Remove historical self-service inserts that permit forged phone/trust data.
REVOKE INSERT ON public.users FROM anon, authenticated;
