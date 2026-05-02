// Breeves — tick_briefings Edge Function (Phase 2 Step 5).
//
// Runs every 10 minutes via Supabase pg_cron. For each enabled profile
// where (a) the user's local time is within ±5 min of their delivery
// notification_time, and (b) we haven't already generated a briefing in
// the last 23 hours, runs the live pipeline and upserts the result.
//
// Concurrency model: users are processed SERIALLY within a single tick.
// Reasons:
//   - Claude prompt cache hit rate is highest when calls land back-to-back.
//   - Anthropic rate-limits per API key; parallel users would tip into 429s.
//   - Each user is ~3 topics × 6 articles ≈ 30s of Claude time, so a
//     handful of users per tick fits in the 60s function budget.
//
// Hard cap: MAX_USERS_PER_TICK protects the function timeout. If more
// users are eligible than fit in one tick, the next 10-min tick picks
// up the rest. Eligibility checks idempotent — same user doesn't get
// double-billed.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'
import { runBriefingPipeline } from '../_shared/pipeline.ts'

const MAX_USERS_PER_TICK = 8
const DELIVERY_WINDOW_MIN = 5
const COOLDOWN_HOURS = 23

interface ProfileRow {
    id: string
    notification_enabled: boolean
    notification_time: string  // 'HH:MM:SS'
    tz: string                  // IANA, e.g. 'America/Los_Angeles'
    last_briefing_run_at: string | null
}

interface TopicRow {
    user_id: string
    slot: number
    topic: string
}

/// Returns minutes-since-midnight for the user's current local time in
/// their stored IANA tz. Uses Intl.DateTimeFormat — no extra deps.
function nowMinutesInTz(tz: string): number {
    try {
        const fmt = new Intl.DateTimeFormat('en-US', {
            timeZone: tz,
            hour: '2-digit',
            minute: '2-digit',
            hour12: false,
        })
        const parts = fmt.formatToParts(new Date())
        const h = parseInt(parts.find((p) => p.type === 'hour')?.value ?? '0', 10)
        const m = parseInt(parts.find((p) => p.type === 'minute')?.value ?? '0', 10)
        return h * 60 + m
    } catch {
        // Bad tz string falls back to UTC. Better than crashing the tick.
        const d = new Date()
        return d.getUTCHours() * 60 + d.getUTCMinutes()
    }
}

/// Today's date string in the user's tz (YYYY-MM-DD). The briefing_date
/// column needs to reflect the user's local calendar day, not UTC, or
/// users near midnight see "yesterday's" briefing date.
function todayInTz(tz: string): string {
    try {
        const fmt = new Intl.DateTimeFormat('en-CA', {
            timeZone: tz,
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
        })
        return fmt.format(new Date())  // en-CA gives YYYY-MM-DD natively
    } catch {
        return new Date().toISOString().slice(0, 10)
    }
}

function parseHmsToMinutes(hms: string): number {
    const [h, m] = hms.split(':').map((s) => parseInt(s, 10))
    return (h || 0) * 60 + (m || 0)
}

function isWithinDeliveryWindow(
    nowMin: number,
    targetMin: number,
    tolerance: number,
): boolean {
    // Handle midnight wrap: e.g. target=00:30, now=23:55. Compute the
    // smaller of the forward and backward differences on a 1440-minute
    // circular axis.
    const diff = Math.abs(nowMin - targetMin)
    const circular = Math.min(diff, 1440 - diff)
    return circular <= tolerance
}

function cooldownExpired(lastRunAt: string | null, hours: number): boolean {
    if (!lastRunAt) return true
    const last = Date.parse(lastRunAt)
    if (Number.isNaN(last)) return true
    return Date.now() - last >= hours * 3600 * 1000
}

Deno.serve(async (req) => {
    // Cron-only function. Reject anything that doesn't carry the service
    // role key — pg_cron sets the Authorization header from a vault secret.
    const auth = req.headers.get('Authorization') ?? ''
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    if (auth !== `Bearer ${serviceKey}`) {
        return new Response(JSON.stringify({ error: 'unauthorized' }), { status: 401 })
    }

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!apiKey) {
        // Without Claude we can't generate live briefings. Log and exit
        // cleanly — better than burning compute on a no-op.
        console.error('tick_briefings: ANTHROPIC_API_KEY unset, skipping tick')
        return new Response(JSON.stringify({ ok: true, skipped: true, reason: 'no_api_key' }), {
            headers: { 'Content-Type': 'application/json' },
        })
    }

    const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        serviceKey,
    )

    // Pull all enabled profiles whose cooldown is expired. The eligibility
    // index from migration 0002 makes this cheap. Window check happens
    // in-memory (per-row tz math is hard to express in SQL).
    const cutoff = new Date(Date.now() - COOLDOWN_HOURS * 3600 * 1000).toISOString()
    const { data: profiles, error: profErr } = await supabase
        .from('profiles')
        .select('id, notification_enabled, notification_time, tz, last_briefing_run_at')
        .eq('notification_enabled', true)
        .or(`last_briefing_run_at.is.null,last_briefing_run_at.lt.${cutoff}`)
        .returns<ProfileRow[]>()

    if (profErr) {
        console.error(`tick_briefings: profile scan failed: ${profErr.message}`)
        return new Response(JSON.stringify({ error: profErr.message }), { status: 500 })
    }

    const eligible = (profiles ?? []).filter((p) => {
        const nowMin = nowMinutesInTz(p.tz)
        const targetMin = parseHmsToMinutes(p.notification_time)
        return (
            isWithinDeliveryWindow(nowMin, targetMin, DELIVERY_WINDOW_MIN) &&
            cooldownExpired(p.last_briefing_run_at, COOLDOWN_HOURS)
        )
    })

    const batch = eligible.slice(0, MAX_USERS_PER_TICK)
    console.log(
        `tick_briefings: ${profiles?.length ?? 0} candidates, ` +
            `${eligible.length} in delivery window, processing ${batch.length}`,
    )

    let succeeded = 0
    let failed = 0
    const failures: string[] = []

    for (const profile of batch) {
        try {
            const { data: topics, error: topicsErr } = await supabase
                .from('user_topics')
                .select('user_id, slot, topic')
                .eq('user_id', profile.id)
                .order('slot')
                .returns<TopicRow[]>()

            if (topicsErr) throw new Error(`topics: ${topicsErr.message}`)
            if (!topics || topics.length === 0) {
                console.warn(`tick_briefings: ${profile.id} has no topics, skipping`)
                continue
            }

            const dateISO = todayInTz(profile.tz)
            const { results } = await runBriefingPipeline(
                topics.map((t) => t.topic),
                apiKey,
                dateISO,
            )

            const payloadTopics = results.map((r) => ({
                topic: r.topic,
                articles: r.articles,
            }))

            const { error: upsertErr } = await supabase
                .from('daily_briefings')
                .upsert({
                    user_id: profile.id,
                    briefing_date: dateISO,
                    payload: { date: dateISO, topics: payloadTopics },
                    generated_at: new Date().toISOString(),
                })
            if (upsertErr) throw new Error(`upsert: ${upsertErr.message}`)

            const { error: stampErr } = await supabase
                .from('profiles')
                .update({ last_briefing_run_at: new Date().toISOString() })
                .eq('id', profile.id)
            if (stampErr) throw new Error(`stamp: ${stampErr.message}`)

            succeeded++
        } catch (err) {
            failed++
            const msg = (err as Error).message
            failures.push(`${profile.id}: ${msg}`)
            console.error(`tick_briefings: failed for ${profile.id}: ${msg}`)
            // Note: we deliberately don't update last_briefing_run_at on
            // failure, so the next tick retries this user.
        }
    }

    return new Response(
        JSON.stringify({
            ok: true,
            scanned: profiles?.length ?? 0,
            in_window: eligible.length,
            processed: batch.length,
            succeeded,
            failed,
            failures: failures.length > 0 ? failures : undefined,
        }),
        { headers: { 'Content-Type': 'application/json' } },
    )
})
