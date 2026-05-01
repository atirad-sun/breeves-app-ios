// Generic RSS / Atom fetcher — stub.
//
// Used in Phase 2.5 for outlets that don't expose APIs (Stratechery, The Verge,
// Bloomberg, Reuters direct feeds). Disabled by default — the dispatcher
// doesn't call into here yet.

import type { Candidate } from "./types.ts";

export async function fetchRSS(_url: string, _limit: number): Promise<Candidate[]> {
    // TODO Phase 2.5: parse RSS/Atom XML and map item[] → Candidate.
    // Use a small, dependency-free parser (DOMParser via deno-dom, or a
    // hand-rolled regex-based approach for the limited shapes we'll hit).
    return [];
}
