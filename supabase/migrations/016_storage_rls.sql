-- Row-level security for Supabase Storage buckets used by the app.
--
-- Without these policies, anyone with the anon key could write arbitrary
-- paths to the public buckets (e.g. write to `items/<another_user>/…`
-- because the client code constructs the path from a client-provided
-- userId). The policies below enforce that:
--
--   * rental-photos:  only owner can write under `items/<auth.uid()>/...`;
--                     borrowers can write return evidence under
--                     `returns/<reservation_id>/<auth.uid()>/...`; public read
--                     matches storage.upload.getPublicUrl.
--   * profile-photos: only owner can write `profiles/<auth.uid()>...`
--                     public read.
--   * chat-images:    authenticated users can read/write under
--                     `chat/<room_id>/...` where they participate in the
--                     room. Room membership is verified via chat_rooms.
--
-- Run once via `supabase db push`. Buckets must already exist with
-- `public = true` for the read policies to make the public URL work.
--
-- NOTE: CREATE POLICY on storage.objects is idempotent via IF NOT EXISTS
-- in Supabase's platform wrapper. If running against bare PostgREST,
-- drop-and-recreate before applying.

-- ---------------------------------------------------------------------------
-- rental-photos:
--   items/<user_id>/<epoch>.<ext>
--   returns/<reservation_id>/<borrower_id>/<epoch>.<ext>
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "rental_photos_read" ON storage.objects;
CREATE POLICY "rental_photos_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'rental-photos');

DROP POLICY IF EXISTS "rental_photos_insert_own" ON storage.objects;
CREATE POLICY "rental_photos_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'rental-photos'
    AND (
      (
        (storage.foldername(name))[1] = 'items'
        AND (storage.foldername(name))[2] = auth.uid()::text
      )
      OR (
        (storage.foldername(name))[1] = 'returns'
        AND (storage.foldername(name))[3] = auth.uid()::text
        AND EXISTS (
          SELECT 1 FROM reservations r
          WHERE r.id::text = (storage.foldername(name))[2]
            AND r.borrower_id = auth.uid()
            AND r.status = 'picked_up'
        )
      )
    )
  );

DROP POLICY IF EXISTS "rental_photos_update_own" ON storage.objects;
CREATE POLICY "rental_photos_update_own"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'rental-photos'
    AND (
      (
        (storage.foldername(name))[1] = 'items'
        AND (storage.foldername(name))[2] = auth.uid()::text
      )
      OR (
        (storage.foldername(name))[1] = 'returns'
        AND (storage.foldername(name))[3] = auth.uid()::text
        AND EXISTS (
          SELECT 1 FROM reservations r
          WHERE r.id::text = (storage.foldername(name))[2]
            AND r.borrower_id = auth.uid()
            AND r.status = 'picked_up'
        )
      )
    )
  );

DROP POLICY IF EXISTS "rental_photos_delete_own" ON storage.objects;
CREATE POLICY "rental_photos_delete_own"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'rental-photos'
    AND (
      (
        (storage.foldername(name))[1] = 'items'
        AND (storage.foldername(name))[2] = auth.uid()::text
      )
      OR (
        (storage.foldername(name))[1] = 'returns'
        AND (storage.foldername(name))[3] = auth.uid()::text
        AND EXISTS (
          SELECT 1 FROM reservations r
          WHERE r.id::text = (storage.foldername(name))[2]
            AND r.borrower_id = auth.uid()
            AND r.status = 'picked_up'
        )
      )
    )
  );

-- ---------------------------------------------------------------------------
-- profile-photos: profiles/<user_id>.<ext>
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "profile_photos_read" ON storage.objects;
CREATE POLICY "profile_photos_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'profile-photos');

DROP POLICY IF EXISTS "profile_photos_write_own" ON storage.objects;
CREATE POLICY "profile_photos_write_own"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'profile-photos'
    AND (storage.foldername(name))[1] = 'profiles'
    AND split_part(name, '/', 2) LIKE auth.uid()::text || '%'
  );

DROP POLICY IF EXISTS "profile_photos_update_own" ON storage.objects;
CREATE POLICY "profile_photos_update_own"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'profile-photos'
    AND (storage.foldername(name))[1] = 'profiles'
    AND split_part(name, '/', 2) LIKE auth.uid()::text || '%'
  );

-- ---------------------------------------------------------------------------
-- chat-images: chat/<chat_id>/<epoch>.<ext>
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "chat_images_read_participants" ON storage.objects;
CREATE POLICY "chat_images_read_participants"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'chat-images'
    AND (storage.foldername(name))[1] = 'chat'
    AND EXISTS (
      SELECT 1 FROM chat_rooms cr
      WHERE cr.id::text = (storage.foldername(name))[2]
        AND (cr.participant_1 = auth.uid() OR cr.participant_2 = auth.uid())
    )
  );

DROP POLICY IF EXISTS "chat_images_write_participants" ON storage.objects;
CREATE POLICY "chat_images_write_participants"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'chat-images'
    AND (storage.foldername(name))[1] = 'chat'
    AND EXISTS (
      SELECT 1 FROM chat_rooms cr
      WHERE cr.id::text = (storage.foldername(name))[2]
        AND (cr.participant_1 = auth.uid() OR cr.participant_2 = auth.uid())
    )
  );
