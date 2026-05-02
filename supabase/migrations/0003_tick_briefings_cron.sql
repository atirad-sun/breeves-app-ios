-- Phase 2 Step 5 — schedule tick_briefings to run every 10 minutes.
--
-- Requires the pg_cron and pg_net extensions (Supabase ships both).
-- The cron job POSTs to the Edge Function with the service role key
-- in the Authorization header; tick_briefings rejects anything else.
--
-- IMPORTANT: this migration references two Vault secrets that must be
-- set in the Supabase dashboard BEFORE running it:
--   project_url      — e.g. 'https://xxxxx.supabase.co'
--   service_role_key — copy from Settings → API
--
-- Set them with:
--   select vault.create_secret('https://xxxxx.supabase.co', 'project_url');
--   select vault.create_secret('eyJhbGc...', 'service_role_key');
--
-- If you re-run this migration, the unschedule call cleans up the old job
-- so you don't end up with duplicates.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Drop any existing schedule with this name so re-running is idempotent.
-- cron.unschedule errors if the job doesn't exist; wrap in a do-block.
do $$
begin
    perform cron.unschedule('tick-briefings-10min');
exception when others then
    null;
end $$;

select cron.schedule(
    'tick-briefings-10min',
    '*/10 * * * *',
    $cron$
    select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/tick_briefings',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
        ),
        body := '{}'::jsonb
    );
    $cron$
);
