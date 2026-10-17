-- Public discovery applies availability before the page boundary. The explicit
-- return shape never grants access to private pickup instructions or device IDs.
CREATE FUNCTION public.search_rental_items(
 p_concert_id uuid DEFAULT NULL, p_category text DEFAULT NULL, p_search text DEFAULT NULL,
 p_pickup_area text DEFAULT NULL, p_starts_at timestamptz DEFAULT NULL, p_ends_at timestamptz DEFAULT NULL,
 p_before_created_at timestamptz DEFAULT NULL, p_before_id uuid DEFAULT NULL
) RETURNS TABLE (
 id uuid, lender_id uuid, concert_id uuid, category text, title text, description text,
 photos text[], daily_price integer, currency text, deposit integer, condition_grade text,
 vlm_tag text, bt_verified boolean, imei_verified boolean, pickup_method text, pickup_area text,
 available_from date, available_to date, status text, created_at timestamptz, updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE
 title_pattern text := '%' || replace(replace(replace(trim(p_search),chr(92),chr(92)||chr(92)),'%',chr(92)||'%'),'_',chr(92)||'_') || '%';
 area_pattern text := '%' || replace(replace(replace(trim(p_pickup_area),chr(92),chr(92)||chr(92)),'%',chr(92)||'%'),'_',chr(92)||'_') || '%';
BEGIN
 IF (p_starts_at IS NULL) <> (p_ends_at IS NULL)
 OR (p_starts_at IS NOT NULL AND (NOT isfinite(p_starts_at) OR NOT isfinite(p_ends_at)
   OR p_starts_at<=now() OR p_ends_at<=p_starts_at)) THEN
  RAISE EXCEPTION '대여 시작과 반납 시간을 확인해 주세요.' USING ERRCODE='22023';
 END IF;
 IF (p_before_created_at IS NULL) <> (p_before_id IS NULL)
 OR length(p_search)>200 OR length(p_pickup_area)>100 OR length(p_category)>40 THEN
  RAISE EXCEPTION '검색 조건을 확인해 주세요.' USING ERRCODE='22023';
 END IF;
 RETURN QUERY SELECT
  i.id,i.lender_id,i.concert_id,i.category,i.title,i.description,i.photos,i.daily_price,i.currency,
  i.deposit,i.condition_grade,i.vlm_tag,i.bt_verified,i.imei_verified,i.pickup_method,i.pickup_area,
  i.available_from,i.available_to,i.status,i.created_at,i.updated_at
 FROM public.rental_items i
 WHERE i.status='active' AND i.moderated_at IS NULL AND public.account_is_active(i.lender_id)
  AND (p_concert_id IS NULL OR i.concert_id=p_concert_id)
  AND (nullif(trim(p_category),'') IS NULL OR i.category=trim(p_category))
  AND (nullif(trim(p_search),'') IS NULL OR i.title ILIKE title_pattern)
  AND (nullif(trim(p_pickup_area),'') IS NULL OR i.pickup_area ILIKE area_pattern)
  AND (p_before_id IS NULL OR (coalesce(i.created_at,'-infinity'::timestamptz),i.id)<(p_before_created_at,p_before_id))
  AND (p_starts_at IS NULL OR (
   (i.available_from IS NULL OR (p_starts_at AT TIME ZONE 'Asia/Seoul')::date>=i.available_from)
   AND (i.available_to IS NULL OR (p_ends_at AT TIME ZONE 'Asia/Seoul')::date<=i.available_to)
   AND NOT EXISTS (
    SELECT 1 FROM public.reservations r WHERE r.item_id=i.id
     -- Match the inventory exclusion constraint. An accepted reservation still
     -- blocks after its deadline until the server safely completes expiry; a
     -- checkout may already have charged the borrower and await reconciliation.
     AND r.status IN ('pending','accepted','paid','picked_up','returned','disputed')
     AND tstzrange(coalesce(r.starts_at,r.rental_date::timestamp AT TIME ZONE 'Asia/Seoul'),
      coalesce(r.ends_at,r.return_date::timestamp AT TIME ZONE 'Asia/Seoul'),'[)')
      && tstzrange(p_starts_at,p_ends_at,'[)')
   )
  ))
 ORDER BY i.created_at DESC NULLS LAST,i.id DESC LIMIT 51;
END $$;
REVOKE ALL ON FUNCTION public.search_rental_items(uuid,text,text,text,timestamptz,timestamptz,timestamptz,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_rental_items(uuid,text,text,text,timestamptz,timestamptz,timestamptz,uuid) TO anon,authenticated,service_role;

CREATE INDEX rental_items_active_area_search ON public.rental_items
 USING gin (pickup_area extensions.gin_trgm_ops) WHERE status='active' AND moderated_at IS NULL;
