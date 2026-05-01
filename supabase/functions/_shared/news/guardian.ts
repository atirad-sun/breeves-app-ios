// The Guardian Open Platform — disabled until GUARDIAN_API_KEY lands.
// When wired, hits https://content.guardianapis.com/search
// — free dev tier: 5k requests/day. Best for global politics, climate.

import type { Candidate, NewsSource } from "./types.ts";

const KEY = Deno.env.get("GUARDIAN_API_KEY") ?? "";

export async function searchGuardian(_query: string, _limit: number): Promise<Candidate[]> {
    if (!KEY) {
        console.info("Guardian source disabled (no GUARDIAN_API_KEY)");
        return [];
    }
    // TODO Phase 2.5: real implementation.
    // Endpoint: https://content.guardianapis.com/search
    // Params: q=<query>, section=<section>, api-key=<KEY>,
    //         order-by=newest, show-fields=headline,trailText,bodyText
    // Map response.results[] → Candidate (headline, webUrl, webPublicationDate)
    return [];
}

export const guardianSource: NewsSource = {
    name: "guardian",
    get enabled() {
        return KEY.length > 0;
    },
    search: searchGuardian,
};
