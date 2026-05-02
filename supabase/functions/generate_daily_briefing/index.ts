// Breeves — generate_daily_briefing Edge Function (v2, live).
//
// Reads the caller's 3 topics, runs the live pipeline (news fetch →
// extract → Claude summarization with prompt caching) and upserts the
// result into daily_briefings. If ANTHROPIC_API_KEY is unset OR a topic's
// pipeline returns zero articles (no candidates, all summarizations
// failed), falls back to the canned fixture for that topic so the client
// still receives a valid briefing.
//
// Fallback rationale: this function is user-triggered ("Refresh now").
// Returning a 500 because we got rate-limited or HN's API blipped is a
// worse UX than serving last-good fixture content. The cron in Step 5
// will be stricter — it logs failures rather than masking them.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'
// deno-lint-ignore-file no-explicit-any

import aiFixture from './fixtures/ai.json' with { type: 'json' }
import financeFixture from './fixtures/finance.json' with { type: 'json' }
import geopoliticsFixture from './fixtures/geopolitics.json' with { type: 'json' }
import defaultFixture from './fixtures/default.json' with { type: 'json' }

import { runTopicPipeline } from '../_shared/pipeline.ts'

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

    const { data: topics, error: topicsErr } = await supabase
      .from('user_topics')
      .select('topic, slot')
      .eq('user_id', user.id)
      .order('slot')

    if (topicsErr) throw topicsErr
    if (!topics || topics.length === 0) {
      return new Response(JSON.stringify({ error: 'no topics configured' }), { status: 400 })
    }

    const today = new Date().toISOString().slice(0, 10)
    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    const live = !!apiKey

    let totalArticles = 0
    let totalDropped = 0
    let totalCacheWrite = 0
    let totalCacheRead = 0
    let liveTopics = 0

    const briefingTopics = await Promise.all(
      topics.map(async (t) => {
        if (!live) {
          return { topic: t.topic, articles: fixtureFor(t.topic) }
        }
        try {
          const result = await runTopicPipeline(t.topic, apiKey!, today)
          if (result.articles.length === 0) {
            console.warn(`generate_daily_briefing: empty pipeline for "${t.topic}", using fixture`)
            return { topic: t.topic, articles: fixtureFor(t.topic) }
          }
          liveTopics++
          totalArticles += result.articles.length
          totalDropped += result.droppedCount
          totalCacheWrite += result.usage.cache_creation_tokens
          totalCacheRead += result.usage.cache_read_tokens
          return { topic: t.topic, articles: result.articles }
        } catch (err) {
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

    return new Response(
      JSON.stringify({
        ok: true,
        date: today,
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
