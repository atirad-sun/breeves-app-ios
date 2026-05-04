// Per-topic source dispatcher — fans queries out across configured sources,
// merges and dedupes results, returns ranked Candidate[].
//
// MVP: HN + GDELT only. NYT/Guardian/Reddit slot in transparently when
// their env-keys land (each source self-gates via NewsSource.enabled).

import type { Candidate, NewsSource } from "./types.ts";
import { hnSource } from "./hn.ts";
import { gdeltSource } from "./gdelt.ts";
import { nytSource } from "./nyt.ts";
import { guardianSource } from "./guardian.ts";
import { redditSource } from "./reddit.ts";

// Per-topic source family preference. Topics not in this map use the
// `default` row. Family names map to NewsSource arrays via FAMILY_SOURCES.
const TOPIC_FAMILIES: Record<string, string> = {
    "ai": "tech",
    "tech": "tech",
    "nvidia": "tech",
    "apple": "tech",
    "spacex": "tech",

    "finance": "finance",
    "markets": "finance",
    "real estate": "finance",

    "geopolitics": "geopolitics",
    "defense": "geopolitics",
    "climate": "geopolitics",

    "crypto": "tech",
    "biotech": "tech",
};

const FAMILY_SOURCES: Record<string, NewsSource[]> = {
    tech: [hnSource, gdeltSource, redditSource],
    finance: [nytSource, gdeltSource],
    geopolitics: [gdeltSource, guardianSource],
    default: [hnSource, gdeltSource],
};

export function selectSourcesForTopic(topic: string): NewsSource[] {
    const family = TOPIC_FAMILIES[topic.trim().toLowerCase()] ?? "default";
    return (FAMILY_SOURCES[family] ?? FAMILY_SOURCES.default).filter((s) => s.enabled);
}

/// Drop scheme/www/trailing-slash variation so the same article from two
/// surfaces dedupes cleanly. Exported so cross-day history dedup (in the
/// edge functions) keys on the same canonical form as intra-briefing dedup.
export function canonicalUrl(url: string): string {
    try {
        const u = new URL(url);
        const host = u.hostname.replace(/^www\./, "");
        const path = u.pathname.replace(/\/+$/, "");
        return `${host}${path}`;
    } catch {
        return url;
    }
}

/// Fast headline-similarity check: Jaccard over lowercased word-sets, with
/// a 0.6+ threshold flagging duplicates. Cheaper than cosine and good
/// enough for "same news, different outlet".
function headlineSimilar(a: string, b: string): boolean {
    const tokenize = (s: string) =>
        new Set(
            s
                .toLowerCase()
                .replace(/[^\w\s]/g, " ")
                .split(/\s+/)
                .filter((t) => t.length > 3),
        );
    const aT = tokenize(a);
    const bT = tokenize(b);
    if (aT.size === 0 || bT.size === 0) return false;
    let intersection = 0;
    for (const t of aT) if (bT.has(t)) intersection++;
    const union = aT.size + bT.size - intersection;
    return intersection / union >= 0.6;
}

export interface SeenSet {
    /// Canonical URLs already shown to this user in the dedup window.
    urls: Set<string>;
    /// Headlines already shown — used for fuzzy-match dedup since two
    /// outlets covering the same story have different URLs.
    headlines: string[];
}

/// Dedupe by canonical URL first, then by headline similarity. Stable
/// ordering: earlier candidates win. When `alreadySeen` is supplied,
/// candidates matching anything in it are also dropped — this is how
/// cross-day dedup (against the briefing_articles history table) lands
/// in the same code path as intra-briefing dedup.
export function dedupe(candidates: Candidate[], alreadySeen?: SeenSet): Candidate[] {
    const out: Candidate[] = [];
    const seenUrls = new Set<string>(alreadySeen?.urls ?? []);
    const seenHeadlines: string[] = [...(alreadySeen?.headlines ?? [])];
    for (const c of candidates) {
        const key = canonicalUrl(c.url);
        if (seenUrls.has(key)) continue;
        if (seenHeadlines.some((h) => headlineSimilar(h, c.headline))) continue;
        seenUrls.add(key);
        seenHeadlines.push(c.headline);
        out.push(c);
    }
    return out;
}

/// Fan out to all configured sources for a topic, merge + dedupe results.
/// Each source has its own try/catch — one failing source never sinks the
/// dispatch.
export async function fetchCandidates(
    topic: string,
    perSourceLimit = 12,
    alreadySeen?: SeenSet,
): Promise<Candidate[]> {
    const sources = selectSourcesForTopic(topic);
    if (sources.length === 0) {
        console.warn(`No enabled sources for topic "${topic}"`);
        return [];
    }

    const settled = await Promise.allSettled(
        sources.map((s) => s.search(topic, perSourceLimit)),
    );

    const all: Candidate[] = [];
    for (const r of settled) {
        if (r.status === "fulfilled") all.push(...r.value);
    }

    return dedupe(all, alreadySeen);
}

/// Rank candidates by a heuristic blend: published-recency × source-quality.
/// MVP: just recency (newer first). Step 4 may add source-weighting once
/// we know which outlets land in production briefings.
export function rankAndPick(candidates: Candidate[], n: number): Candidate[] {
    const sorted = [...candidates].sort((a, b) => {
        const at = Date.parse(a.publishedAt) || 0;
        const bt = Date.parse(b.publishedAt) || 0;
        return bt - at;
    });
    return sorted.slice(0, n);
}

/// Drop candidates older than `maxAgeHours` relative to `now`. Also drops
/// candidates whose publishedAt fails to parse — better to lose them than
/// treat unparseable timestamps as "now" and serve old news.
export function filterFresh(
    candidates: Candidate[],
    maxAgeHours: number,
    now: Date = new Date(),
): Candidate[] {
    const cutoff = now.getTime() - maxAgeHours * 3600 * 1000;
    return candidates.filter((c) => {
        const t = Date.parse(c.publishedAt);
        if (Number.isNaN(t)) return false;
        return t >= cutoff;
    });
}
