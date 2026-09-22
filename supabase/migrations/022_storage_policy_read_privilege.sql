-- PostgreSQL checks privileges of tables referenced by applicable policies,
-- even when the uploaded object belongs to a different storage bucket.
-- Existing participant-only RLS on chat_rooms continues to restrict rows.
GRANT SELECT ON public.chat_rooms TO authenticated;
