CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE FUNCTION public.invoke_rental_recovery() RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE endpoint text; token text; request_id bigint;
BEGIN
 SELECT decrypted_secret INTO endpoint FROM vault.decrypted_secrets WHERE name='dolpin_recovery_url';
 SELECT decrypted_secret INTO token FROM vault.decrypted_secrets WHERE name='dolpin_recovery_token';
 IF endpoint IS NULL OR token IS NULL THEN RAISE EXCEPTION 'Configure dolpin_recovery_url and dolpin_recovery_token in Vault'; END IF;
 SELECT net.http_post(url:=endpoint,headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||token),body:='{}'::jsonb,timeout_milliseconds:=60000) INTO request_id;
 RETURN request_id;
END $$;
REVOKE ALL ON FUNCTION public.invoke_rental_recovery() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.invoke_rental_recovery() TO service_role;
SELECT cron.schedule('dolpin-reconcile-rentals','* * * * *','SELECT public.invoke_rental_recovery();');
