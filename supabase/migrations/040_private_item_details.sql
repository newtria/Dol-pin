-- Existing detailed directions stay in place, but are no longer public columns.
-- Do not copy old free text into pickup_area: it may contain a private address.
ALTER TABLE public.rental_items ADD COLUMN pickup_area text
  CHECK (pickup_area IS NULL OR length(trim(pickup_area)) BETWEEN 2 AND 100);
GRANT INSERT(pickup_area), UPDATE(pickup_area) ON public.rental_items TO authenticated;

REVOKE SELECT ON public.rental_items FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, lender_id, concert_id, category, title, description, photos,
  daily_price, currency, deposit, condition_grade, vlm_tag, bt_verified,
  imei_verified, pickup_method, pickup_area, available_from, available_to,
  status, created_at, updated_at)
ON public.rental_items TO anon, authenticated;

-- Owners can inspect their current instructions. Borrowers receive the frozen
-- instructions through their accepted reservation, never a public item RPC.
CREATE FUNCTION public.own_item_pickup_note(p_item_id uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE note text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  SELECT pickup_note INTO note FROM public.rental_items
    WHERE id = p_item_id AND lender_id = auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Item access denied' USING ERRCODE = '42501';
  END IF;
  RETURN note;
END $$;
REVOKE ALL ON FUNCTION public.own_item_pickup_note(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.own_item_pickup_note(uuid) TO authenticated;
