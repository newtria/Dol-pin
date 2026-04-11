-- Widen the "public profile" SELECT policy so chat counterparties are
-- visible even when neither side is a lender yet.
--
-- Prior behaviour: `is_lender = TRUE` was a hard filter, so a borrower
-- talking to another borrower — or a fresh account that never listed an
-- item — appeared as NULL in the chat list (missing nickname, avatar).
-- This migration broadens the policy to ALSO allow reading a user row
-- when the caller shares any reservation with that user, matching the
-- scope of the app's chat feature.

DROP POLICY IF EXISTS "Public can read active user profiles" ON users;

CREATE POLICY "Public can read active lenders and reservation partners"
  ON users FOR SELECT
  USING (
    deleted_at IS NULL
    AND (
      is_lender = TRUE
      OR EXISTS (
        SELECT 1
        FROM reservations r
        WHERE (r.lender_id = users.id AND r.borrower_id = auth.uid())
           OR (r.borrower_id = users.id AND r.lender_id = auth.uid())
      )
    )
  );
