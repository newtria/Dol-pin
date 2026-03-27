-- Chat rooms table for proper conversation management
CREATE TABLE IF NOT EXISTS chat_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_1 UUID NOT NULL REFERENCES users(id),
  participant_2 UUID NOT NULL REFERENCES users(id),
  item_id UUID REFERENCES rental_items(id),
  last_message TEXT,
  last_message_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),

  UNIQUE(participant_1, participant_2)
);

-- Add room_id to chat_messages
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES chat_rooms(id);

-- Create index for fast room lookups
CREATE INDEX IF NOT EXISTS idx_chat_rooms_participants
  ON chat_rooms(participant_1, participant_2);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room
  ON chat_messages(room_id, created_at DESC);

-- RLS for chat_rooms
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own rooms" ON chat_rooms
  FOR SELECT USING (
    auth.uid() = participant_1 OR auth.uid() = participant_2
  );

CREATE POLICY "Users can create rooms" ON chat_rooms
  FOR INSERT WITH CHECK (
    auth.uid() = participant_1 OR auth.uid() = participant_2
  );

-- Function to get or create a chat room
CREATE OR REPLACE FUNCTION get_or_create_room(
  user_a UUID,
  user_b UUID,
  p_item_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  room_id UUID;
  p1 UUID;
  p2 UUID;
BEGIN
  -- Normalize participant order
  IF user_a < user_b THEN
    p1 := user_a; p2 := user_b;
  ELSE
    p1 := user_b; p2 := user_a;
  END IF;

  -- Find existing room
  SELECT id INTO room_id FROM chat_rooms
    WHERE participant_1 = p1 AND participant_2 = p2;

  IF room_id IS NULL THEN
    INSERT INTO chat_rooms (participant_1, participant_2, item_id)
    VALUES (p1, p2, p_item_id)
    RETURNING id INTO room_id;
  END IF;

  RETURN room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Updated get_chat_list to use rooms
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
$$ LANGUAGE plpgsql SECURITY DEFINER;
