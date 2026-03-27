CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID REFERENCES reservations(id),
  sender_id UUID REFERENCES users(id) NOT NULL,
  receiver_id UUID REFERENCES users(id) NOT NULL,
  message TEXT,
  translated_message TEXT,
  source_lang TEXT,
  image_url TEXT,
  location JSONB,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Participants can read their messages
CREATE POLICY "Participants can read own messages"
  ON chat_messages FOR SELECT
  USING (sender_id = auth.uid() OR receiver_id = auth.uid());

-- Users can send messages
CREATE POLICY "Users can send messages"
  ON chat_messages FOR INSERT
  WITH CHECK (sender_id = auth.uid());

-- Receiver can mark as read
CREATE POLICY "Receiver can update messages"
  ON chat_messages FOR UPDATE
  USING (receiver_id = auth.uid());

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
