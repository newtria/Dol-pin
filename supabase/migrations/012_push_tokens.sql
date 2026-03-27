-- Add FCM token column to users
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Supabase Edge Function will handle sending push notifications
-- when new messages, reservation updates, etc. occur.
-- See supabase/functions/push-notification/ for the edge function.
