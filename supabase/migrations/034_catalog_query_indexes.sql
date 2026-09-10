-- Preserve substring search semantics; index selective searches of 3+ characters.
-- One/two-character and very common searches can still use the ordered index.
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;
CREATE INDEX rental_items_active_title_search ON public.rental_items
 USING gin (title extensions.gin_trgm_ops) WHERE status='active';
CREATE INDEX rental_items_active_order ON public.rental_items(created_at DESC,id DESC) WHERE status='active';
CREATE INDEX rental_items_active_category_order ON public.rental_items(category,created_at DESC,id DESC) WHERE status='active';
CREATE INDEX rental_items_active_concert_order ON public.rental_items(concert_id,created_at DESC,id DESC) WHERE status='active';
CREATE INDEX reservations_borrower_order ON public.reservations(borrower_id,created_at DESC,id DESC);
CREATE INDEX reservations_lender_order ON public.reservations(lender_id,created_at DESC,id DESC);
