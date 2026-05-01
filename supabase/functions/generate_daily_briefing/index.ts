// Breeves — generate_daily_briefing Edge Function (v1, stubbed).
// Reads the caller's 3 topics, returns a schema-valid briefing built from
// fixture JSON keyed by topic name (case-insensitive). No LLM call in v1.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'
// deno-lint-ignore-file no-explicit-any

import aiFixture from './fixtures/ai.json' with { type: 'json' }
import financeFixture from './fixtures/finance.json' with { type: 'json' }
import geopoliticsFixture from './fixtures/geopolitics.json' with { type: 'json' }
import defaultFixture from './fixtures/default.json' with { type: 'json' }

const FIXTURES: Record<string, any[]> = {
  ai: aiFixture,
  finance: financeFixture,
  geopolitics: geopoliticsFixture,
}

function fixtureFor(topicName: string): any[] {
  const key = topicName.trim().toLowerCase()
  if (FIXTURES[key]) return FIXTURES[key]
  // Fallback: use the default fixture but rebrand article ids/headlines per topic
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

    // Identify the caller from their JWT
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: { user }, error: userErr } = await userClient.auth.getUser()
    if (userErr || !user) return new Response(JSON.stringify({ error: 'invalid user' }), { status: 401 })

    // Load topics
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
    const payload = {
      date: today,
      topics: topics.map(t => ({
        topic: t.topic,
        articles: fixtureFor(t.topic),
      })),
    }

    const { error: upsertErr } = await supabase
      .from('daily_briefings')
      .upsert({
        user_id: user.id,
        briefing_date: today,
        payload,
        generated_at: new Date().toISOString(),
      })
    if (upsertErr) throw upsertErr

    return new Response(JSON.stringify({ ok: true, date: today, topic_count: topics.length }), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  }
})
