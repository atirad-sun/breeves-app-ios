# Supabase setup — Breeves v1

This is the manual-setup checklist. Owner of the Supabase project runs these steps once.

## 1. Create the project
1. Sign in at https://supabase.com → New project → name it **breeves**, region near primary user base.
2. Capture the **Project URL** and **anon key** from Project Settings → API.
3. Capture the **service role key** (keep it server-side only).

## 2. Run migrations
```bash
psql "$SUPABASE_DB_URL" -f migrations/0001_init.sql
```
or paste the migration into the Supabase SQL editor.

## 3. Enable auth providers
- Apple: Authentication → Providers → Apple. Configure with the Services ID + key from your Apple Developer account.
- Google: Authentication → Providers → Google. Configure with the iOS OAuth client ID from Google Cloud Console.
- Add the iOS bundle ID `com.breeves.app` to the redirect allowlist.

## 4. Deploy the Edge Function
```bash
supabase functions deploy generate_daily_briefing --project-ref <ref>
```

## 5. Schedule via pg_cron (daily 05:00 UTC for v1)
```sql
select cron.schedule(
  'breeves-daily-brief',
  '0 5 * * *',
  $$ select net.http_post(
       url := 'https://<ref>.functions.supabase.co/generate_daily_briefing',
       headers := jsonb_build_object('Authorization','Bearer ' || current_setting('app.service_role_key'))
     ) $$
);
```
Per-user TZ scheduling is v2.

## 6. Smoke test
```bash
curl -X POST 'https://<ref>.functions.supabase.co/generate_daily_briefing' \
  -H "Authorization: Bearer <user-jwt>"
```
Expect `{"ok": true, "date": "...", "topic_count": 3}` and a row in `daily_briefings`.
