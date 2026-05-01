# Breeves — iOS

A 30-minute morning brief. Three topics. No noise.

## Quick start

```bash
# 1. Generate the Xcode project from project.yml
xcodegen generate

# 2. Open in Xcode
open Breeves.xcodeproj

# 3. Run on iPhone 17 Pro simulator (or any iOS 18+ device)
#    The app boots into a mock backend automatically when no Secrets.plist exists.
```

The app will launch with a fully-working mock backend that serves the 18-article fixture
data so you can exercise the entire UX (auth → onboarding → dashboard → completion → settings)
without any Supabase setup.

## Wiring the live Supabase backend

When you're ready to connect to a real backend:

1. Create a Supabase project. See `supabase/README.md` for the full checklist.
2. Run `supabase/migrations/0001_init.sql` against your project.
3. Deploy `supabase/functions/generate_daily_briefing/`.
4. Add a `Breeves/Secrets.plist` (gitignored) with these keys:

```xml
<dict>
  <key>SUPABASE_URL</key>      <string>https://YOUR_REF.supabase.co</string>
  <key>SUPABASE_ANON_KEY</key> <string>...</string>
  <key>GOOGLE_CLIENT_ID</key>  <string>...</string>
</dict>
```

`BreevesBackend.resolve()` switches automatically: if `Secrets.plist` is present and parseable,
all services point at Supabase; otherwise the in-memory mock takes over.

## Project structure

```
Breeves/                      App target — SwiftUI screens + AppModel
Packages/
  DesignSystem/               Color/typography tokens, primitives (LensToggle, ProgressHairline, …)
  Models/                     Codable types for the JSON briefing schema (with tests)
  Networking/                 Supabase + Mock service implementations
  Persistence/                SwiftData cache (CachedBriefing, ReadArticle, CachedPreferences)
supabase/
  migrations/0001_init.sql    Schema + RLS + signup trigger
  functions/generate_daily_briefing/
                              Edge Function (v1: returns canned fixture per topic)
claude-docs/                  Design + planning docs
handoff/                      Original Claude Design HTML/JSX export
```

## Demo launch flags (mock backend only)

Useful for screenshot capture / QA without tapping through the flow:

| Flag                      | Effect                                               |
|---------------------------|------------------------------------------------------|
| `-BREEVES_DEMO`           | Auto sign-in, seed AI / Finance / Geopolitics topics |
| `-BREEVES_LENS_DEEP`      | Start with Deep Dive lens active (with `-BREEVES_DEMO`) |
| `-BREEVES_LENS_ACTION`    | Start with Action lens active (with `-BREEVES_DEMO`)    |
| `-BREEVES_COMPLETE`       | Mark all 18 read → show completion screen           |
| `-BREEVES_SETTINGS`       | Auto-present Settings sheet on dashboard             |
| `-BREEVES_TOPICS`         | Land on Topic Selection (signed-in)                  |
| `-BREEVES_PREFS`          | Land on Preferences (signed-in)                      |

These flags are no-ops when `Secrets.plist` is configured (live backend mode).

## Tests

```bash
cd Packages/Models && swift test
```

## v1 scope (what's done)

- ✅ Auth (Sign in with Apple + mock Google)
- ✅ Onboarding: pick 3 topics + delivery time + default lens
- ✅ Dashboard: progress hairline, swipe between 3 topics, lens toggle, 6 articles per topic
- ✅ ArticleCard: counter + dot leader + headline + lens-keyed bullet block + read state
- ✅ Completion screen ("Inbox Zero")
- ✅ Settings sheet: topics, delivery, brief length, default lens, appearance, account, about
- ✅ Light + Dark themes (designed independently, not auto-inverted)
- ✅ SwiftData offline cache for briefing + read state + preferences
- ✅ Mock backend served from bundled fixtures (no Supabase required for demo)
- ✅ Real Supabase wiring via `BreevesBackend.resolve()` when Secrets.plist is provided

## Out of scope for v1 (per plan)

- Real NewsAPI + Gemini pipeline (the Edge Function returns canned fixtures)
- Push notifications (toggle stored, delivery is v2)
- BGTaskScheduler background refresh
- Per-user-timezone cron scheduling
- Android, iPad, widgets, analytics, billing
