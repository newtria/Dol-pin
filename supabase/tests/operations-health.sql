BEGIN;
DO $$
BEGIN
 IF has_function_privilege('anon','public.operations_health()','EXECUTE')
 OR has_function_privilege('authenticated','public.operations_health()','EXECUTE') THEN
  RAISE EXCEPTION 'Operations health must not expose internal queues to client roles';
 END IF;
 IF NOT has_function_privilege('service_role','public.operations_health()','EXECUTE') THEN
  RAISE EXCEPTION 'External watchdog cannot query operations health';
 END IF;
END $$;
INSERT INTO public.users(id,nickname,country) VALUES('63000000-0000-4000-8000-000000000010','watchdog fixture','KR');
INSERT INTO public.push_tokens(token,user_id) VALUES('ExpoPushToken[watchdogclaimfixture000000]','63000000-0000-4000-8000-000000000010');
INSERT INTO public.notifications(user_id,event_key,kind,title,body)
 SELECT '63000000-0000-4000-8000-000000000010','watchdog-claim-'||n::text,'reminder','dol-pin','fixture'
 FROM generate_series(1,20) n;
INSERT INTO public.notification_deliveries(notification_id,token)
 SELECT id,'ExpoPushToken[watchdogclaimfixture000000]' FROM public.notifications WHERE user_id='63000000-0000-4000-8000-000000000010';
UPDATE public.service_alert_state SET lease_token='63000000-0000-4000-8000-000000000001',lease_until=clock_timestamp()+interval '1 minute';
SET LOCAL ROLE service_role;
DO $$
DECLARE claimed integer;
BEGIN
 SELECT count(*) INTO claimed FROM public.claim_notification_deliveries('63000000-0000-4000-8000-000000000003');
 IF claimed<>10 THEN RAISE EXCEPTION 'Delivery claimed more work than one bounded wave'; END IF;
 IF (SELECT count(*) FROM public.notification_deliveries WHERE token='ExpoPushToken[watchdogclaimfixture000000]' AND lease_token IS NULL)<10
 THEN RAISE EXCEPTION 'Later waves were claimed before they could start'; END IF;
 DELETE FROM public.push_tokens WHERE token='ExpoPushToken[watchdogclaimfixture000000]';
 IF EXISTS(SELECT 1 FROM public.notification_deliveries WHERE token='ExpoPushToken[watchdogclaimfixture000000]')
 THEN RAISE EXCEPTION 'Invalid device token left orphan deliveries'; END IF;
END $$;
SELECT public.operations_health();
SELECT public.finish_service_alert('63000000-0000-4000-8000-000000000001',false);
DO $$
BEGIN
 IF (public.operations_health()->'services'->>'alertDeliveryFailures')::integer<>1 THEN
  RAISE EXCEPTION 'External watchdog lost a failed alert after the worker returned';
 END IF;
END $$;
RESET ROLE;
-- The backlog may return to its previously successful signature before retry.
-- A failed delivery must still retry without waiting for the daily reminder.
UPDATE public.service_alert_state SET last_signature='unchanged',last_sent_at=clock_timestamp(),next_attempt_at=clock_timestamp()-interval '1 second';
SET LOCAL ROLE service_role;
DO $$
BEGIN
 IF NOT public.claim_service_alert('unchanged','63000000-0000-4000-8000-000000000002') THEN
  RAISE EXCEPTION 'An unchanged snapshot stranded a failed alert';
 END IF;
END $$;
SELECT public.finish_service_alert('63000000-0000-4000-8000-000000000002',true);
DO $$
BEGIN
 IF (public.operations_health()->'services'->>'alertDeliveryFailures')::integer<>0 THEN
  RAISE EXCEPTION 'Successful alert did not clear the watchdog failure';
 END IF;
END $$;
ROLLBACK;
