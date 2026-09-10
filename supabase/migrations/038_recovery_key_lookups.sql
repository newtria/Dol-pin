-- Keep recovery writes as indexed point lookups as the ledger grows.
CREATE OR REPLACE FUNCTION public.record_rental_recovery_attempt(
 p_kind text,p_key text,p_lease uuid,p_code text,p_review boolean DEFAULT false,p_failed boolean DEFAULT true
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE target text; key_column text; key_type text;
BEGIN
 IF p_kind IS NULL OR p_kind NOT IN ('checkout','money') OR p_code IS NULL OR p_code !~ '^[A-Z_]{1,48}$'
 THEN RAISE EXCEPTION 'Invalid recovery result' USING ERRCODE='22023'; END IF;
 target:=CASE p_kind WHEN 'checkout' THEN 'toss_checkouts' ELSE 'rental_money_operations' END;
 key_column:=CASE p_kind WHEN 'checkout' THEN 'order_id' ELSE 'id' END;
 key_type:=CASE p_kind WHEN 'checkout' THEN 'text' ELSE 'uuid' END;
 EXECUTE format('UPDATE public.%I SET
  failure_count=failure_count+CASE WHEN $4 THEN 1 ELSE 0 END,
  last_error_code=$1,last_error_at=clock_timestamp(),
  review_required_at=CASE WHEN $2 OR ($4 AND failure_count+1>=8) THEN coalesce(review_required_at,clock_timestamp()) ELSE review_required_at END,
  next_attempt_at=clock_timestamp()+make_interval(secs=>CASE WHEN $4 THEN least(3600,30*power(2,least(failure_count,7)))::integer ELSE 60 END)
  WHERE %I=$3::%s AND lease_token=$5',target,key_column,key_type)
 USING p_code,p_review,p_key,p_failed,p_lease;
END $$;
CREATE OR REPLACE FUNCTION public.retry_rental_recovery(p_kind text,p_key text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_kind='money' THEN
  UPDATE public.rental_money_operations SET review_required_at=NULL,failure_count=0,next_attempt_at=clock_timestamp()
  WHERE id=p_key::uuid AND status='pending' AND (lease_until IS NULL OR lease_until<=clock_timestamp());
 ELSIF p_kind='checkout' THEN
  UPDATE public.toss_checkouts c SET review_required_at=NULL,failure_count=0,next_attempt_at=clock_timestamp()
  WHERE order_id=p_key AND (lease_until IS NULL OR lease_until<=clock_timestamp())
   AND EXISTS(SELECT 1 FROM public.reservations r WHERE r.id=c.reservation_id AND r.status='accepted');
 ELSE RAISE EXCEPTION 'Invalid recovery kind' USING ERRCODE='22023'; END IF;
 RETURN FOUND;
END $$;
