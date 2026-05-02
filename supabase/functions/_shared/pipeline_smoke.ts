// Smoke test for the live briefing pipeline.
//
// Runs the full flow (dispatcher → extract → Claude) against three
// representative topics, prints token usage and cache hit rate, and
// exits non-zero if any topic returned zero articles.
//
// Run:
//   ANTHROPIC_API_KEY=... deno run \
//     --allow-net --allow-read --allow-env \
//     supabase/functions/_shared/pipeline_smoke.ts
//
// Cleanup: this script is local-only — never imported by Edge Functions.
// Delete or move to /scripts/ if it survives Phase 2 close-out.

import { runBriefingPipeline } from "./pipeline.ts";

const TOPICS = ["AI", "Finance", "Geopolitics"];

async function main() {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
        console.error("ANTHROPIC_API_KEY not set");
        Deno.exit(2);
    }

    const today = new Date().toISOString().slice(0, 10);
    const t0 = Date.now();
    const { results, totalUsage } = await runBriefingPipeline(TOPICS, apiKey, today);
    const elapsed = ((Date.now() - t0) / 1000).toFixed(1);

    console.log();
    console.log(`Pipeline finished in ${elapsed}s`);
    for (const r of results) {
        console.log(
            `  ${r.topic.padEnd(14)} ${r.articles.length} articles, ` +
                `${r.droppedCount} dropped, ` +
                `cache_read=${r.usage.cache_read_tokens}`,
        );
        for (const a of r.articles.slice(0, 2)) {
            console.log(`    • ${a.headline.slice(0, 80)}`);
        }
    }

    const cacheBase = totalUsage.cache_creation_tokens + totalUsage.cache_read_tokens;
    const ratio = cacheBase > 0 ? totalUsage.cache_read_tokens / cacheBase : 0;
    console.log();
    console.log(`Total: in=${totalUsage.input_tokens} out=${totalUsage.output_tokens}`);
    console.log(`Cache: write=${totalUsage.cache_creation_tokens} read=${totalUsage.cache_read_tokens}`);
    console.log(`Cache hit rate: ${(ratio * 100).toFixed(1)}% (target ≥90%)`);

    const empty = results.filter((r) => r.articles.length === 0);
    if (empty.length > 0) {
        console.error(`\n${empty.length} topic(s) returned zero articles:`);
        for (const r of empty) console.error(`  - ${r.topic}`);
        Deno.exit(1);
    }
    console.log(`\nAll ${TOPICS.length} topics produced articles.`);
}

await main();
