# Claude Design Prompt — Breeves iOS App

> Paste everything below into Claude Design (or any high-fidelity UI generation tool). It is self-contained: product context, aesthetic direction, screen-by-screen specs, design tokens, interaction patterns, and quality bar. No outside references required.

---

## 0. Role & Mission

You are designing the **iOS native SwiftUI** UI for **Breeves** — a premium daily news briefing app for time-poor executives. The product promise is rigid: **3 topics × 6 articles, finished in ≤30 minutes.** Your job is to make that promise feel like a luxury, not a chore.

Deliver a complete, cohesive, production-grade visual design system and high-fidelity mockups for every screen listed in §6. Designs must be **iOS 18+ native** (SF Symbols, Dynamic Type, system materials, safe areas), **dark-mode-first** (OLED `#000000`), and **typography-led** — closer to a Sunday broadsheet or a private-bank research note than a social news feed.

**Non-negotiable quality bar:** Every screen must look like it belongs in an Apple Design Award shortlist. No stock dashboard chrome. No generic AI-app gradients. No emoji icons.

---

## 1. Product Snapshot

- **Name:** Breeves (rhymes with "leaves")
- **Format:** iOS native, SwiftUI, iPhone-only for v1 (iOS 18+)
- **Promise:** A 30-minute morning briefing — 3 user-chosen topics, 6 AI-summarized articles each, delivered at 5 AM local
- **Killer feature — "Reading Lenses":** A 3-way client-side toggle that re-renders the same article in three formats with no network call:
  1. **Universal** — 4 bullets: Gist, Ripple Effect, Personal Impact, Key Metric
  2. **Deep Dive** (Topic-Specific) — 3 bullets with dynamic, topic-aware headers (e.g. "The Market Move", "Capital at Stake", "Counter-Position" for Finance)
  3. **Action** (Executive) — 4 bullets: The Intel, Why Flagged, Open Questions, Decision/Action
- **Audience:** Senior operators, founders, investors, partners — people who pay for time, not content. They read the FT, Stratechery, Matt Levine. They will judge typography in 0.4 seconds.

---

## 2. Aesthetic Direction (commit fully)

Pick ONE direction and execute it with precision. Do not blend.

**Primary direction — "Executive Dossier":**
A private intelligence brief delivered each morning. Editorial restraint. Generous negative space. Serif headlines with confident weight. Ultra-fine hairline rules instead of boxes. Dot-leader read-time chips. Tabular figures everywhere a number appears. Materials are paper and ink, not plastic and glow.

**Tone words:** Quiet, exact, expensive, considered, unhurried-but-efficient, FT Weekend × Apple Notes × Bloomberg Terminal (without the green).

**Anti-references — explicitly avoid:**
- ❌ Apple News (too consumer, too colorful, image-led)
- ❌ Flipboard / Feedly / Inoreader (RSS-reader chrome)
- ❌ Generic "AI app" tropes: purple→blue gradients, sparkle icons, glassmorphism on everything, Inter/Space Grotesk
- ❌ Emoji as structural icons
- ❌ Stock photography or hero images per article (this is a *summary* product — text is the hero)
- ❌ Skeuomorphic newspaper textures, faux paper grain, faux ink bleed

**Reference moodboard (in spirit, not in copy):**
- Financial Times app, weekend long-reads
- Stratechery email layout
- Apple's *Books* serif reading view
- Linear's quiet density and tabular numerics
- Robinhood Gold's restrained dark theme
- A Moleskine cahier — small, precise, premium

---

## 3. Design Tokens (start here, lock these first)

### 3.1 Color — Dark mode (default, primary)

```
// Surfaces
bg.canvas         #000000   // OLED true black, app background
bg.elevated.1     #0A0A0B   // cards, sheets resting on canvas
bg.elevated.2     #131316   // modal sheets, popovers
bg.scrim          rgba(0,0,0,0.55) // modal backdrop

// Hairlines & dividers (use these heavily — they replace boxes)
hairline.faint    rgba(255,255,255,0.06)
hairline.standard rgba(255,255,255,0.10)
hairline.strong   rgba(255,255,255,0.18)

// Text
text.primary      #F5F2EC   // warm off-white, NOT pure white — softens at 5 AM
text.secondary    #A8A39A   // metadata, captions
text.tertiary     #6E6A63   // timestamps, dot-leaders, disabled
text.inverse      #0A0A0B

// Brand accent — single color, used sparingly
accent.primary    #C8A45C   // brushed brass / aged gold — the only chromatic color in the entire app
accent.muted      #8A6F3D   // pressed/disabled accent

// Topic chroma (used ONLY as a 2px topic indicator stripe + topic-name color in the page-dot row, never as filled backgrounds)
topic.1           #C8A45C   // brass (default Topic 1)
topic.2           #7A9E9F   // oxidized teal
topic.3           #B4654A   // burnt sienna
// (Optional palette for additional topics if user picks more in future: muted dusty rose, slate, moss — all desaturated, all paper-friendly)

// Semantic
state.read        rgba(245,242,236,0.32)  // headline of a read article fades to this
state.success     #6B8E5A
state.danger      #B4554A
```

### 3.2 Color — Light mode (must also be designed; do not ship dark-only)

Invert thoughtfully — do **not** flip values. Use a warm cream canvas, not white.

```
bg.canvas         #F5F2EC   // warm paper
bg.elevated.1     #FFFFFF
hairline.standard rgba(10,10,11,0.10)
text.primary      #0A0A0B
text.secondary    #4B4842
accent.primary    #8A6F3D   // darker brass for AA contrast on cream
```

Verify every fg/bg pair meets WCAG AA (4.5:1 for body, 3:1 for large display).

### 3.3 Typography

Use **two type families only**.

- **Display & headlines:** **New York** (Apple system serif). Tight tracking. Weights: Medium (500), Semibold (600).
- **Body, UI, metadata, numerics:** **SF Pro Text** & **SF Pro Display**. Always enable **tabular figures** (`.monospacedDigit()`) for read-times, percentages, dates, the 30-min countdown — anywhere a number could shift width.

**Type scale (iOS Dynamic Type compatible — anchor at default, scale via `.scaledFont`):**

| Token        | Family       | Size / LH | Weight | Tracking | Use |
|--------------|--------------|-----------|--------|----------|-----|
| display.xl   | New York     | 40 / 44   | 500    | -0.5     | Date header on dashboard, completion screen |
| display.l    | New York     | 32 / 38   | 500    | -0.4     | Topic name on topic page |
| headline.l   | New York     | 26 / 32   | 600    | -0.3     | Article headline (card) |
| headline.s   | New York     | 20 / 26   | 600    | -0.2     | Section headers (Settings) |
| body.l       | SF Pro Text  | 17 / 26   | 400    |  0       | Bullet text, long-form |
| body.m       | SF Pro Text  | 15 / 22   | 400    |  0       | Secondary descriptions |
| label.m      | SF Pro Text  | 13 / 18   | 600    | +0.4     | Bullet headers (Deep Dive, Action lens), uppercase |
| caption      | SF Pro Text  | 12 / 16   | 500    | +0.2     | Read time, byline, metadata |
| mono.s       | SF Mono      | 12 / 16   | 500    |  0       | Article counter "02 / 06", time codes |

Bullet headers in Deep Dive / Action lenses are **`label.m` UPPERCASE with +0.4 tracking** — this is the editorial signature of the app. Treat it as a brand asset.

### 3.4 Spacing — 4pt base, named tokens (not arbitrary numbers)

`space.1 = 4 · space.2 = 8 · space.3 = 12 · space.4 = 16 · space.5 = 24 · space.6 = 32 · space.7 = 48 · space.8 = 64`

- Card horizontal padding: `space.5` (24)
- Card vertical rhythm between bullets: `space.4` (16)
- Section breaks: `space.7` (48)
- Screen edge insets: `space.5` (24) — generous, deliberate

### 3.5 Radius, elevation, motion

- **Radius:** Default `12pt`. Article cards `16pt`. Toggle pill `999pt` (full). **No rounded rectangles below 8pt** — keep edges either crisp or softly generous, never timid.
- **Elevation:** Avoid drop shadows. Use **hairline borders + a 1pt lift in `bg.elevated.1`** to suggest depth. The only shadow allowed: completion screen progress ring's inner glow.
- **Motion:**
  - Lens toggle cross-fade: 220ms, `easeInOut`. Bullet content fades + translates 4pt vertically, staggered 30ms per bullet. **Never reflow the card height** during the swap (reserve max-height of the three lens contents).
  - Topic swipe (TabView .page): native iOS spring, do not customize.
  - Article scroll: native; momentum unchanged.
  - Progress ring fill: spring(response: 0.6, damping: 0.8) on read-state change.
  - Respect `prefers-reduced-motion`: replace cross-fade with instant swap; replace ring spring with linear 200ms.

### 3.6 Iconography

- **SF Symbols only.** Weight: `.medium`. Scale: `.medium` for inline, `.large` for nav.
- Allowed: `chevron.left`, `chevron.right`, `xmark`, `gearshape`, `checkmark`, `safari`, `bell`, `clock`, `square.and.arrow.up`, `magnifyingglass`, `circle.fill` (for unread dot), `circle` (read).
- **Banned:** any emoji, any custom illustrative icon, any third-party icon set, any flat-color icon (filled with brand color). Icons inherit `text.secondary` by default.

---

## 4. Interaction Signature Moments

Three moments must feel disproportionately good. Spend design budget here.

1. **Lens toggle** — The 3-segment control sits pinned at the top of the article card. On tap, the segment indicator slides with a subtle spring, and the bullet block cross-fades + 4pt rise, staggered. The card height **does not jump** (pre-measure tallest lens). This is the "wow" of the product. Make it feel like turning a page in a leather-bound notebook.
2. **Topic swipe** — Horizontal page swipe between the 3 topics. The header (date, progress ring) stays fixed; only the topic name + feed transitions. Topic name uses `display.l` and slides in with a 80ms-delayed fade so the user feels the *arrival* at the new topic.
3. **Completion ("Inbox Zero")** — When article 18 is marked read, the dashboard transitions into a full-screen completion state. Progress ring closes the final arc with a spring, then gently pulses once. Headline reads *"You're all caught up for today."* in `display.xl` New York. Subline gives tomorrow's briefing time. A single quiet line of metadata: total reading time elapsed (e.g., *"23 min · 4,812 words"*) in `mono.s` tabular. No confetti. No checkmark animation. The reward is silence and white space.

---

## 5. Information Architecture & Navigation

```
Splash
  └─ AuthView (Sign in with Apple / Google)
      └─ Onboarding
          ├─ TopicSelectionView (must pick exactly 3)
          └─ PreferencesView (notification time, default lens)
              └─ DashboardView  ◄──── primary destination
                  ├─ Header: Date · ProgressRing · LensToggle
                  ├─ TabView (.page, 3 topics)
                  │   └─ TopicFeedView
                  │       └─ ArticleCard × 6 (vertical scroll)
                  │           └─ ArticleWebView (SFSafariViewController for "Read Full")
                  └─ CompletionView (replaces dashboard at 18/18)

  Settings (modal sheet from gear icon top-right of Dashboard)
      ├─ Manage Topics
      ├─ Notification Time
      ├─ Default Reading Lens
      └─ Sign Out
```

**No tab bar.** The app has one primary surface (Dashboard). Settings is a sheet. Going against iOS convention here is intentional and brand-appropriate — it reinforces the "one job, done well" promise. Settings is reached via gear icon top-right of the Dashboard.

---

## 6. Screens — Design Each in Full (dark + light, iPhone 16 Pro at 393×852)

For every screen below produce: full mockup, key states (loading, empty, error where relevant), and a callout of the typographic and spacing decisions.

### 6.1 Splash
- Full-bleed `bg.canvas`. Wordmark "Breeves" centered, `display.xl` New York Medium, letter-spacing −0.5, `text.primary`. A single 1pt × 24pt vertical hairline above the wordmark in `accent.primary` — this is the recurring brand mark; reuse it as a delimiter elsewhere. No animation beyond a 600ms fade-in.

### 6.2 Auth
- Wordmark anchored at top third.
- Tagline below in `body.m`, `text.secondary`: *"A 30-minute morning brief. Three topics. No noise."*
- Two buttons stacked at bottom, separated by `space.4`:
  - **Sign in with Apple** — native `SignInWithAppleButton(.continue, style: .white)`, full width, height 52pt
  - **Continue with Google** — custom but disciplined: `bg.elevated.1`, hairline border, Google "G" mark + label in `body.l` weight 600, height 52pt
- Below buttons: ToS / Privacy in `caption`, `text.tertiary`, centered, with hairline-underlined links.
- Bottom safe-area respected.

### 6.3 Topic Selection (Onboarding step 1)
- Header: `display.l` "Pick three." New York. Subhead `body.m` `text.secondary`: *"You can change them anytime."*
- Counter pinned top-right: `mono.s` `0 / 3` → updates to `1 / 3`, `2 / 3`, `3 / 3` in `accent.primary` when complete.
- **No grid of cards.** Instead: a single-column list of topics, each row = topic name in `headline.s` New York + a faint one-line description in `body.m` `text.secondary`. Selected state: a 2pt `accent.primary` vertical hairline appears flush left, and topic name shifts to `text.primary` weight 600. *No checkboxes, no fills.*
- Topics for v1: AI · Finance · Tech · Climate · Geopolitics · Markets · Startups · Crypto · Energy · Biotech · Defense · Macro
- "Add a custom topic" appears as the last row, with a `+` SF Symbol — tapping opens a tasteful inline input.
- Bottom CTA "Continue" — full-width, 52pt, `bg.elevated.1` with `accent.primary` text. Disabled state: opacity 0.4, no fill change.

### 6.4 Preferences (Onboarding step 2)
- Header: `display.l` "When should we wake you?"
- Two grouped sections separated by `space.7`, each preceded by an UPPERCASE `label.m` section title in `text.tertiary`:
  - **DELIVERY TIME** — large native iOS time wheel, no chrome around it. Default 5:30 AM.
  - **DEFAULT LENS** — three vertically-stacked rows: Universal · Deep Dive · Action. Each row shows the lens name `headline.s` + a one-line description `body.m`. Selected = `accent.primary` 2pt left hairline (same pattern as topic selection — repetition of this device IS the design system).
- Bottom CTA "Begin" — same style as previous step.

### 6.5 Daily Dashboard — THE HERO SCREEN
This is the screen that sells the app. Spend the most time here.

**Layout (top to bottom):**

1. **Status row** (safe-area + 8pt): left `caption` weight 500 `text.tertiary` `MONDAY · 04 MAY` (uppercase, tabular figures). Right: gear icon `text.secondary`, 24pt hit area expanded to 44pt via hitSlop.
2. **Date headline** (`space.4` below status row): `display.xl` New York `text.primary`, e.g. *"Today's brief."* — yes, with the period. Two words, declarative, never changes.
3. **Progress meter** (`space.4` below): a horizontal hairline rule the full content width. Above it on the left: `mono.s` `04 / 18` in `text.secondary`. Above on the right: `mono.s` countdown `~22 MIN LEFT` in `text.tertiary`. The hairline fills with `accent.primary` from left to right as articles are read — no rounded ends, just a clean line. (No ring on the dashboard. The ring is only used on the Completion screen.)
4. **Lens toggle** (`space.5` below progress): a 3-segment control, full content width, height 40pt. Background `bg.elevated.1`, hairline border. Segments labeled `Universal · Deep Dive · Action` in `caption` weight 600. Active segment: `bg.canvas` (yes, darker than the toggle bg — flips the convention) with `text.primary`, `accent.primary` 1pt underline 2pt below baseline. Spring-slide indicator on change.
5. **Topic name + page dots** (`space.6` below toggle): topic name in `display.l` New York, e.g. *"AI"* — left-aligned. Below it, three small page dots `· · ·` (8pt each, 8pt gap). Active dot: `accent.primary` filled. Inactive: hairline-stroke `text.tertiary`.
6. **Article feed** (paged TabView .page horizontally for topics; vertical scroll inside each):
   - Each topic is a vertically-scrolling stack of 6 ArticleCards. See §6.6.
7. **No bottom nav, no FAB, no tab bar.** Trust the user to swipe.

**States:**
- **Loading:** Skeleton cards (3 visible) — hairline-bordered rectangles with shimmering `text.tertiary` placeholder bars. Date and "Today's brief." render immediately.
- **Empty (rare):** "Tomorrow's brief lands at 5:30 AM." in `headline.l`, centered, with the brass hairline mark above. Show a `caption` line: *"Last brief: Friday · all 18 read · 28 min."*
- **Error:** Quiet inline message under the progress hairline: *"Couldn't refresh. Showing cached brief."* in `caption` `state.danger`. Single retry text-button.

### 6.6 ArticleCard (the workhorse component — 6 per topic)

This is the second-most important design after the Dashboard frame.

**Anatomy (top to bottom inside the card):**

1. **Counter + read time row:** left `mono.s` `text.tertiary` `01 / 06`. Right `caption` `text.tertiary` `4 MIN READ`. Between them: a dot-leader `· · · · · · · · · ·` filling the gap in `text.tertiary` opacity 0.4. (This dot-leader is a brand signature — keep it.)
2. **Headline:** `headline.l` New York Semibold, `text.primary`. Allow up to 3 lines, then ellipsis. When article is in `read` state: color shifts to `state.read`, weight stays.
3. **Bullet block** (depends on active lens — content swaps with cross-fade, height pre-reserved):
   - **Universal lens (4 bullets, no per-bullet header):**
     - Each bullet is a row: a 1pt × full-height `accent.primary` left hairline (4pt indent), then bullet text in `body.l`. Vertical gap between bullets: `space.4`. **No bullet glyphs (`•`)** — the hairline IS the bullet.
     - Internal label per bullet (Gist / Ripple Effect / Personal Impact / Key Metric) is **omitted** in this lens — the order conveys role.
   - **Deep Dive lens (3 bullets, dynamic headers):**
     - Each bullet has an UPPERCASE `label.m` header in `accent.primary` (e.g. *"THE MARKET MOVE"*), followed on the next line by `body.l` `text.primary` text. No left hairline.
     - Vertical gap between bullets: `space.5`.
   - **Action lens (4 bullets, fixed headers):**
     - Same structure as Deep Dive but headers are fixed: *"THE INTEL"*, *"WHY FLAGGED"*, *"OPEN QUESTIONS"*, *"DECISION / ACTION"*. The DECISION / ACTION block has a 2pt `accent.primary` left hairline AND its body text is weight 500 — the only emphasized bullet in the entire app.
4. **Footer row:** left, a single ghost text-button *"Read full →"* in `caption` weight 600 `accent.primary`, opens SFSafariViewController. Right, a single SF Symbol bookmark/share icon in `text.tertiary`, 24pt with 44pt hit area.

**Card framing:**
- No filled background. The card sits on `bg.canvas`. Top and bottom hairlines (`hairline.standard`) define the card. Horizontal edges go to the screen edge insets — there is no rounded card; the card IS the hairline + spacing pattern.
- Vertical padding inside card: `space.5` top and bottom.
- Spacing between cards: a single `space.7` (48pt) gap — the bottom hairline of card N and the top hairline of card N+1 are the same line (collapse the borders). This dense-but-rhythmic feed is what makes the product feel like a real document.

**Read state:** Tap headline OR scroll past 80% of card → marks read. Headline fades to `state.read`, counter prefix gets a tiny `accent.primary` filled `circle.fill` 6pt next to the counter (e.g. `01 / 06 ●`). No other change.

### 6.7 Article web view
Native `SFSafariViewController` in `.preferredControlTintColor(accent.primary)` and `.preferredBarTintColor(bg.canvas)`. No custom chrome. iOS handles it.

### 6.8 Completion ("Inbox Zero")
- Triggered when 18 / 18 read. Replaces dashboard (does not modal-over).
- Top: same status row + gear icon (so user can still reach settings).
- Center: a **circular progress ring**, 120pt diameter, 3pt stroke, full circle in `accent.primary`. This is the ONLY place the ring appears. Inside the ring: a single tiny `checkmark` SF Symbol, 16pt, `accent.primary`. (Yes, the only checkmark in the app — earn its presence.)
- Below ring (`space.7`): `display.xl` New York: *"You're all caught up for today."*
- Below (`space.4`): `body.l` `text.secondary`: *"Tomorrow's brief lands at 5:30 AM."*
- Below (`space.6`): a quiet stats line, centered, `mono.s` `text.tertiary`: *"23 MIN · 4,812 WORDS · 18 / 18"*.
- No CTA. No share button. Let the user close the app feeling done.

### 6.9 Settings (modal sheet)
- Sheet detent `.large`. Drag indicator visible.
- Header: `display.l` "Settings". Close button top-right (`xmark`, `text.secondary`).
- Sections, each preceded by UPPERCASE `label.m` `text.tertiary` section header:
  - **TOPICS** — a list of the user's 3 topics, each row = topic name `headline.s` + chevron right. Tapping → drills into a Manage Topics sub-screen using same picker as onboarding.
  - **DAILY DELIVERY** — row showing current notification time, drills into an inline time picker.
  - **DEFAULT LENS** — three rows (Universal / Deep Dive / Action), same pattern as onboarding.
  - **ACCOUNT** — Email (read-only, `body.m` `text.secondary`), Sign Out (text in `state.danger`, full-width row, hairline-bounded, no fill).
- Topic-change confirmation alert: native iOS alert, copy: *"Changes apply to tomorrow's brief."*

---

## 7. Component Library Deliverables

Document and design each as a standalone artifact, with default + all states (rest, hover-equiv, pressed, focus, disabled, dark, light):

1. **Hairline primitive** — `Divider` replacement; faint / standard / strong; horizontal & vertical
2. **Brass mark** — the 1×24pt vertical accent hairline used as a brand delimiter
3. **Type scale** — every token rendered with sample text, both light & dark
4. **Lens toggle** — 3-segment control, all 3 active states + animation spec
5. **Article counter chip** — `01 / 06` with read-state dot variant
6. **Read-time chip** — `4 MIN READ` with leading `clock` SF Symbol option
7. **Progress hairline** — horizontal fill component, dashboard variant
8. **Progress ring** — circular variant for completion screen
9. **Bullet row — Universal** (with left accent hairline)
10. **Bullet row — Deep Dive / Action** (UPPERCASE label + body)
11. **Topic row** (selection list, default + selected states)
12. **Primary CTA button** — 52pt height, full-width, 3 states
13. **Ghost text button** — *"Read full →"* style
14. **Section header** — UPPERCASE `label.m` `text.tertiary`, with optional brass mark above
15. **Settings row** — label + value + chevron
16. **Empty state composition** — generic template using brass mark + headline + caption

---

## 8. Hard Quality Bar — pass all of these or don't ship

Apply to every screen, both themes:

**Accessibility (CRITICAL)**
- [ ] Body text ≥ 4.5:1 contrast against its surface in BOTH themes (verify with a tool — do not eyeball)
- [ ] Secondary text ≥ 3:1
- [ ] Every interactive element has a descriptive accessibility label
- [ ] Lens toggle exposes selected state to VoiceOver (`accessibilityAddTraits(.isSelected)`)
- [ ] Color is never the only signal — read state ALSO uses opacity + a dot, not color alone
- [ ] Designs hold up at Dynamic Type XXL without truncation or layout breakage (show one screen at largest size as proof)
- [ ] `prefers-reduced-motion` variant for the lens cross-fade specified

**Touch & layout**
- [ ] All tap targets ≥ 44×44pt (use hitSlop on small icons)
- [ ] Safe areas respected — Dynamic Island clearance, home indicator clearance
- [ ] No content sits closer than `space.5` (24pt) from screen edges
- [ ] Tested at 393×852 (iPhone 16 Pro) AND 375×812 (iPhone 13 mini, smallest current)

**Visual discipline**
- [ ] Zero emojis used as icons anywhere
- [ ] Zero drop shadows except the one explicitly specified on the completion ring
- [ ] Zero gradients (the brand is hairlines and ink, not glow)
- [ ] Tabular figures everywhere a number could change width
- [ ] One — and only one — accent color in the chromatic palette
- [ ] No icon is filled with a color other than its inherited text color
- [ ] Every spacing value is from the 4pt scale; no arbitrary 13s, 18s, 23s

**Motion**
- [ ] Lens cross-fade does not cause card height jump (state this explicitly in the spec)
- [ ] Page swipe uses native iOS feel
- [ ] All durations 150–300ms unless justified

**Both themes shipped together**
- [ ] Light mode designed independently — not auto-inverted
- [ ] Both themes screenshotted side-by-side for the Dashboard hero, ArticleCard (each lens), and Completion

---

## 9. Deliverable Format

Provide as a single response:

1. **Aesthetic manifesto** (3–5 sentences) — restate your interpretation of the direction in your own words so we can confirm alignment before you over-invest.
2. **Token sheet** — colors, type, spacing, radius, motion (lock these first).
3. **Screen-by-screen mockups** — every screen in §6, dark + light, with annotation callouts for typography, spacing rationale, and interaction notes.
4. **Component library** — every item in §7.
5. **Three signature-moment storyboards** — Lens toggle, Topic swipe, Completion (3–4 frames each showing motion).
6. **Quality-bar self-check** — go through §8 and tick each item with a one-line note on how the design satisfies it.

If any decision in this brief feels wrong for the aesthetic vision, **push back in writing before designing** — but back the pushback with reasoning grounded in the product promise (30 minutes, executive audience, premium-but-quiet). Do not silently deviate.

Now design. Make it look like the only news app worth keeping on the home screen.
