BEGIN;
-- Simulate Auth's trusted confirmation result; this is not proof of a real
-- Google/Apple redirect or token exchange, which needs configured providers.
INSERT INTO auth.users(id,email,email_confirmed_at,is_anonymous) VALUES
 ('12000000-0000-4000-8000-000000000001','oauth-fixture@example.invalid',now(),false),
 ('12000000-0000-4000-8000-000000000002','unverified-fixture@example.invalid',NULL,false);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','12000000-0000-4000-8000-000000000001',true);
DO $$ DECLARE profile public.users%ROWTYPE; BEGIN
 profile:=public.ensure_profile('OAuth fixture');
 IF profile.id <> auth.uid() OR profile.phone IS NOT NULL OR profile.identity_verified IS DISTINCT FROM false THEN
   RAISE EXCEPTION 'OAuth profile fabricated a phone or identity verification';
 END IF;
 UPDATE public.users SET nickname='OAuth renamed' WHERE id=auth.uid();
 BEGIN
  UPDATE public.users SET phone='forged-phone' WHERE id=auth.uid();
  RAISE EXCEPTION 'client forged phone';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 IF (public.ensure_profile('Retry fixture')).id <> profile.id THEN RAISE EXCEPTION 'profile retry duplicated identity'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','12000000-0000-4000-8000-000000000002',true);
DO $$ BEGIN
 BEGIN
  PERFORM public.ensure_profile('Unverified fixture');
  RAISE EXCEPTION 'unverified Auth account created a profile';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
ROLLBACK;
SELECT 'verified Auth profile accepts absent phone without marking identity verified' AS result;
