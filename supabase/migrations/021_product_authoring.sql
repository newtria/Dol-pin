-- Product photos are public marketing assets. Return evidence must not use this bucket.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('product-photos', 'product-photos', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY product_photos_read ON storage.objects FOR SELECT
  USING (bucket_id = 'product-photos');
CREATE POLICY product_photos_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'product-photos' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Column privileges preserve ownership and prevent self-assigned verification flags.
REVOKE INSERT, UPDATE ON public.rental_items FROM anon, authenticated;
GRANT INSERT (id, lender_id, concert_id, category, title, description, photos,
  daily_price, currency, deposit, pickup_method, available_from, available_to)
ON public.rental_items TO authenticated;
GRANT UPDATE (concert_id, category, title, description, photos, daily_price,
  deposit, pickup_method, available_from, available_to, status)
ON public.rental_items TO authenticated;

-- Validate new writes without rewriting or silently discarding legacy inventory.
ALTER TABLE public.rental_items ADD CONSTRAINT product_authoring_bounds CHECK (
  length(trim(title)) BETWEEN 2 AND 80 AND coalesce(length(description), 0) <= 2000
  AND category IN ('lightstick', 'phone', 'camera', 'slogan', 'costume', 'etc')
  AND daily_price BETWEEN 100 AND 1000000 AND deposit BETWEEN 0 AND 3000000
  AND cardinality(photos) BETWEEN 1 AND 5
  AND (available_from IS NULL OR available_to IS NULL OR available_to >= available_from)
) NOT VALID;

-- The existing ownership RLS applies to both INSERT and UPDATE. With no granted
-- lender_id UPDATE, ownership cannot be transferred by a client.
