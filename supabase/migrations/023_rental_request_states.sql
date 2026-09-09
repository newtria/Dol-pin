-- Enum additions commit before migration 024 uses them.
ALTER TYPE public.reservation_status ADD VALUE IF NOT EXISTS 'requested';
ALTER TYPE public.reservation_status ADD VALUE IF NOT EXISTS 'accepted';
ALTER TYPE public.reservation_status ADD VALUE IF NOT EXISTS 'rejected';
ALTER TYPE public.reservation_status ADD VALUE IF NOT EXISTS 'expired';
