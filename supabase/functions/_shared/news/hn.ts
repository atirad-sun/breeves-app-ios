// Hacker News via Algolia search. Free, keyless, ~10k req/hr unofficial cap.
// Best for AI / Tech / specific companies (NVIDIA, Apple, SpaceX).

import type { Candidate, NewsSource } from "./types.ts";

const ENDPOINT = "https://hn.algolia.com/api/v1/search";

interface AlgoliaHit {
    objectID: string;
    title: string | null;
    url: string | null;
    author: string | null;
    points: number | null;
    num_comments: number | null;
    created_at: string | null;
}

interface AlgoliaResponse {
    hits: AlgoliaHit[];
    nbHits?: number;
}

export async function searchHN(query: string, limit: number): Promise<Candidate[]> {
    // Algolia takes a unix-second cutoff. Match the dispatcher's
    // freshness gate (36h) so HN's default ordering can't smuggle in
    // older highly-upvoted posts that drown out genuinely fresh stories.
    const cutoff = Math.floor((Date.now() - 36 * 3600 * 1000) / 1000);

    const params = new URLSearchParams({
        query,
        tags: "story",
        // Bias toward higher-quality posts; HN signal is messy without this.
        // created_at_i is HN's unix-second post timestamp.
        numericFilters: `points>=20,created_at_i>${cutoff}`,
        hitsPerPage: String(Math.min(limit * 3, 50)),
    });

    let json: AlgoliaResponse;
    try {
        const res = await fetch(`${ENDPOINT}?${params}`, {
            headers: { "user-agent": "Breeves/1.0 (briefing-bot)" },
        });
        if (!res.ok) {
            console.warn(`HN search ${res.status} for "${query}"`);
            return [];
        }
        json = await res.json();
    } catch (err) {
        console.warn(`HN search failed for "${query}": ${(err as Error).message}`);
        return [];
    }

    return json.hits
        .filter((h) => h.url && h.title && h.created_at)
        .map((h) => ({
            url: h.url!,
            headline: h.title!,
            source: "Hacker News",
            // Real timestamp only — backfilling with fetch-time is how
            // stale posts get smuggled past the freshness gate.
            publishedAt: h.created_at!,
        }))
        .slice(0, limit);
}

export const hnSource: NewsSource = {
    name: "hn",
    enabled: true,
    search: searchHN,
};
