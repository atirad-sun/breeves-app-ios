# News source dispatcher — MVP

## Decision

For the v2 MVP we ship **keyless-only sources** (Hacker News Algolia + GDELT 2.0). NYT, Guardian, and Reddit dispatchers are stubbed but gated off until we have API keys.

## Rationale

- **Zero blocked dependencies.** No API key signups, no per-source rate-limit accounts. Ships end-to-end same day.
- **Coverage is "good enough".** HN Algolia is excellent for AI/tech/companies (the topics most early users will pick); GDELT covers global events including geopolitics, climate, defense. The pairing handles ~80% of the topic taxonomy in [TopicSelectionContent.swift](../../../Breeves/Features/Onboarding/TopicSelectionContent.swift) without help.
- **Quota headroom.** Both sources are effectively unlimited at our scale. HN Algolia caps around 10k requests/hour unofficially; GDELT has no documented cap. At 1k DAU × 18 articles × 10 candidate fetches = 180k req/day spread across both, neither hits a wall.
- **Reversible.** When NYT and Guardian keys arrive, we flip a feature gate in `dispatcher.ts` and the new sources start contributing candidates without touching downstream code.

## Per-topic dispatcher (MVP)

| Topic family | Primary source | Secondary | When secondary lands |
|---|---|---|---|
| AI / Tech / specific companies (NVIDIA, Apple, SpaceX) | HN Algolia | The Verge RSS | Phase 2.5 |
| Finance / Markets / Real Estate | GDELT (filtered for `themes:ECON_*`) | NYT Article Search (`desk:Business`) | when `NYT_API_KEY` present |
| Geopolitics / Defense | GDELT (filtered for `themes:CRISISLEX_*` + top-50 sources) | Guardian World API | when `GUARDIAN_API_KEY` present |
| Climate | GDELT (filtered for `themes:ENV_CLIMATECHANGE`) | Guardian Environment API | when `GUARDIAN_API_KEY` present |
| Crypto | HN Algolia (`tags=story&query=<topic>`) | Reddit `/r/CryptoCurrency` JSON | when comfortable with Reddit's user-agent rules |
| Biotech | HN Algolia | Reddit `/r/biotech` | Phase 2.5 |
| Custom / fallback | HN Algolia + GDELT (parallel, deduped) | — | — |

Both primary sources are queried in parallel for every topic; results are merged, URL-canonicalized, and deduped on a 0.85 cosine-similarity threshold against the headline before ranking.

## Module layout for [_shared/news/](.)

```
_shared/news/
  hn.ts             searchHN(query, limit) → Candidate[]      ← MVP
  gdelt.ts          searchGDELT(query, themeFilter, limit)    ← MVP
  nyt.ts            searchNYT(query, desk, limit)             ← stub, gated on NYT_API_KEY
  guardian.ts       searchGuardian(query, section, limit)     ← stub, gated on GUARDIAN_API_KEY
  reddit.ts         searchReddit(subreddit, limit)            ← stub, gated on a feature flag
  rss.ts            fetchRSS(url, limit)                       ← stub
  dispatcher.ts     selectSourcesForTopic(topic) → Source[]
                    fetchCandidates(topic) → Candidate[]
  extract.ts        extractFullText(url) → string             ← Mozilla Readability
  types.ts          interface Candidate { url, headline,
                                          source, publishedAt,
                                          body? }
```

## Candidate type (shared)

```ts
export interface Candidate {
  url: string;            // canonical URL after redirect resolution
  headline: string;
  source: string;         // "Hacker News" | "GDELT (Reuters)" | etc.
  publishedAt: string;    // ISO 8601, UTC
  body?: string;          // populated by extract.ts; may be empty if extraction fails
}
```

## What ships in Step 3

- `hn.ts` — real implementation against `https://hn.algolia.com/api/v1/search`.
- `gdelt.ts` — real implementation against `https://api.gdeltproject.org/api/v2/doc/doc`.
- `dispatcher.ts` — full per-topic dispatch table above; gated sources return `[]` until their key is set, so they slot in cleanly later.
- `extract.ts` — Readability-based full-text extraction with OG-description fallback when extraction fails (paywalls, SPA-heavy sites).
- `nyt.ts`, `guardian.ts`, `reddit.ts`, `rss.ts` — interface skeletons only, returning `[]` and logging "source disabled".

That's enough to swap the fixture lookup in `generate_daily_briefing/index.ts` for real fetches in Step 3 + Step 4.
