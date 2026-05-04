// GDELT 2.0 Doc API — global news, real-time event indexing. Free, keyless.
// Best for geopolitics, defense, climate, finance — broad worldwide coverage,
// somewhat noisy. Use the source-domain whitelist below to filter for
// editorial-grade outlets.

import type { Candidate, NewsSource } from "./types.ts";

const ENDPOINT = "https://api.gdeltproject.org/api/v2/doc/doc";

// Top 50-ish editorial-grade English-language sources. GDELT indexes
// thousands of outlets; filtering to this list dramatically improves
// signal/noise on raw queries.
const QUALITY_DOMAINS = [
    "reuters.com",
    "ft.com",
    "bloomberg.com",
    "wsj.com",
    "nytimes.com",
    "washingtonpost.com",
    "theguardian.com",
    "bbc.com",
    "bbc.co.uk",
    "economist.com",
    "apnews.com",
    "axios.com",
    "politico.com",
    "foreignpolicy.com",
    "defenseone.com",
    "defensenews.com",
    "warontherocks.com",
    "csis.org",
    "rand.org",
    "brookings.edu",
    "cfr.org",
    "carnegieendowment.org",
    "aljazeera.com",
    "japantimes.co.jp",
    "scmp.com",
    "nikkei.com",
    "lemonde.fr",
    "spiegel.de",
    "ft.com",
    "cnbc.com",
    "marketwatch.com",
    "barrons.com",
    "theverge.com",
    "techcrunch.com",
    "wired.com",
    "arstechnica.com",
    "stratechery.com",
    "spacenews.com",
    "scientificamerican.com",
    "nature.com",
    "science.org",
    "newscientist.com",
    "climatehome.com",
    "carbonbrief.org",
];

interface GdeltArticle {
    url: string;
    url_mobile?: string;
    title: string;
    seendate: string; // YYYYMMDDTHHMMSSZ format
    socialimage?: string;
    domain: string;
    language: string;
    sourcecountry?: string;
}

interface GdeltResponse {
    articles?: GdeltArticle[];
}

function parseGdeltDate(s: string): string | null {
    // GDELT format: 20260315T143000Z → 2026-03-15T14:30:00Z. Returns
    // null on malformed input so the candidate gets dropped rather than
    // backfilled with fetch-time (which is how years-old articles ended
    // up tagged as "today" in earlier briefings).
    if (s.length < 15) return null;
    const yyyy = s.slice(0, 4);
    const mm = s.slice(4, 6);
    const dd = s.slice(6, 8);
    const HH = s.slice(9, 11);
    const MM = s.slice(11, 13);
    const SS = s.slice(13, 15);
    const iso = `${yyyy}-${mm}-${dd}T${HH}:${MM}:${SS}Z`;
    return Number.isNaN(Date.parse(iso)) ? null : iso;
}

const QUALITY_DOMAIN_SET = new Set(QUALITY_DOMAINS);

// GDELT throttles to roughly 1 request per 5 seconds per IP and serves a
// plaintext "Please limit requests to one every 5 seconds" body on violation.
// In production each user's briefing has at most 3 topics, processed
// sequentially with the Claude call between, so this rarely matters — but
// the dispatcher smoke and any back-to-back topic fans-out can hit it.
// Self-throttle: track the last request and sleep if the last one was less
// than 5s ago.
const MIN_GAP_MS = 5_000;
let lastRequestAt = 0;

async function gdeltGate() {
    const wait = lastRequestAt + MIN_GAP_MS - Date.now();
    if (wait > 0) await new Promise((r) => setTimeout(r, wait));
    lastRequestAt = Date.now();
}

export async function searchGDELT(query: string, limit: number): Promise<Candidate[]> {
    // GDELT requires ≥3-char keywords. Expand obvious short topics so we
    // don't get a "keyword too short" rejection. Once Phase 2 Step 6 (topic
    // canonicalization via Haiku) is in place, this is largely moot — the
    // canonical name is already long.
    if (query.length < 3) {
        const expanded: Record<string, string> = {
            "ai": "artificial intelligence",
        };
        query = expanded[query.toLowerCase()] ?? query;
        if (query.length < 3) {
            console.info(`GDELT skipping short query "${query}"`);
            return [];
        }
    }

    // GDELT's query parser rejects nested parens (returns "Parentheses..."
    // error) and throttles long queries hard. Keep it minimal: free-text
    // query plus sourcelang:eng. Filter for editorial-grade outlets
    // client-side via QUALITY_DOMAIN_SET below.
    const fullQuery = `${query} sourcelang:eng`;

    const params = new URLSearchParams({
        query: fullQuery,
        mode: "ArtList",
        format: "json",
        // Last 24h. GDELT updates every 15 min so this is fresh.
        timespan: "24h",
        // Pull more than we need — client-side domain filter will trim.
        maxrecords: String(Math.min(limit * 6, 100)),
        sort: "hybridrel",
    });

    let json: GdeltResponse;
    try {
        await gdeltGate();
        const res = await fetch(`${ENDPOINT}?${params}`, {
            headers: { "user-agent": "Breeves/1.0 (briefing-bot)" },
        });
        // GDELT returns plaintext error bodies (with various 4xx/200 statuses)
        // when the query itself is malformed — read as text first either way.
        const text = await res.text();
        if (!res.ok) {
            console.warn(`GDELT search ${res.status} for "${query}": ${text.slice(0, 200)}`);
            return [];
        }
        if (!text.trim()) return [];
        // If GDELT didn't actually return JSON, surface the body so the
        // failure mode is visible.
        if (!text.trimStart().startsWith("{")) {
            console.warn(`GDELT non-JSON response for "${query}": ${text.slice(0, 200)}`);
            return [];
        }
        json = JSON.parse(text);
    } catch (err) {
        console.warn(`GDELT search failed for "${query}": ${(err as Error).message}`);
        return [];
    }

    if (!json.articles) return [];

    const filtered = json.articles
        .filter((a) => a.url && a.title)
        .filter((a) => {
            const domain = a.domain.replace(/^www\./, "").toLowerCase();
            return QUALITY_DOMAIN_SET.has(domain);
        });

    return filtered
        .map((a) => {
            const publishedAt = parseGdeltDate(a.seendate);
            if (!publishedAt) return null;
            return {
                url: a.url,
                headline: a.title,
                source: `GDELT (${a.domain})`,
                publishedAt,
            };
        })
        .filter((c): c is Candidate => c !== null)
        .slice(0, limit);
}

export const gdeltSource: NewsSource = {
    name: "gdelt",
    enabled: true,
    search: searchGDELT,
};
