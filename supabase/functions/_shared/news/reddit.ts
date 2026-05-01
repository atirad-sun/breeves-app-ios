// Reddit JSON API — disabled by default. Reddit's user-agent rules and
// recent API changes make unauthenticated access fragile in production;
// gate this on REDDIT_USER_AGENT being set so it's an explicit opt-in.
//
// When wired, hits https://www.reddit.com/r/<sub>/hot.json — keyless but
// rate-limited at ~60 req/min unauth. Best for AI/Crypto/Biotech zeitgeist.

import type { Candidate, NewsSource } from "./types.ts";

const USER_AGENT = Deno.env.get("REDDIT_USER_AGENT") ?? "";

export async function searchReddit(_subreddit: string, _limit: number): Promise<Candidate[]> {
    if (!USER_AGENT) {
        console.info("Reddit source disabled (no REDDIT_USER_AGENT)");
        return [];
    }
    // TODO Phase 2.5: real implementation.
    // Endpoint: https://www.reddit.com/r/<subreddit>/hot.json?limit=<limit>
    // Headers: { "user-agent": USER_AGENT }
    // Map response.data.children[] (where data.url is external, not self.posts) → Candidate
    return [];
}

export const redditSource: NewsSource = {
    name: "reddit",
    get enabled() {
        return USER_AGENT.length > 0;
    },
    search: searchReddit,
};
