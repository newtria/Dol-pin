-- Service reads must work on installations without permissive default grants.
-- Existing row policies limit messages to room participants and reports to their reporter.
GRANT SELECT ON public.chat_messages, public.reports TO authenticated;
GRANT SELECT ON public.reports TO service_role;

-- Message commands use an empty search path. Their nested trigger must resolve
-- the room table independently of the caller's function settings.
CREATE OR REPLACE FUNCTION public.update_chat_room_last_message()
RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.room_id IS NOT NULL THEN
    UPDATE public.chat_rooms
       SET last_message = coalesce(NEW.message, '[image]'),
           last_message_at = coalesce(NEW.created_at, now())
     WHERE id = NEW.room_id;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.update_chat_room_last_message() FROM PUBLIC, anon, authenticated;

-- Attaching a photo locks its Storage row but does not update that row. A
-- candidate scan may therefore miss an attachment committed before the lock
-- is acquired. Recheck references after locking, using a fresh query snapshot.
CREATE OR REPLACE FUNCTION public.claim_orphan_product_photos() RETURNS SETOF text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE object record;
BEGIN
  FOR object IN
    SELECT o.name FROM storage.objects o
    WHERE o.bucket_id='product-photos' AND o.created_at<clock_timestamp()-interval '24 hours'
      AND NOT EXISTS(SELECT 1 FROM public.product_photo_deletions d WHERE d.path=o.name)
      AND NOT EXISTS(SELECT 1 FROM public.rental_items i,unnest(i.photos) p
        WHERE split_part(p,'/storage/v1/object/public/product-photos/',2)=o.name)
      AND NOT EXISTS(SELECT 1 FROM public.reservations r,
        jsonb_array_elements_text(CASE WHEN jsonb_typeof(r.terms_snapshot->'photos')='array'
          THEN r.terms_snapshot->'photos' ELSE '[]'::jsonb END) p
        WHERE split_part(p,'/storage/v1/object/public/product-photos/',2)=o.name)
    ORDER BY o.created_at LIMIT 50 FOR UPDATE OF o SKIP LOCKED
  LOOP
    IF EXISTS(SELECT 1 FROM public.rental_items i,unnest(i.photos) p
      WHERE split_part(p,'/storage/v1/object/public/product-photos/',2)=object.name)
      OR EXISTS(SELECT 1 FROM public.reservations r,
        jsonb_array_elements_text(CASE WHEN jsonb_typeof(r.terms_snapshot->'photos')='array'
          THEN r.terms_snapshot->'photos' ELSE '[]'::jsonb END) p
        WHERE split_part(p,'/storage/v1/object/public/product-photos/',2)=object.name) THEN
      CONTINUE;
    END IF;
    INSERT INTO public.product_photo_deletions(path) VALUES(object.name) ON CONFLICT DO NOTHING;
  END LOOP;
  RETURN QUERY UPDATE public.product_photo_deletions SET attempts=attempts+1,last_attempt_at=clock_timestamp()
    WHERE path IN(SELECT path FROM public.product_photo_deletions
      WHERE deleted_at IS NULL AND (last_attempt_at IS NULL OR last_attempt_at<clock_timestamp()-interval '1 hour')
      ORDER BY claimed_at LIMIT 50)
    RETURNING path;
END $$;
