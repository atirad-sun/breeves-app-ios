-- Phase 2 Step 5 — per-user-timezone cron support.
--
-- Adds last_briefing_run_at to profiles so the tick_briefings cron
-- can skip users it already processed in the current 23-hour window.
-- 23h (not 24h) gives a small safety margin so a user whose delivery
-- time drifts by a minute doesn't get skipped on the second day.

alter table public.profiles
    add column if not exists last_briefing_run_at timestamptz;

-- Index supports the eligibility scan: where notification_enabled and
-- (last_briefing_run_at is null or last_briefing_run_at < now() - 23h).
create index if not exists profiles_eligibility_idx
    on public.profiles (notification_enabled, last_briefing_run_at)
    where notification_enabled = true;
