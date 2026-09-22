-- Expiry runs independently of a client being open. Financial attempts with
-- unknown outcomes remain held for reconciliation, never cleared by this job.
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule('dolpin-expire-unpaid-rentals', '* * * * *',
  'SELECT public.expire_unpaid_rentals();');
