// Full-text extraction. MVP version uses regex-based meta-tag + first-paragraph
// fallback — no DOM parser, no extra dependencies. Misses ~30% of cases
// (paywalls, SPA-rendered content, exotic markup) but the Claude prompt
// is designed to handle thin source material gracefully.
//
// Phase 2.5 upgrade: swap in @mozilla/readability + deno-dom for ~80%
// success rate. Tradeoff is +500ms cold start per Edge Function invocation.

import type { Candidate } from "./types.ts";

const MAX_BYTES = 1_500_000; // 1.5 MB cap — protects against giant home pages
const FETCH_TIMEOUT_MS = 8_000;

async function fetchHTML(url: string): Promise<string | null> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    try {
        const res = await fetch(url, {
            headers: {
                "user-agent":
                    "Mozilla/5.0 (compatible; Breeves/1.0; +https://breeves.app/bot)",
                accept: "text/html,*/*",
            },
            redirect: "follow",
            signal: controller.signal,
        });
        if (!res.ok) return null;
        const ct = res.headers.get("content-type") ?? "";
        if (!ct.includes("text/html")) return null;
        const buf = await res.arrayBuffer();
        if (buf.byteLength > MAX_BYTES) return null;
        return new TextDecoder("utf-8").decode(buf);
    } catch {
        return null;
    } finally {
        clearTimeout(timer);
    }
}

function decodeEntities(s: string): string {
    return s
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&nbsp;/g, " ")
        .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(parseInt(n, 10)));
}

function stripTags(html: string): string {
    return decodeEntities(
        html
            .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, " ")
            .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, " ")
            .replace(/<[^>]+>/g, " ")
            .replace(/\s+/g, " "),
    ).trim();
}

function metaContent(html: string, names: string[]): string | null {
    for (const name of names) {
        const re = new RegExp(
            `<meta[^>]+(?:name|property)\\s*=\\s*["']${name}["'][^>]+content\\s*=\\s*["']([^"']+)["']`,
            "i",
        );
        const m = html.match(re);
        if (m) return decodeEntities(m[1]).trim();

        // Some publishers reverse the attribute order
        const re2 = new RegExp(
            `<meta[^>]+content\\s*=\\s*["']([^"']+)["'][^>]+(?:name|property)\\s*=\\s*["']${name}["']`,
            "i",
        );
        const m2 = html.match(re2);
        if (m2) return decodeEntities(m2[1]).trim();
    }
    return null;
}

function firstParagraphs(html: string, max: number): string {
    const matches = html.match(/<p\b[^>]*>([\s\S]*?)<\/p>/gi);
    if (!matches) return "";
    const ps = matches
        .map((p) => stripTags(p))
        .filter((p) => p.length > 80) // skip nav/footer/social-share noise
        .slice(0, max);
    return ps.join("\n\n");
}

/// Extracts a best-effort article body from a candidate's URL. Populates
/// `body` in place and returns the same Candidate. Never throws.
export async function extractFullText(candidate: Candidate): Promise<Candidate> {
    if (candidate.body && candidate.body.length > 0) return candidate;

    const html = await fetchHTML(candidate.url);
    if (!html) {
        candidate.body = "";
        return candidate;
    }

    const description =
        metaContent(html, ["og:description", "twitter:description", "description"]) ?? "";
    const paragraphs = firstParagraphs(html, 12);

    // Combine: OG description → blank line → first ~12 paragraphs.
    // Cap total length so Claude calls stay reasonably bounded.
    const combined = [description, paragraphs].filter((s) => s.length > 0).join("\n\n");
    candidate.body = combined.slice(0, 12_000);
    return candidate;
}

/// Convenience for parallel extraction with a concurrency cap.
export async function extractAll(
    candidates: Candidate[],
    concurrency = 5,
): Promise<Candidate[]> {
    const results: Candidate[] = [];
    for (let i = 0; i < candidates.length; i += concurrency) {
        const batch = candidates.slice(i, i + concurrency);
        const extracted = await Promise.all(batch.map(extractFullText));
        results.push(...extracted);
    }
    return results;
}
