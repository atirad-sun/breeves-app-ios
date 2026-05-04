// Breeves — generate_daily_briefing Edge Function (v3, idempotent + history).
//
// Reads the caller's 3 topics, runs the live pipeline (news fetch →
// extract → Claude summarization with prompt caching) and upserts the
// result into daily_briefings. If ANTHROPIC_API_KEY is unset OR a topic's
// pipeline returns zero articles (no candidates, all summarizations
// failed), falls back to the canned fixture for that topic so the client
// still receives a valid briefing.
//
// Idempotency: a request without ?force=true short-circuits when a
// briefing already exists for (user, today). This protects against cold
// launches racing into the function and burning Claude tokens to
// regenerate work that was already cached. The iOS refresh button sets
// ?force=true to bypass.
//
// History: every generated article is inserted into briefing_articles
// (deduped by canonical_url per user). Powers cross-day dedup and
// preserves articles even when daily_briefings.payload is overwritten
// by a refresh.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'
// deno-lint-ignore-file no-explicit-any

import aiFixture from './fixtures/ai.json' with { type: 'json' }
import financeFixture from './fixtures/finance.json' with { type: 'json' }
import geopoliticsFixture from './fixtures/geopolitics.json' with { type: 'json' }
import defaultFixture from './fixtures/default.json' with { type: 'json' }

import { runTopicPipeline, type PipelineArticle, type SeenSet } from '../_shared/pipeline.ts'
import { canonicalUrl } from '../_shared/news/dispatcher.ts'

/// Number of days back to dedup against. An article that appeared in
/// the user's brief in the last week is considered "already seen" and
/// won't be re-surfaced — preventing yesterday's news from showing up
/// today.
const HISTORY_LOOKBACK_DAYS = 7

const FIXTURES: Record<string, any[]> = {
  ai: aiFixture,
  finance: financeFixture,
  geopolitics: geopoliticsFixture,
}

function fixtureFor(topicName: string): any[] {
  const key = topicName.trim().toLowerCase()
  if (FIXTURES[key]) return FIXTURES[key]
  return (defaultFixture as any[]).map((a, i) => ({
    ...a,
    id: `${key.replace(/\s+/g, '-')}-${i + 1}`,
    headline: a.headline.replace('{{topic}}', topicName),
  }))
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return new Response(JSON.stringify({ error: 'no auth' }), { status: 401 })

    const url = new URL(req.url)
    const force = url.searchParams.get('force') === 'true'

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: { user }, error: userErr } = await userClient.auth.getUser()
    if (userErr || !user) return new Response(JSON.stringify({ error: 'invalid user' }), { status: 401 })

    const today = new Date().toISOString().slice(0, 10)

    // Idempotency: if today's briefing already exists and the caller
    // didn't ask for a forced refresh, return early. Avoids burning
    // Claude tokens on cold-launch races and accidental retries.
    if (!force) {
      const { data: existing } = await supabase
        .from('daily_briefings')
        .select('briefing_date')
        .eq('user_id', user.id)
        .eq('briefing_date', today)
        .maybeSingle()
      if (existing) {
        return new Response(
          JSON.stringify({ ok: true, cached: true, date: today }),
          { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } },
        )
      }
    }

    const { data: topics, error: topicsErr } = await supabase
      .from('user_topics')
      .select('topic, slot')
      .eq('user_id', user.id)
      .order('slot')

    if (topicsErr) throw topicsErr
    if (!topics || topics.length === 0) {
      return new Response(JSON.stringify({ error: 'no topics configured' }), { status: 400 })
    }

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    const live = !!apiKey

    // Cross-day dedup: pull canonical URLs + headlines from the last 7
    // days so the pipeline excludes anything the user has already seen.
    // On forced refresh, today's existing articles are included too so
    // the regeneration produces genuinely new content rather than the
    // same set the user just saw.
    const sinceDate = new Date()
    sinceDate.setUTCDate(sinceDate.getUTCDate() - HISTORY_LOOKBACK_DAYS)
    const sinceISO = sinceDate.toISOString().slice(0, 10)
    const { data: history } = await supabase
      .from('briefing_articles')
      .select('canonical_url, headline')
      .eq('user_id', user.id)
      .gte('first_seen_date', sinceISO)
      .returns<{ canonical_url: string; headline: string }[]>()

    const alreadySeen: SeenSet = {
      urls: new Set((history ?? []).map((r) => r.canonical_url)),
      headlines: (history ?? []).map((r) => r.headline),
    }

    let totalArticles = 0
    let totalDropped = 0
    let totalCacheWrite = 0
    let totalCacheRead = 0
    let liveTopics = 0

    // Track real (non-fixture) articles separately so we only write the
    // history table for articles that actually came from the live
    // pipeline. Fixtures aren't real news and shouldn't pollute
    // cross-day dedup.
    const liveArticlesForHistory: { topic: string; article: PipelineArticle }[] = []

    const briefingTopics = await Promise.all(
      topics.map(async (t) => {
        if (!live) {
          // Dev/offline: no API key configured. Fixture content is the
          // intended UX here.
          return { topic: t.topic, articles: fixtureFor(t.topic) }
        }
        try {
          const result = await runTopicPipeline(t.topic, apiKey!, today, { alreadySeen })
          // Empty result is now a valid outcome — freshness + dedup may
          // legitimately leave a topic with zero articles on a slow news
          // day. Surface that honestly rather than padding with fixture
          // content (which would re-introduce the "old news as new" bug).
          // The iOS empty-topic UX renders this as "No fresh stories
          // today."
          liveTopics++
          totalArticles += result.articles.length
          totalDropped += result.droppedCount
          totalCacheWrite += result.usage.cache_creation_tokens
          totalCacheRead += result.usage.cache_read_tokens
          for (const a of result.articles) {
            liveArticlesForHistory.push({ topic: t.topic, article: a })
          }
          return { topic: t.topic, articles: result.articles }
        } catch (err) {
          // True pipeline error (API outage, network, etc.) — fixture
          // fallback is still the right call here because returning
          // empty would penalize the user for a backend failure.
          console.error(`generate_daily_briefing: pipeline failed for "${t.topic}": ${(err as Error).message}`)
          return { topic: t.topic, articles: fixtureFor(t.topic) }
        }
      }),
    )

    const payload = { date: today, topics: briefingTopics }

    const { error: upsertErr } = await supabase
      .from('daily_briefings')
      .upsert({
        user_id: user.id,
        briefing_date: today,
        payload,
        generated_at: new Date().toISOString(),
      })
    if (upsertErr) throw upsertErr

    // History insert: one row per live article, idempotent on
    // (user_id, canonical_url). ignoreDuplicates so a re-surfaced article
    // keeps its original first_seen_date — the dedup window must reflect
    // when the user first saw it, not when we re-served it.
    if (liveArticlesForHistory.length > 0) {
      const historyRows = liveArticlesForHistory.map(({ topic, article }) => ({
        user_id: user.id,
        canonical_url: canonicalUrl(article.url),
        article_id: article.id,
        headline: article.headline,
        source: article.source,
        url: article.url,
        topic,
        first_seen_date: today,
        payload: article,
      }))
      const { error: histErr } = await supabase
        .from('briefing_articles')
        .upsert(historyRows, { onConflict: 'user_id,canonical_url', ignoreDuplicates: true })
      if (histErr) {
        // History write is best-effort — failure shouldn't fail the
        // briefing. Log and continue.
        console.warn(`generate_daily_briefing: history upsert failed: ${histErr.message}`)
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        date: today,
        forced: force,
        topic_count: topics.length,
        live_topics: liveTopics,
        live_articles: totalArticles,
        dropped: totalDropped,
        cache_read: totalCacheRead,
        cache_write: totalCacheWrite,
      }),
      { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } },
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
