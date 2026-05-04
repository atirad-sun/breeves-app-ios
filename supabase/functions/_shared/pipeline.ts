// End-to-end briefing pipeline: topic → candidates → ranked → extracted →
// summarized → schema-shaped articles ready for upsert into daily_briefings.
//
// Used by both the on-demand `generate_daily_briefing` Edge Function and
// the timezone-tick cron (Phase 2 Step 5). Centralized here so source
// selection, rank order, and summarization stay consistent across entry
// points.

import { fetchCandidates, rankAndPick, filterFresh, type SeenSet } from "./news/dispatcher.ts";
import { extractAll } from "./news/extract.ts";
import { summarizeWithClaude } from "./llm/anthropic.ts";
import type { Candidate } from "./news/types.ts";

export type { SeenSet } from "./news/dispatcher.ts";

/// Final per-article shape persisted into daily_briefings.payload. Keys
/// are snake_case to match the JSONDecoder.briefing convention used by
/// the iOS Article Codable struct.
export interface PipelineArticle {
    id: string;
    headline: string;
    estimated_read_time_minutes: number;
    source: string;
    /// Original article URL on the publisher's site. Powers the "Read full"
    /// link in the iOS card footer.
    url: string;
    universal_mode: {
        gist: string;
        ripple_effect: string;
        personal_impact: string;
        key_metric: string;
    };
    topic_specific_mode: {
        bullet_1_header: string;
        bullet_1_text: string;
        bullet_2_header: string;
        bullet_2_text: string;
        bullet_3_header: string;
        bullet_3_text: string;
    };
    executive_mode: {
        the_intel: string;
        why_flagged: string;
        open_questions: string;
        decision_action: string;
    };
}

export interface PipelineUsage {
    input_tokens: number;
    output_tokens: number;
    cache_creation_tokens: number;
    cache_read_tokens: number;
}

export interface PipelineResult {
    topic: string;
    articles: PipelineArticle[];
    usage: PipelineUsage;
    droppedCount: number;
}

/// Maximum articles per topic. Variable: a topic may produce fewer if
/// freshness/dedup gates eliminate weaker candidates. Padding to 6
/// regardless would dilute the brief with low-quality picks.
const MAX_ARTICLES_PER_TOPIC = 6;

/// Drop articles older than this. Sources also self-filter (HN by
/// numericFilters, GDELT by timespan), but post-extract verification
/// catches articles whose source-API timestamp lied (e.g. "indexed today"
/// for an article that's actually years old). 36h leaves a small buffer
/// for next-morning briefings while keeping content genuinely fresh.
const MAX_ARTICLE_AGE_HOURS = 36;

/// Slugify a headline + topic into a stable, human-readable id. The
/// briefing-day prefix prevents collisions across daily upserts. Matches
/// the shape of the canned-fixture ids ("ai-1", "finance-2") loosely so
/// existing client UI doesn't choke.
function makeId(topic: string, headline: string, dateISO: string, idx: number): string {
    const slug = (s: string) =>
        s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 40);
    return `${dateISO}-${slug(topic)}-${idx + 1}-${slug(headline)}`.slice(0, 120);
}

/// Run a single topic end-to-end. Each candidate is summarized
/// concurrently up to `concurrency` at a time. Failures are logged and
/// dropped — never thrown — so one bad article doesn't sink the topic.
export async function runTopicPipeline(
    topic: string,
    apiKey: string,
    dateISO: string,
    options: { concurrency?: number; alreadySeen?: SeenSet } = {},
): Promise<PipelineResult> {
    const concurrency = options.concurrency ?? 4;
    const alreadySeen = options.alreadySeen;
    const usage: PipelineUsage = {
        input_tokens: 0,
        output_tokens: 0,
        cache_creation_tokens: 0,
        cache_read_tokens: 0,
    };

    console.log(`pipeline: [${topic}] fetching candidates…`);
    const allCandidates = await fetchCandidates(topic, 18, alreadySeen);
    if (allCandidates.length === 0) {
        console.warn(`pipeline: [${topic}] no candidates`);
        return { topic, articles: [], usage, droppedCount: 0 };
    }
    console.log(`pipeline: [${topic}] got ${allCandidates.length} candidates`);

    // Pre-extract freshness pass: drop anything the source timestamps
    // already mark as too old. Saves wasted HTML fetches on candidates
    // we'd just throw away.
    const preFresh = filterFresh(allCandidates, MAX_ARTICLE_AGE_HOURS);
    if (preFresh.length < allCandidates.length) {
        console.log(
            `pipeline: [${topic}] dropped ${allCandidates.length - preFresh.length} stale candidates pre-extract`,
        );
    }
    if (preFresh.length === 0) {
        console.warn(`pipeline: [${topic}] no fresh candidates`);
        return { topic, articles: [], usage, droppedCount: 0 };
    }

    // Take a generous top slice for extraction — extract.ts can rewrite
    // publishedAt from the page's own meta, so we may still drop more
    // here. Pulling 2× the target gives the post-extract gate room to
    // breathe before we trim to MAX_ARTICLES_PER_TOPIC.
    const extractionPool: Candidate[] = rankAndPick(preFresh, MAX_ARTICLES_PER_TOPIC * 2);
    console.log(`pipeline: [${topic}] extracting top ${extractionPool.length}…`);
    const extracted = await extractAll(extractionPool, concurrency);

    // Post-extract freshness pass: extract.ts may have corrected a
    // candidate's publishedAt by reading the page's own meta tags, so
    // re-apply the gate. Catches articles whose source-API listing said
    // "today" but the article itself was actually years old.
    const postFresh = filterFresh(extracted, MAX_ARTICLE_AGE_HOURS);
    if (postFresh.length < extracted.length) {
        console.log(
            `pipeline: [${topic}] dropped ${extracted.length - postFresh.length} stale candidates post-extract`,
        );
    }
    const finalPool = rankAndPick(postFresh, MAX_ARTICLES_PER_TOPIC);
    if (finalPool.length === 0) {
        console.warn(`pipeline: [${topic}] no fresh candidates after extract`);
        return { topic, articles: [], usage, droppedCount: 0 };
    }
    console.log(`pipeline: [${topic}] summarizing ${finalPool.length} with Claude…`);

    // Summarize with bounded concurrency. Settled-not-all so one bad
    // candidate (paywall + Claude rejecting "(Full text unavailable...)" or
    // a transient 5xx) never sinks the topic.
    const articles: PipelineArticle[] = [];
    let dropped = 0;
    for (let i = 0; i < finalPool.length; i += concurrency) {
        const batch = finalPool.slice(i, i + concurrency);
        const settled = await Promise.allSettled(
            batch.map((c) => summarizeWithClaude(c, topic, apiKey)),
        );
        settled.forEach((r, j) => {
            const c = batch[j];
            if (r.status !== "fulfilled") {
                dropped++;
                console.warn(
                    `pipeline: dropped "${c.headline}" — ${(r.reason as Error).message}`,
                );
                return;
            }
            const a = r.value.article;
            const u = r.value.usage;
            usage.input_tokens += u.input_tokens;
            usage.output_tokens += u.output_tokens;
            usage.cache_creation_tokens += u.cache_creation_input_tokens ?? 0;
            usage.cache_read_tokens += u.cache_read_input_tokens ?? 0;

            articles.push({
                id: makeId(topic, a.headline, dateISO, articles.length),
                headline: a.headline,
                estimated_read_time_minutes: a.estimated_read_time_minutes,
                source: c.source,
                url: c.url,
                universal_mode: a.universal_mode,
                topic_specific_mode: a.topic_specific_mode,
                executive_mode: a.executive_mode,
            });
        });
    }

    return { topic, articles, usage, droppedCount: dropped };
}

/// Run multiple topics serially. Serial is intentional — Claude's prompt
/// cache hit rate is highest when calls land back-to-back inside the
/// 5-minute ephemeral window, and parallel topics can blow past per-key
/// rate limits. With 3 topics × 6 articles, this is ~18 sequential Claude
/// calls — well under a 60s function budget at ~2s each.
export async function runBriefingPipeline(
    topics: string[],
    apiKey: string,
    dateISO: string,
    options: { alreadySeen?: SeenSet } = {},
): Promise<{ results: PipelineResult[]; totalUsage: PipelineUsage }> {
    const results: PipelineResult[] = [];
    const totalUsage: PipelineUsage = {
        input_tokens: 0,
        output_tokens: 0,
        cache_creation_tokens: 0,
        cache_read_tokens: 0,
    };

    for (const topic of topics) {
        const r = await runTopicPipeline(topic, apiKey, dateISO, { alreadySeen: options.alreadySeen });
        results.push(r);
        totalUsage.input_tokens += r.usage.input_tokens;
        totalUsage.output_tokens += r.usage.output_tokens;
        totalUsage.cache_creation_tokens += r.usage.cache_creation_tokens;
        totalUsage.cache_read_tokens += r.usage.cache_read_tokens;
    }

    const cacheBase = totalUsage.cache_creation_tokens + totalUsage.cache_read_tokens;
    const cacheRatio = cacheBase > 0 ? totalUsage.cache_read_tokens / cacheBase : 0;
    console.log(
        `pipeline: ${results.length} topics, ` +
            `${results.reduce((n, r) => n + r.articles.length, 0)} articles, ` +
            `cache_read=${totalUsage.cache_read_tokens} cache_write=${totalUsage.cache_creation_tokens} ` +
            `hit_rate=${(cacheRatio * 100).toFixed(1)}%`,
    );

    return { results, totalUsage };
}
