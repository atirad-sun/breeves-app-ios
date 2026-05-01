// NYT Article Search — disabled until NYT_API_KEY lands.
// When wired, hits https://api.nytimes.com/svc/search/v2/articlesearch.json
// — free tier: 4k requests/day, 5/min. Best for finance/business and
// geopolitics with editorial weight.

import type { Candidate, NewsSource } from "./types.ts";

const KEY = Deno.env.get("NYT_API_KEY") ?? "";

export async function searchNYT(_query: string, _limit: number): Promise<Candidate[]> {
    if (!KEY) {
        console.info("NYT source disabled (no NYT_API_KEY)");
        return [];
    }
    // TODO Phase 2.5: real implementation.
    // Endpoint: https://api.nytimes.com/svc/search/v2/articlesearch.json
    // Params: q=<query>, fq=desk:("Business"|"Foreign"|"Tech"), api-key=<KEY>,
    //         sort=newest, page=0
    // Map response[].response.docs[] → Candidate
    return [];
}

export const nytSource: NewsSource = {
    name: "nyt",
    get enabled() {
        return KEY.length > 0;
    },
    search: searchNYT,
};
