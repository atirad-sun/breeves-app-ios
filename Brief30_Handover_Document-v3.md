# Handover Document: Project "Brief30"

## 1. Product Overview
* **The Mission:** To provide time-poor professionals with a high-signal, zero-noise daily news briefing that takes exactly 30 minutes or less to consume.
* **The Hook:** 3 custom topics, 6 articles per topic, summarized by AI, delivered every morning.
* **Core Differentiator:** "Reading Lenses" that allow users to instantly switch the format of the news (Universal, Topic-Specific, or Executive Action) without reloading the page.

---

## 2. Design Brief (For UX/UI Team)
**Goal:** Design a frictionless, typography-first iOS native app. The app must feel less like a traditional news feed and more like a sleek, premium executive dossier.

### Design Principles
* **Time-Aware:** The UI must respect the 30-minute limit. No infinite scrolling. 
* **Dark Mode Default:** Optimized for early morning reading in dim lighting. Use deep OLED blacks (`#000000`) and high-contrast, readable typography (e.g., Apple's SF Pro or a clean serif like New York).
* **Focused Consumption:** One article per screen.

### Key Screens to Wireframe
1. **Splash & Authentication Screen:** Minimalist logo, "Sign in with Apple" and "Sign in with Google" buttons.
2. **Onboarding - Topic Selection:** Searchable list or grid of topics. User must select exactly 3. Include a "Custom Topic" input field.
3. **Onboarding - Preferences:** Time of day for the daily push notification, and preferred default "Reading Lens".
4. **The Daily Dashboard (Main View):**
    * **Header:** Date, a subtle 30-minute countdown/progress tracker, and a 3-way toggle for the "Reading Lenses" (Universal / Deep Dive / Action).
    * **Navigation:** A horizontal `TabView` (swipe left/right) to switch between the 3 macro-topics.
    * **Content Card:** Vertical scrolling for the 6 articles. Each card shows the Headline, Read Time, and the specific bullet points dictated by the active Lens toggle. Include a "Read Full Article" secondary button.
5. **Full Article Web-View (Deep Dive):** An in-app Safari view or clean reader view for when the user wants to read beyond the bullet points.
6. **Settings & Profile:** Options to change the 3 selected topics, adjust notification time, change default Reading Lens, and Logout.
7. **Completion State:** A satisfying "Inbox Zero" style screen when all 18 articles are read, with a message like "You're all caught up for today."

### User Flows & Interactions (For Prototyping)
* **Flow 1: First-Time Onboarding:**
    * Splash Screen -> Tap "Sign in with Apple" -> Success State -> Topic Selection Screen (Requires 3 selections to enable 'Next' button) -> Preferences Screen (Set Time) -> Transition to First Daily Dashboard.
* **Flow 2: The Daily 30-Minute Reading Habit:**
    * Tap Push Notification -> Opens directly to Daily Dashboard (Topic 1, Article 1).
    * *Interaction:* User reads Article 1. Swipes UP to go to Article 2.
    * *Interaction:* User taps "Executive Action" on the top toggle -> bullet points instantly cross-fade into the new format.
    * *Interaction:* User swipes LEFT -> Screen slides to Topic 2 feed.
    * User finishes the last article -> Auto-transitions to the Completion "Inbox Zero" Screen.
* **Flow 3: Modifying Interests:**
    * User taps gear icon (Settings) -> Taps "Manage Topics" -> Deselects "AI Agents", selects "Quantum Computing" -> Taps "Save" -> Alert: "Changes will apply to tomorrow's briefing."

---

## 3. Engineering Spec (For Dev Team)
**Goal:** Build a fast, offline-capable iOS app powered by a cheap, automated, serverless backend.

### Tech Stack
* **Frontend:** SwiftUI (iOS Native).
* **Backend/Database:** Supabase (PostgreSQL).
* **Compute:** Supabase Edge Functions + Supabase Cron.
* **AI Provider:** Gemini API (or equivalent LLM).

### Backend Architecture (The 5:00 AM Cron Job)
1. At 5:00 AM local time, Supabase triggers an Edge Function.
2. The function pings a news API (e.g., NewsAPI) to fetch top stories for the user's 3 topics.
3. The function passes the raw article text to the LLM using the designated **System Prompt** (detailed below).
4. The LLM returns a strictly formatted **JSON Object** (containing the 3 Reading Lens data points).
5. Supabase saves this JSON payload into a `daily_briefings` table.

### Frontend Architecture (iOS)
1. **Background Fetch:** The app should ideally use iOS Background Tasks to silently download the day's JSON payload before the user even wakes up.
2. **State Management:** The "Reading Lenses" toggle must be handled purely on the client side. Toggling the state simply maps different keys from the downloaded JSON to the UI. It **must not** trigger a network request.
3. **Data Schema:** The app will parse the `Master Fact Sheet` JSON using Swift's `Codable` protocol based on the schema below.

---

## 4. AI Engine: Prompt & JSON Schema

### The System Prompt
This prompt should be stored in your Supabase Edge Function and passed to the LLM alongside the raw text of each fetched article.

> **System Prompt:**
> You are an elite Chief of Staff and Market Analyst summarizing news for a time-poor executive. Your goal is to extract high-signal information from the provided article and format it into strict JSON. You must not hallucinate or add outside information. 
> 
> You must populate data for three distinct reading modes:
> 1. **Universal Mode**: A standard 4-point impact breakdown.
> 2. **Topic-Specific Mode**: Dynamic headers tailored to whether the news is Finance, AI, or General Tech.
> 3. **Executive Mode**: An aggressively action-oriented summary.
>
> Analyze the provided article text and return ONLY a valid JSON object matching the required schema. Calculate a realistic reading time based on 250 words per minute.

### The JSON Schema
Use this schema to enforce structured outputs from the LLM and to build your Swift `Codable` models.

```json
{
  "type": "object",
  "properties": {
    "headline": {
      "type": "string",
      "description": "A crisp, engaging title for the news item."
    },
    "estimated_read_time_minutes": {
      "type": "integer",
      "description": "Estimated time to read the full original article."
    },
    "universal_mode": {
      "type": "object",
      "properties": {
        "gist": { "type": "string" },
        "ripple_effect": { "type": "string" },
        "personal_impact": { "type": "string" },
        "key_metric": { "type": "string" }
      }
    },
    "topic_specific_mode": {
      "type": "object",
      "properties": {
        "bullet_1_header": { "type": "string", "description": "e.g., 'The Market Move' or 'The Breakthrough'" },
        "bullet_1_text": { "type": "string" },
        "bullet_2_header": { "type": "string", "description": "e.g., 'Capital at Stake' or 'Timeline'" },
        "bullet_2_text": { "type": "string" },
        "bullet_3_header": { "type": "string" },
        "bullet_3_text": { "type": "string" }
      }
    },
    "executive_mode": {
      "type": "object",
      "properties": {
        "the_intel": { "type": "string" },
        "why_flagged": { "type": "string" },
        "open_questions": { "type": "string" },
        "decision_action": { "type": "string" }
      }
    }
  },
  "required": ["headline", "estimated_read_time_minutes", "universal_mode", "topic_specific_mode", "executive_mode"]
}
```
