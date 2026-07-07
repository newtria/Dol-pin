-- Chat rooms table for proper conversation management
CREATE TABLE IF NOT EXISTS chat_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_1 UUID NOT NULL REFERENCES users(id),
  participant_2 UUID NOT NULL REFERENCES users(id),
  item_id UUID REFERENCES rental_items(id),
  reservation_id UUID REFERENCES reservations(id),
  last_message TEXT,
  last_message_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Add room_id to chat_messages
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES chat_rooms(id);

-- Old versions had a table-level UNIQUE(participant_1, participant_2, item_id).
-- Reservation-scoped rooms must allow repeat rentals of the same item between
-- the same pair, so keep only partial uniqueness for non-reservation rooms.
ALTER TABLE chat_rooms
  DROP CONSTRAINT IF EXISTS chat_rooms_participant_1_participant_2_item_id_key;

-- Create index for fast room lookups
CREATE INDEX IF NOT EXISTS idx_chat_rooms_participants
  ON chat_rooms(participant_1, participant_2);
CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_rooms_reservation
  ON chat_rooms(reservation_id)
  WHERE reservation_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_rooms_item_thread
  ON chat_rooms(participant_1, participant_2, item_id)
  WHERE reservation_id IS NULL AND item_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_chat_messages_room
  ON chat_messages(room_id, created_at DESC);

-- RLS for chat_rooms
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own rooms" ON chat_rooms;
CREATE POLICY "Users can view their own rooms" ON chat_rooms
  FOR SELECT USING (
    auth.uid() = participant_1 OR auth.uid() = participant_2
  );

DROP POLICY IF EXISTS "Users can create rooms" ON chat_rooms;
CREATE POLICY "Users can create rooms" ON chat_rooms
  FOR INSERT WITH CHECK (false);

-- Function to get or create a chat room
CREATE OR REPLACE FUNCTION get_or_create_room(
  user_a UUID,
  user_b UUID,
  p_item_id UUID DEFAULT NULL,
  p_reservation_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  room_id UUID;
  p1 UUID;
  p2 UUID;
  v_uid UUID;
  v_role TEXT;
  v_reservation reservations%ROWTYPE;
  v_item rental_items%ROWTYPE;
  v_item_id UUID;
BEGIN
  v_uid := auth.uid();
  v_role := current_setting('role', true);

  IF user_a IS NULL OR user_b IS NULL THEN
    RAISE EXCEPTION 'user_a and user_b are required';
  END IF;

  IF user_a = user_b THEN
    RAISE EXCEPTION 'cannot create a room with yourself';
  END IF;

  IF v_role <> 'service_role'
     AND (v_uid IS NULL OR (v_uid <> user_a AND v_uid <> user_b)) THEN
    RAISE EXCEPTION 'not authorized to create this room';
  END IF;

  IF p_reservation_id IS NOT NULL THEN
    SELECT * INTO v_reservation
      FROM reservations
     WHERE id = p_reservation_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'reservation not found';
    END IF;

    IF p_item_id IS NOT NULL AND p_item_id <> v_reservation.item_id THEN
      RAISE EXCEPTION 'reservation item mismatch';
    END IF;

    IF NOT (
      (user_a = v_reservation.borrower_id AND user_b = v_reservation.lender_id)
      OR
      (user_a = v_reservation.lender_id AND user_b = v_reservation.borrower_id)
    ) THEN
      RAISE EXCEPTION 'reservation participants mismatch';
    END IF;

    IF v_role <> 'service_role'
       AND v_uid NOT IN (v_reservation.borrower_id, v_reservation.lender_id) THEN
      RAISE EXCEPTION 'not a reservation participant';
    END IF;

    user_a := v_reservation.borrower_id;
    user_b := v_reservation.lender_id;
    v_item_id := v_reservation.item_id;
  ELSE
    IF p_item_id IS NULL THEN
      RAISE EXCEPTION 'p_item_id is required for non-reservation rooms';
    END IF;
    SELECT * INTO v_item
      FROM rental_items
     WHERE id = p_item_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'item not found';
    END IF;

    IF v_item.status <> 'active' THEN
      RAISE EXCEPTION 'item is not active';
    END IF;

    IF v_item.lender_id NOT IN (user_a, user_b) THEN
      RAISE EXCEPTION 'item lender must participate in the room';
    END IF;

    v_item_id := p_item_id;
  END IF;

  -- Normalize participant order
  IF user_a < user_b THEN
    p1 := user_a; p2 := user_b;
  ELSE
    p1 := user_b; p2 := user_a;
  END IF;

  IF p_reservation_id IS NOT NULL THEN
    INSERT INTO chat_rooms (participant_1, participant_2, item_id, reservation_id)
    VALUES (p1, p2, v_item_id, p_reservation_id)
    ON CONFLICT (reservation_id) WHERE reservation_id IS NOT NULL
    DO UPDATE SET reservation_id = EXCLUDED.reservation_id
    RETURNING id INTO room_id;
  ELSE
    INSERT INTO chat_rooms (participant_1, participant_2, item_id, reservation_id)
    VALUES (p1, p2, v_item_id, NULL)
    ON CONFLICT (participant_1, participant_2, item_id)
      WHERE reservation_id IS NULL AND item_id IS NOT NULL
    DO UPDATE SET item_id = EXCLUDED.item_id
    RETURNING id INTO room_id;
  END IF;

  RETURN room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION get_or_create_room(UUID, UUID, UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_or_create_room(UUID, UUID, UUID, UUID)
  TO authenticated, service_role;

-- Updated get_chat_list to use rooms
DROP FUNCTION IF EXISTS get_chat_list(UUID);

CREATE OR REPLACE FUNCTION get_chat_list(p_user_id UUID)
RETURNS TABLE (
  room_id UUID,
  partner_id UUID,
  partner_nickname TEXT,
  partner_image TEXT,
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  unread_count BIGINT
) AS $$
BEGIN
  IF current_setting('role', true) <> 'service_role'
     AND (auth.uid() IS NULL OR auth.uid() <> p_user_id) THEN
    RAISE EXCEPTION 'not authorized to read this chat list';
  END IF;

  RETURN QUERY
  SELECT
    r.id AS room_id,
    CASE WHEN r.participant_1 = p_user_id THEN r.participant_2 ELSE r.participant_1 END AS partner_id,
    u.nickname AS partner_nickname,
    u.profile_image AS partner_image,
    r.last_message,
    r.last_message_at,
    COALESCE(
      (SELECT COUNT(*) FROM chat_messages cm
       WHERE cm.room_id = r.id
       AND cm.sender_id != p_user_id
       AND cm.read_at IS NULL), 0
    ) AS unread_count
  FROM chat_rooms r
  JOIN users u ON u.id = CASE
    WHEN r.participant_1 = p_user_id THEN r.participant_2
    ELSE r.participant_1
  END
  WHERE r.participant_1 = p_user_id OR r.participant_2 = p_user_id
  ORDER BY r.last_message_at DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION get_chat_list(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_chat_list(UUID) TO authenticated, service_role;

-- Room-aware chat message RLS. The old policies only checked sender/receiver
-- ids and did not verify room membership.
DROP POLICY IF EXISTS "Participants can read own messages" ON chat_messages;
CREATE POLICY "Participants can read own messages"
  ON chat_messages FOR SELECT
  USING (
    (sender_id = auth.uid() OR receiver_id = auth.uid())
    AND room_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM chat_rooms cr
      WHERE cr.id = chat_messages.room_id
        AND (cr.participant_1 = auth.uid() OR cr.participant_2 = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can send messages" ON chat_messages;
CREATE POLICY "Users can send messages"
  ON chat_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND room_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM chat_rooms cr
      WHERE cr.id = chat_messages.room_id
        AND (auth.uid() = cr.participant_1 OR auth.uid() = cr.participant_2)
        AND chat_messages.receiver_id IN (cr.participant_1, cr.participant_2)
        AND chat_messages.receiver_id <> auth.uid()
    )
  );

DROP POLICY IF EXISTS "Receiver can update messages" ON chat_messages;
DROP POLICY IF EXISTS "Receiver can mark messages as read" ON chat_messages;
CREATE POLICY "Receiver can mark messages as read"
  ON chat_messages FOR UPDATE
  USING (receiver_id = auth.uid())
  WITH CHECK (receiver_id = auth.uid());

CREATE OR REPLACE FUNCTION chat_messages_block_immutable_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.sender_id IS DISTINCT FROM OLD.sender_id
     OR NEW.receiver_id IS DISTINCT FROM OLD.receiver_id
     OR NEW.room_id IS DISTINCT FROM OLD.room_id
     OR NEW.reservation_id IS DISTINCT FROM OLD.reservation_id
     OR NEW.message IS DISTINCT FROM OLD.message
     OR NEW.translated_message IS DISTINCT FROM OLD.translated_message
     OR NEW.source_lang IS DISTINCT FROM OLD.source_lang
     OR NEW.image_url IS DISTINCT FROM OLD.image_url
     OR NEW.location IS DISTINCT FROM OLD.location
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'chat message content is immutable';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS chat_messages_block_immutable_update ON chat_messages;
CREATE TRIGGER chat_messages_block_immutable_update
  BEFORE UPDATE ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION chat_messages_block_immutable_update();

CREATE OR REPLACE FUNCTION update_chat_room_last_message()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.room_id IS NOT NULL THEN
    UPDATE chat_rooms
       SET last_message = COALESCE(NEW.message, '[image]'),
           last_message_at = COALESCE(NEW.created_at, now())
     WHERE id = NEW.room_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS update_chat_room_last_message ON chat_messages;
CREATE TRIGGER update_chat_room_last_message
  AFTER INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_chat_room_last_message();
