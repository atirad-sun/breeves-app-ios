# Breeves iOS App — v1 Vertical Slice Plan

## Context

This is a greenfield build. The workspace currently contains only the handover doc ([Brief30_Handover_Document-v3.md](../Brief30_Handover_Document-v3.md)) — no code, no Xcode project, no Supabase setup. The product (formerly codenamed "Brief30", now branded **Breeves**) is a 30-minute daily news briefing app: 3 user-chosen topics × 6 AI-summarized articles, with three switchable "Reading Lenses" (Universal / Topic-Specific / Executive).

Goal of this v1: **a clickable end-to-end vertical slice.** A real iOS app with real auth (Apple + Google), real Supabase persistence, and the full Reading Lenses UX — but the news pipeline (NewsAPI → Gemini → JSON) is **stubbed**: an Edge Function returns canned, schema-correct briefings so the iOS app and the data contract can be exercised without paying for / debugging the LLM yet. Real news ingestion is v2.

Decisions locked from clarification:
- **Scope:** Full vertical slice with stubbed news/LLM data
- **iOS target:** iOS 18+ (modern SwiftUI, `@Observable`, SwiftData, latest TabView/scroll APIs)
- **Auth:** Sign in with Apple + Google, both from day one
- **Project shape:** Single app target with internal SPM modules
- **Offline:** Cache-on-fetch (persist day's briefing locally; skip BGTaskScheduler in v1)
- **Brand:** "Breeves" everywhere — bundle ID, display name, Supabase project, code

---

## Architecture Overview

```
┌─────────────────────────── iOS App (SwiftUI, iOS 18+) ───────────────────────────┐
│                                                                                  │
│   App target: Breeves                                                            │
│   ├── Packages/DesignSystem    — colors, typography, spacing, primitives         │
│   ├── Packages/Models          — Codable models matching JSON schema             │
│   ├── Packages/Networking      — Supabase client wrapper, auth, briefing fetch   │
│   ├── Packages/Persistence     — SwiftData store for cached briefings + prefs    │
│   └── App/Features             — Onboarding, Dashboard, Settings, Completion    │
│                                                                                  │
└────────────────────────────────────┬─────────────────────────────────────────────┘
                                     │ Supabase Swift SDK
                                     ▼
┌─────────────────────────── Supabase Project: breeves ────────────────────────────┐
│   auth.users  (Apple + Google providers enabled)                                 │
│   public.profiles            — user prefs (notification time, default lens)      │
│   public.user_topics         — exactly 3 topics per user                         │
│   public.daily_briefings     — JSONB payload, one row per (user, date)           │
│                                                                                  │
│   Edge Function: generate_daily_briefing                                         │
│     v1: returns canned schema-valid JSON (seeded fixtures keyed by topic)        │
│     v2: NewsAPI fetch → Gemini → strict JSON                                     │
│                                                                                  │
│   pg_cron: 5:00 AM (user-local, stored as offset) → invokes Edge Function        │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## Phased Build Order

The slice is built bottom-up so each phase is demoable:

### Phase A — Foundation (no UI yet)
1. Create Xcode project: app target `Breeves`, bundle ID `com.breeves.app`, deployment target iOS 18.
2. Initialize git repo at workspace root.
3. Add SPM packages (local, in `Packages/`): `DesignSystem`, `Models`, `Networking`, `Persistence`.
4. Add external SPM dependency: [supabase-swift](https://github.com/supabase/supabase-swift).
5. **Models package:** Define `Codable` types mirroring the JSON schema (handover doc §4):
   - `DailyBriefing { date, topics: [TopicBriefing] }`
   - `TopicBriefing { topic, articles: [Article] }`
   - `Article { headline, estimatedReadTimeMinutes, universalMode, topicSpecificMode, executiveMode }`
   - `UniversalMode { gist, rippleEffect, personalImpact, keyMetric }`
   - `TopicSpecificMode { bullet1Header, bullet1Text, bullet2Header, bullet2Text, bullet3Header, bullet3Text }`
   - `ExecutiveMode { theIntel, whyFlagged, openQuestions, decisionAction }`
   - Use `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`.
6. **DesignSystem package:** OLED-friendly tokens — `Color.background = .black`, SF Pro for UI, New York for long-form. Spacing scale (4/8/16/24/32). Typography ramp (LargeTitle, Title, Body, Caption). Reusable `LensToggle`, `ProgressRing`, `ArticleCard` primitives.

### Phase B — Supabase backend
1. Create Supabase project named `breeves` (manual; user does this in dashboard).
2. SQL migration file in `supabase/migrations/0001_init.sql`:
   - `profiles` (id FK auth.users, notification_time time, default_lens text, tz text)
   - `user_topics` (user_id, topic text, slot int 1..3, UNIQUE(user_id, slot))
   - `daily_briefings` (user_id, briefing_date date, payload jsonb, PRIMARY KEY(user_id, briefing_date))
   - RLS policies: users read/write only their own rows.
3. Enable Apple + Google providers in Supabase Auth dashboard. Configure Apple Services ID + Google OAuth client.
4. Edge Function `generate_daily_briefing` (Deno):
   - v1 implementation: read user's 3 topics, return seeded fixture JSON per topic (6 articles each), insert into `daily_briefings`.
   - Fixtures live in `supabase/functions/generate_daily_briefing/fixtures/{topic}.json`.
5. pg_cron job: daily at 05:00 UTC (good enough for v1; per-user TZ scheduling is v2).

### Phase C — Networking & Persistence
1. **Networking package:**
   - `SupabaseClient` singleton wrapper (URL + anon key from `Secrets.plist`, gitignored).
   - `AuthService`: `signInWithApple()`, `signInWithGoogle()`, `signOut()`, `currentUser` (`@Observable`).
   - `BriefingService.fetchToday() -> DailyBriefing` — selects from `daily_briefings` for today's date.
   - `ProfileService` — read/update preferences and topics.
2. **Persistence package:** SwiftData `@Model CachedBriefing { date, payloadData, fetchedAt }`. Single-row-per-date upsert. Read path returns cached if same day, else triggers refresh.

### Phase D — Onboarding flow
1. **Splash + Auth screen** ([Features/Auth/AuthView.swift]): minimalist Breeves wordmark, two buttons. Real `SignInWithAppleButton` + Google sign-in via the Google iOS SDK; both feed into `AuthService`.
2. **Topic selection** ([Features/Onboarding/TopicSelectionView.swift]): grid of preset topics + custom text input. "Next" disabled until exactly 3 selected. Writes to `user_topics`.
3. **Preferences** ([Features/Onboarding/PreferencesView.swift]): `DatePicker` for notification time (.hourAndMinute), segmented `LensToggle` for default lens. Writes to `profiles`.

### Phase E — Daily Dashboard (the core UX)
1. **DashboardView** ([Features/Dashboard/DashboardView.swift]):
   - Header: today's date, 30-min progress ring (driven by count of read articles), `LensToggle` (Universal / Deep Dive / Action).
   - `TabView(.page)` for swipe between the 3 topics.
   - Inside each tab: vertical `ScrollView` of `ArticleCard`s.
2. **ArticleCard** ([DesignSystem/ArticleCard.swift]): headline, read-time chip, three bullet rows whose **content is keyed off the active lens** via the `@Observable` view model. Lens switch is a pure client-side keypath swap with `.animation(.easeInOut)` cross-fade — **no network call** (per spec §3).
3. **Read tracking:** tap or scroll-past marks article read; persisted in SwiftData; drives progress ring.
4. **Full Article view** ([Features/Dashboard/ArticleWebView.swift]): `SafariView` (`SFSafariViewController` wrapped) for "Read Full Article".
5. **Completion screen** ([Features/Completion/CompletionView.swift]): triggered when all 18 read; "You're all caught up for today."

### Phase F — Settings
1. **SettingsView** ([Features/Settings/SettingsView.swift]): Manage Topics, Notification Time, Default Lens, Sign Out. Topic changes show alert: "Changes will apply to tomorrow's briefing."

### Phase G — Polish & verification (see Verification section)

---

## Critical Files to Create

```
Breeves.xcodeproj
Breeves/
  BreevesApp.swift                          ← @main, AuthService environment
  Info.plist                                ← URL schemes for Google sign-in
  Secrets.plist                             ← gitignored; SUPABASE_URL, ANON_KEY, GOOGLE_CLIENT_ID
  Features/
    Auth/AuthView.swift
    Onboarding/TopicSelectionView.swift
    Onboarding/PreferencesView.swift
    Dashboard/DashboardView.swift
    Dashboard/TopicFeedView.swift
    Dashboard/ArticleWebView.swift
    Settings/SettingsView.swift
    Completion/CompletionView.swift
  AppState/RootView.swift                   ← routes splash → onboarding → dashboard
Packages/
  DesignSystem/Sources/DesignSystem/
    Tokens.swift                            ← colors, spacing, typography
    LensToggle.swift
    ArticleCard.swift
    ProgressRing.swift
  Models/Sources/Models/
    DailyBriefing.swift
    Article.swift
    ReadingLens.swift                       ← enum { universal, topicSpecific, executive }
  Networking/Sources/Networking/
    SupabaseClient.swift
    AuthService.swift
    BriefingService.swift
    ProfileService.swift
  Persistence/Sources/Persistence/
    CachedBriefing.swift                    ← @Model
    BriefingCache.swift                     ← upsert/read
supabase/
  migrations/0001_init.sql
  functions/generate_daily_briefing/index.ts
  functions/generate_daily_briefing/fixtures/{ai,finance,tech,...}.json
.gitignore                                  ← Secrets.plist, .DS_Store, build/, DerivedData
README.md                                   ← setup steps, env vars
```

---

## Out of Scope for v1 (explicit non-goals)

- Real NewsAPI integration
- Real Gemini / LLM calls
- Push notifications (notification time is stored but not yet used)
- BGTaskScheduler background refresh
- Per-user-timezone cron scheduling
- Android, iPad-optimized layout, widgets
- Analytics, crash reporting

---

## Verification

End-to-end smoke test once all phases land:

1. **Build:** Open `Breeves.xcodeproj` in Xcode 16, select an iPhone 16 Pro simulator (iOS 18+), Cmd-R. App launches to splash.
2. **Auth:** Tap "Sign in with Apple" → use simulator Apple ID → lands on Topic Selection. Repeat with a fresh sim for Google.
3. **Onboarding:** Pick exactly 3 topics → Next enables → set notification time → land on Dashboard.
4. **Backend trigger:** In Supabase dashboard, manually invoke `generate_daily_briefing` for the test user. Verify a row appears in `daily_briefings` with valid JSON matching the Models schema (decode test in unit tests).
5. **Dashboard UX:**
   - 6 article cards visible per topic; swipe left/right between topics; cards render headline + bullets.
   - Tap each Lens toggle option → bullet content cross-fades **with no network request** (verify via Charles/Proxyman or Xcode network instrument).
   - Read all 18 → Completion screen appears.
6. **Persistence:** Force-quit app, relaunch with airplane mode → cached briefing still renders.
7. **Settings:** Change topics → alert fires → re-trigger Edge Function → next day's briefing uses new topics.
8. **Unit tests** (XCTest, in `Models` and `Networking` packages):
   - JSON schema fixture decodes cleanly into `DailyBriefing`.
   - Lens enum maps to correct keypaths on `Article`.
   - `BriefingCache` upsert is idempotent.

---

## Open Questions to Resolve During Implementation

These don't block planning but will need answers as we go:
- Topic taxonomy for v1 — fixed list of ~20 (Tech, AI, Finance, Climate, Geopolitics, ...) or fully freeform? Spec says searchable list **plus** custom input, so likely both.
- Exact wordmark / logo for "Breeves" — placeholder text-based mark for v1 unless an asset is provided.
- Supabase project region — pick one near primary user base.
