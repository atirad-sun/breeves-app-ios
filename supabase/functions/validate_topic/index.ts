// Breeves — validate_topic Edge Function (Phase 2 Step 6).
//
// Accepts { topic: string }, calls Claude Haiku 4.6 to:
//   1. Reject garbage (gibberish, single chars, profanity, off-policy).
//   2. Canonicalize freely-typed input to a search-friendly form
//      ("ai" → "Artificial Intelligence", "fed" → "Federal Reserve").
//   3. Return a one-line description for the topic chip UI.
//
// Why Haiku 4.6 (not Sonnet): this is a low-stakes classification task
// that runs on every custom topic add. Haiku is ~10x cheaper and ~3x
// faster, and the output is structurally trivial (small JSON). Sonnet
// would be overkill.
//
// No prompt cache here: each call has different user input and the
// system block is short (<<2048 tokens), so caching wouldn't pay off.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const MODEL = 'claude-haiku-4-5-20251001'
const MAX_TOKENS = 200
const API_URL = 'https://api.anthropic.com/v1/messages'

const SYSTEM_PROMPT = `You are validating user-typed topic names for a daily news briefing app. The user types a short string; you decide whether it's a valid news topic, canonicalize it, and provide a one-line description.

Output ONLY a single valid JSON object. No prose. No code fences. The first character must be \`{\` and the last must be \`}\`.

Schema:
{
  "ok": boolean,                     // true if the topic is valid for news briefings
  "canonical": string | null,        // canonical form, ≤32 chars (e.g. "Artificial Intelligence")
  "description": string | null,      // one-line description, ≤80 chars
  "reason": string | null            // if ok=false, a short user-facing reason
}

Rules:
- Reject gibberish ("asdf", "xyz123"), single characters, profanity, slurs, sexual content, illegal activity, personal targeting (specific private individuals).
- Accept: companies, public figures (politicians, executives), industries, technologies, geographic regions, sports, health/wellness, finance, science, world events.
- Canonicalize aggressively: "ai" → "Artificial Intelligence", "fed" → "Federal Reserve", "apple" → "Apple Inc.", "tsla" → "Tesla", "nvidia stock" → "NVIDIA".
- Description must be neutral and factual. No marketing language.
- If the input is already canonical, set canonical to that input verbatim and ok=true.

Examples:
  Input: "asdf" → {"ok": false, "canonical": null, "description": null, "reason": "Doesn't look like a real topic — try a company, person, or subject."}
  Input: "ai"   → {"ok": true, "canonical": "Artificial Intelligence", "description": "AI research, models, and applications", "reason": null}
  Input: "fed"  → {"ok": true, "canonical": "Federal Reserve", "description": "U.S. central bank policy, rates, and statements", "reason": null}
  Input: "Climate change" → {"ok": true, "canonical": "Climate Change", "description": "Global warming, policy, and mitigation efforts", "reason": null}
  Input: "porn" → {"ok": false, "canonical": null, "description": null, "reason": "We don't summarize adult content. Try a different topic."}`

interface Usage {
    input_tokens: number
    output_tokens: number
}

interface MessagesResponse {
    content: Array<{ type: string; text?: string }>
    usage: Usage
    stop_reason: string
}

interface ValidationResult {
    ok: boolean
    canonical: string | null
    description: string | null
    reason: string | null
}

function extractJSON(resp: MessagesResponse): string {
    const text = resp.content.find((b) => b.type === 'text')?.text
    if (!text) throw new Error('Haiku returned no text block')
    let s = text.trim()
    if (s.startsWith('```')) {
        s = s.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, '').trim()
    }
    return s
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
        // Auth: must be a real signed-in user. Garbage-collect requests
        // from unauthenticated callers — this endpoint costs Anthropic
        // tokens and shouldn't be a public abuse vector.
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(JSON.stringify({ error: 'no auth' }), { status: 401 })
        }
        const userClient = createClient(
            Deno.env.get('SUPABASE_URL')!,
            Deno.env.get('SUPABASE_ANON_KEY')!,
            { global: { headers: { Authorization: authHeader } } },
        )
        const { data: { user }, error: userErr } = await userClient.auth.getUser()
        if (userErr || !user) {
            return new Response(JSON.stringify({ error: 'invalid user' }), { status: 401 })
        }

        const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
        if (!apiKey) {
            // No key in dev — pass-through accept. Better than blocking
            // the iOS dev loop on Supabase secrets being set.
            const body = await req.json().catch(() => ({})) as { topic?: string }
            const topic = (body.topic ?? '').trim()
            return new Response(JSON.stringify({
                ok: !!topic,
                canonical: topic || null,
                description: 'Custom topic — news will be curated daily.',
                reason: topic ? null : 'Topic cannot be empty.',
            }), { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } })
        }

        const body = await req.json().catch(() => ({})) as { topic?: string }
        const topic = (body.topic ?? '').trim()
        if (!topic) {
            return new Response(JSON.stringify({
                ok: false,
                canonical: null,
                description: null,
                reason: 'Topic cannot be empty.',
            }), { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } })
        }
        if (topic.length > 64) {
            return new Response(JSON.stringify({
                ok: false,
                canonical: null,
                description: null,
                reason: 'Topic is too long. Try something shorter.',
            }), { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } })
        }

        const claudeRes = await fetch(API_URL, {
            method: 'POST',
            headers: {
                'x-api-key': apiKey,
                'anthropic-version': '2023-06-01',
                'content-type': 'application/json',
            },
            body: JSON.stringify({
                model: MODEL,
                max_tokens: MAX_TOKENS,
                system: SYSTEM_PROMPT,
                messages: [{ role: 'user', content: `Validate topic: ${topic}` }],
            }),
        })

        if (!claudeRes.ok) {
            const text = await claudeRes.text()
            console.error(`validate_topic: Haiku ${claudeRes.status}: ${text.slice(0, 300)}`)
            // Fail open — don't block the user on a transient Anthropic
            // error. The pipeline tolerates any topic string anyway; a
            // bad topic just produces low-relevance briefing content.
            return new Response(JSON.stringify({
                ok: true,
                canonical: topic,
                description: 'Custom topic — news will be curated daily.',
                reason: null,
            }), { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } })
        }

        const json = await claudeRes.json() as MessagesResponse
        const jsonText = extractJSON(json)
        let result: ValidationResult
        try {
            result = JSON.parse(jsonText)
        } catch (e) {
            console.error(`validate_topic: non-JSON from Haiku: ${(e as Error).message}\n${jsonText.slice(0, 300)}`)
            // Fail open on bad JSON too. Same reasoning.
            return new Response(JSON.stringify({
                ok: true,
                canonical: topic,
                description: 'Custom topic — news will be curated daily.',
                reason: null,
            }), { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } })
        }

        return new Response(JSON.stringify(result), {
            headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
        })
    } catch (err) {
        return new Response(JSON.stringify({ error: String(err) }), {
            status: 500,
            headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
        })
    }
})
