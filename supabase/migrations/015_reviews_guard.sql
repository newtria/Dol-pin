-- Gate review creation so it can only happen after a reservation is
-- actually complete. Prior policy (`005_reviews.sql`) only checked
-- `reviewer_id = auth.uid()`, which allowed fabricating reviews for
-- reservations the user never participated in and for reservations that
-- were still pending / cancelled.
--
-- New rules:
--   1. The reviewer must be the authenticated caller.
--   2. The referenced reservation must have status = 'returned'.
--   3. The caller must be a participant (borrower or lender) of that
--      reservation.
--   4. The reviewee must be the *other* participant of that reservation
--      (can't review yourself).

DROP POLICY IF EXISTS "Users can create reviews" ON reviews;

CREATE POLICY "Users can create reviews for completed reservations"
  ON reviews FOR INSERT
  WITH CHECK (
    reviewer_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM reservations r
      WHERE r.id = reviews.reservation_id
        AND r.status = 'returned'
        AND (r.borrower_id = auth.uid() OR r.lender_id = auth.uid())
        AND reviews.reviewee_id IN (r.borrower_id, r.lender_id)
        AND reviews.reviewee_id <> auth.uid()
    )
  );
