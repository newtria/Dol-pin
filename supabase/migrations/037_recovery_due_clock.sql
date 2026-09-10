-- Evaluate scheduling against the DB clock that wrote next_attempt_at, rather
-- than the Edge host clock (including hosts waking from sleep).
CREATE VIEW public.rental_recovery_due AS
 SELECT * FROM public.rental_recovery_queue
 WHERE review_required_at IS NULL AND next_attempt_at<=now();
REVOKE ALL ON public.rental_recovery_due FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.rental_recovery_due TO service_role;
