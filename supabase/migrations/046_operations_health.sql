-- Read-only watchdog snapshot. Runs outside the workers it monitors.
CREATE INDEX service_dispatches_recent ON public.service_dispatches(created_at DESC) INCLUDE(request_id);
CREATE INDEX rental_recovery_dispatches_recent ON public.rental_recovery_dispatches(created_at DESC) INCLUDE(request_id);
ALTER TABLE public.service_alert_state ADD COLUMN last_failed_at timestamptz;

CREATE OR REPLACE FUNCTION public.claim_service_alert(p_signature text,p_lease uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_signature IS NULL OR length(p_signature)>128 OR p_lease IS NULL THEN RAISE EXCEPTION 'Invalid alert claim'; END IF;
 UPDATE public.service_alert_state SET pending_signature=p_signature,lease_token=p_lease,lease_until=clock_timestamp()+interval '1 minute'
 WHERE id AND (lease_until IS NULL OR lease_until<=clock_timestamp()) AND next_attempt_at<=clock_timestamp()
 AND (last_failed_at IS NOT NULL OR last_signature IS DISTINCT FROM p_signature OR last_sent_at<clock_timestamp()-interval '24 hours');
 RETURN FOUND;
END $$;

-- A worker has a 50-second budget under pg_net's 60-second request timeout.
-- Claim a single concurrent wave, leaving unstarted work available next minute.
CREATE OR REPLACE FUNCTION public.claim_notification_deliveries(p_lease uuid) RETURNS SETOF public.notification_deliveries
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_lease IS NULL THEN RAISE EXCEPTION 'Delivery lease is required' USING ERRCODE='22023'; END IF;
 UPDATE public.notification_deliveries SET status='review',last_code='SEND_OUTCOME_UNKNOWN',lease_token=NULL,lease_until=NULL
 WHERE status='sending' AND lease_until<=clock_timestamp();
 RETURN QUERY WITH due AS (
  SELECT id FROM public.notification_deliveries WHERE status IN ('pending','receipt') AND next_attempt_at<=clock_timestamp()
  AND (lease_until IS NULL OR lease_until<=clock_timestamp()) ORDER BY next_attempt_at,id FOR UPDATE SKIP LOCKED LIMIT 10
 ) UPDATE public.notification_deliveries d SET lease_token=p_lease,lease_until=clock_timestamp()+interval '3 minutes',attempt_count=attempt_count+1,
 status=CASE WHEN status='pending' THEN 'sending' ELSE status END FROM due WHERE d.id=due.id RETURNING d.*;
END $$;

CREATE OR REPLACE FUNCTION public.finish_service_alert(p_lease uuid,p_success boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.service_alert_state SET last_signature=CASE WHEN p_success THEN pending_signature ELSE last_signature END,
 last_sent_at=CASE WHEN p_success THEN clock_timestamp() ELSE last_sent_at END,
 last_failed_at=CASE WHEN p_success THEN NULL ELSE clock_timestamp() END,
 lease_token=NULL,lease_until=NULL,
 next_attempt_at=clock_timestamp()+CASE WHEN p_success THEN interval '5 minutes' ELSE interval '1 hour' END
 WHERE id AND lease_token=p_lease AND lease_until>clock_timestamp();
END $$;

CREATE FUNCTION public.operations_health() RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object(
  'observedAt',clock_timestamp(),
  'services',public.service_health() || jsonb_build_object(
   'stalledClosures',(SELECT count(*) FROM public.account_closures WHERE auth_deleted_at IS NULL AND requested_at<clock_timestamp()-interval '1 hour'),
   'stalledNotifications',(SELECT count(*) FROM public.notification_deliveries WHERE status IN ('pending','receipt','sending') AND next_attempt_at<clock_timestamp()-interval '15 minutes'),
   'alertDeliveryFailures',(SELECT count(*) FROM public.service_alert_state WHERE last_failed_at IS NOT NULL)
  ),
  'workers',jsonb_build_object(
   'delivery',jsonb_build_object(
    'lastSuccessAt',(SELECT d.created_at FROM public.service_dispatches d JOIN net._http_response r ON r.id=d.request_id WHERE r.status_code=200 AND NOT coalesce(r.timed_out,false) ORDER BY d.created_at DESC LIMIT 1),
    'lastCompleted',(SELECT jsonb_build_object('at',d.created_at,'status',r.status_code,'timedOut',r.timed_out) FROM public.service_dispatches d JOIN net._http_response r ON r.id=d.request_id ORDER BY d.created_at DESC LIMIT 1)
   ),
   'payments',jsonb_build_object(
    'lastSuccessAt',(SELECT d.created_at FROM public.rental_recovery_dispatches d JOIN net._http_response r ON r.id=d.request_id WHERE r.status_code=200 AND NOT coalesce(r.timed_out,false) ORDER BY d.created_at DESC LIMIT 1),
    'lastCompleted',(SELECT jsonb_build_object('at',d.created_at,'status',r.status_code,'timedOut',r.timed_out) FROM public.rental_recovery_dispatches d JOIN net._http_response r ON r.id=d.request_id ORDER BY d.created_at DESC LIMIT 1)
   )
  )
 )
$$;
REVOKE ALL ON FUNCTION public.operations_health() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.operations_health() TO service_role;
