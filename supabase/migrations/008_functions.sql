-- Get chat list with latest message per conversation partner
CREATE OR REPLACE FUNCTION get_chat_list(user_id UUID)
RETURNS TABLE (
  partner_id UUID,
  partner_nickname TEXT,
  partner_image TEXT,
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  unread_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  WITH conversations AS (
    SELECT DISTINCT
      CASE
        WHEN sender_id = user_id THEN receiver_id
        ELSE sender_id
      END AS partner
    FROM chat_messages
    WHERE sender_id = user_id OR receiver_id = user_id
  ),
  latest_msg AS (
    SELECT DISTINCT ON (c.partner)
      c.partner,
      cm.message,
      cm.created_at
    FROM conversations c
    JOIN chat_messages cm ON
      (cm.sender_id = user_id AND cm.receiver_id = c.partner) OR
      (cm.sender_id = c.partner AND cm.receiver_id = user_id)
    ORDER BY c.partner, cm.created_at DESC
  ),
  unread AS (
    SELECT
      sender_id AS partner,
      COUNT(*) AS cnt
    FROM chat_messages
    WHERE receiver_id = user_id AND read_at IS NULL
    GROUP BY sender_id
  )
  SELECT
    lm.partner AS partner_id,
    u.nickname AS partner_nickname,
    u.profile_image AS partner_image,
    lm.message AS last_message,
    lm.created_at AS last_message_at,
    COALESCE(ur.cnt, 0) AS unread_count
  FROM latest_msg lm
  JOIN users u ON u.id = lm.partner
  LEFT JOIN unread ur ON ur.partner = lm.partner
  ORDER BY lm.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
