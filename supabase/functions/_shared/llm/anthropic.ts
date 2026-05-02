// Claude summarizer — turns a Candidate (URL + headline + body) into a
// schema-shaped article object, using prompt caching so the ~2700-token
// system prompt is paid for once per 5-minute window per Edge Function
// instance.
//
// IMPORTANT: the system block bytes here MUST stay identical to those sent
// by prompt_smoke.ts and any other caller. Any divergence (whitespace, an
// extra header, a different cache_control shape) splits the cache and tanks
// the hit rate. If you're touching prompts.ts or this call shape, change
// both call sites in lockstep.

import { BRIEFING_SYSTEM_PROMPT } from "../prompts.ts";
import type { Candidate } from "../news/types.ts";

const MODEL = "claude-sonnet-4-6";
const MAX_TOKENS = 1500;
const API_URL = "https://api.anthropic.com/v1/messages";

interface Usage {
    input_tokens: number;
    output_tokens: number;
    cache_creation_input_tokens?: number;
    cache_read_input_tokens?: number;
}

interface MessagesResponse {
    content: Array<{ type: string; text?: string }>;
    usage: Usage;
    stop_reason: string;
}

/// Shape returned by Claude — matches the JSON schema in prompts.ts.
/// Note: `id` and `source` live on the Swift `Article` struct but are NOT
/// produced by Claude — they're stamped in by the pipeline before upsert.
export interface ClaudeArticle {
    headline: string;
    estimated_read_time_minutes: number;
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

export interface SummarizeResult {
    article: ClaudeArticle;
    usage: Usage;
}

function todayUTC(): string {
    return new Date().toISOString().slice(0, 10);
}

function extractJSONText(resp: MessagesResponse): string {
    const textBlock = resp.content.find((b) => b.type === "text");
    if (!textBlock?.text) throw new Error("Claude returned no text block");
    let s = textBlock.text.trim();
    // Strip optional ```json fences if the model wraps the JSON despite the
    // prompt explicitly saying not to.
    if (s.startsWith("```")) {
        s = s.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/, "").trim();
    }
    return s;
}

/// Summarize a single candidate into a Claude-shaped article. Throws on
/// network error, non-2xx, or unparseable JSON — the pipeline catches and
/// drops the candidate so one bad article never sinks a whole topic.
export async function summarizeWithClaude(
    candidate: Candidate,
    topic: string,
    apiKey: string,
): Promise<SummarizeResult> {
    if (!candidate.body || candidate.body.trim().length === 0) {
        // Defensive: extract.ts can return empty body for paywalled / SPA pages.
        // The prompt is designed to handle thin material, but we still need
        // *something* in the user message — fall back to headline + URL so
        // Claude has at least the title to work with.
        candidate.body = `(Full text unavailable — paywalled or extraction failed.)\nHeadline: ${candidate.headline}\nURL: ${candidate.url}`;
    }

    const userText = `Today's date: ${todayUTC()}\nTopic: ${topic}\nSource: ${candidate.source}\nURL: ${candidate.url}\nPublished: ${candidate.publishedAt}\n\nArticle text:\n\n${candidate.body}`;

    const body = {
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: [
            {
                type: "text",
                text: BRIEFING_SYSTEM_PROMPT,
                cache_control: { type: "ephemeral" },
            },
        ],
        messages: [
            { role: "user", content: userText },
        ],
    };

    const res = await fetch(API_URL, {
        method: "POST",
        headers: {
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        body: JSON.stringify(body),
    });

    if (!res.ok) {
        const text = await res.text();
        throw new Error(`Claude API ${res.status}: ${text.slice(0, 500)}`);
    }

    const json = await res.json() as MessagesResponse;
    const jsonText = extractJSONText(json);

    let parsed: ClaudeArticle;
    try {
        parsed = JSON.parse(jsonText);
    } catch (e) {
        throw new Error(
            `Claude returned non-JSON for "${candidate.headline}": ${(e as Error).message}\n${jsonText.slice(0, 500)}`,
        );
    }

    return { article: parsed, usage: json.usage };
}
