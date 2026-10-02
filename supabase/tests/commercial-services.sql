BEGIN;
INSERT INTO public.users(id,nickname,country) VALUES
 ('53000000-0000-4000-8000-000000000001','service lender','KR'),
 ('53000000-0000-4000-8000-000000000002','service borrower','KR'),
 ('53000000-0000-4000-8000-000000000003','service outsider','KR');
INSERT INTO public.policy_consents(user_id,terms_version,privacy_version)
 SELECT id,'2026-09-22','2026-09-22' FROM public.users WHERE id IN
 ('53000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000002');
INSERT INTO public.rental_items(id,lender_id,title,category,photos,daily_price,deposit,currency,pickup_method)
 VALUES('54000000-0000-4000-8000-000000000001','53000000-0000-4000-8000-000000000001','service fixture','lightstick',
 ARRAY['https://example.invalid/legacy-fixture.png'],1000,10000,'KRW','direct');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','53000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE rental public.reservations; first public.chat_messages; replay public.chat_messages; forbidden boolean:=false;
BEGIN
 rental:=public.request_rental('54000000-0000-4000-8000-000000000001',now()+interval '3 days',now()+interval '4 days',
 (SELECT updated_at FROM public.rental_items WHERE id='54000000-0000-4000-8000-000000000001'),'55000000-0000-4000-8000-000000000001');
 first:=public.send_rental_message(rental.id,'거래 일정 문의입니다.','55000000-0000-4000-8000-000000000002');
 replay:=public.send_rental_message(rental.id,'거래 일정 문의입니다.','55000000-0000-4000-8000-000000000002');
 IF first.id<>replay.id THEN RAISE EXCEPTION 'retry duplicated message'; END IF;
 BEGIN
  PERFORM public.enqueue_notification(auth.uid(),'fake','fake','fake',rental.id);
 EXCEPTION WHEN insufficient_privilege THEN forbidden:=true;
 END;
 IF NOT forbidden THEN RAISE EXCEPTION 'client may forge server push'; END IF;
 forbidden:=false;
 BEGIN
  UPDATE public.users SET nickname='direct write' WHERE id=auth.uid();
 EXCEPTION WHEN insufficient_privilege THEN forbidden:=true;
 END;
 IF NOT forbidden THEN RAISE EXCEPTION 'profile direct write allowed'; END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','53000000-0000-4000-8000-000000000001',true);
DO $$
DECLARE rental_id uuid; messages_count integer;
BEGIN
 SELECT id INTO rental_id FROM public.reservations WHERE item_id='54000000-0000-4000-8000-000000000001';
 PERFORM public.mark_rental_messages_read(rental_id);
 SELECT count(*) INTO messages_count FROM public.chat_messages WHERE reservation_id=rental_id AND read_at IS NOT NULL;
 IF messages_count<>1 THEN RAISE EXCEPTION 'message receipt not recorded'; END IF;
 PERFORM public.set_user_block('53000000-0000-4000-8000-000000000002',true);
 PERFORM public.set_my_item_status('54000000-0000-4000-8000-000000000001','hidden');
END $$;

SELECT set_config('request.jwt.claim.sub','53000000-0000-4000-8000-000000000002',true);
DO $$
DECLARE forbidden boolean:=false; rental_id uuid;
BEGIN
 SELECT id INTO rental_id FROM public.reservations WHERE item_id='54000000-0000-4000-8000-000000000001';
 BEGIN
  PERFORM public.send_rental_message(rental_id,'blocked message','55000000-0000-4000-8000-000000000003');
 EXCEPTION WHEN insufficient_privilege THEN forbidden:=true;
 END;
 IF NOT forbidden THEN RAISE EXCEPTION 'blocked participant sent message'; END IF;
 IF EXISTS(SELECT 1 FROM public.rental_items WHERE id='54000000-0000-4000-8000-000000000001') THEN RAISE EXCEPTION 'hidden item publicly visible'; END IF;
END $$;

RESET ROLE;
SELECT set_config('request.jwt.claim.role','service_role',true);
DO $$
DECLARE blocked boolean:=false;
BEGIN
 BEGIN
  PERFORM public.begin_account_closure('53000000-0000-4000-8000-000000000002');
 EXCEPTION WHEN SQLSTATE 'PCL01' THEN blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'active rental allowed closure'; END IF;
 PERFORM public.begin_account_closure('53000000-0000-4000-8000-000000000003');
 PERFORM public.begin_account_closure('53000000-0000-4000-8000-000000000003');
 IF (SELECT count(*) FROM public.account_closures WHERE user_id='53000000-0000-4000-8000-000000000003')<>1 THEN RAISE EXCEPTION 'duplicate closure'; END IF;
 IF EXISTS(SELECT 1 FROM public.users WHERE id='53000000-0000-4000-8000-000000000003' AND (deleted_at IS NULL OR nickname<>'탈퇴한 사용자')) THEN RAISE EXCEPTION 'profile not anonymized'; END IF;
END $$;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.role','authenticated',true);
SELECT set_config('request.jwt.claim.sub','53000000-0000-4000-8000-000000000003',true);
DO $$
DECLARE blocked boolean:=false;
BEGIN
 BEGIN PERFORM public.require_open_session(); EXCEPTION WHEN insufficient_privilege THEN blocked:=true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'stale closed JWT bypassed request guard'; END IF;
END $$;
ROLLBACK;
