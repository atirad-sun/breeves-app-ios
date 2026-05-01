// Smoke test for the Brief30 system prompt.
//
// Reads supabase/functions/_shared/canned/*.txt, sends each through
// Claude Sonnet 4.6 with prompt caching, writes the parsed JSON to
// canned/_out/, and logs token-usage so we can verify cache reads
// kick in on calls 2..N.
//
// Run:
//   ANTHROPIC_API_KEY=... deno run \
//     --allow-net --allow-read --allow-write --allow-env \
//     supabase/functions/_shared/prompt_smoke.ts
//
// Exit codes:
//   0 — every article parsed cleanly into a JSON object.
//   1 — at least one parse error (details printed to stderr).

import { BRIEFING_SYSTEM_PROMPT } from "./prompts.ts";

const MODEL = "claude-sonnet-4-6";
const MAX_TOKENS = 1500;
const API_URL = "https://api.anthropic.com/v1/messages";

// Resolve the script's own directory. fileURLToPath decodes %20 etc. so paths
// with spaces (e.g. "Sunatrd Projects/") survive readDir/readFile/writeFile.
import { fromFileUrl } from "https://deno.land/std@0.224.0/path/from_file_url.ts";
import { join } from "https://deno.land/std@0.224.0/path/join.ts";
const HERE = fromFileUrl(new URL(".", import.meta.url));
const CANNED_DIR = join(HERE, "canned");
const OUT_DIR = join(CANNED_DIR, "_out");

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

function inferTopic(basename: string): string {
    // "ai_openai_o3.txt" → "AI"; "geopolitics_taiwan.txt" → "Geopolitics".
    const stem = basename.replace(/\.txt$/i, "");
    const head = stem.split(/[_-]/)[0] ?? stem;
    return head.charAt(0).toUpperCase() + head.slice(1);
}

async function callClaude(
    apiKey: string,
    topic: string,
    articleText: string,
): Promise<MessagesResponse> {
    const body = {
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: [
            {
                type: "text",
                text: BRIEFING_SYSTEM_PROMPT,
                // 5-minute ephemeral cache. Same prefix bytes across calls →
                // cache_read_input_tokens > 0 on calls 2..N.
                cache_control: { type: "ephemeral" },
            },
        ],
        messages: [
            {
                role: "user",
                content: `Topic: ${topic}\n\nArticle text:\n\n${articleText}`,
            },
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
        throw new Error(`Claude API ${res.status}: ${text}`);
    }
    return await res.json() as MessagesResponse;
}

function extractJSONText(resp: MessagesResponse): string {
    const textBlock = resp.content.find((b) => b.type === "text");
    if (!textBlock?.text) {
        throw new Error("No text block in response");
    }
    // Strip optional ```json fences if the model wraps the JSON.
    let s = textBlock.text.trim();
    if (s.startsWith("```")) {
        s = s.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/, "").trim();
    }
    return s;
}

function logUsage(name: string, idx: number, usage: Usage) {
    const cw = usage.cache_creation_input_tokens ?? 0;
    const cr = usage.cache_read_input_tokens ?? 0;
    console.log(
        `[${idx + 1}] ${name.padEnd(40)} ` +
            `in=${usage.input_tokens} out=${usage.output_tokens} ` +
            `cache_write=${cw} cache_read=${cr}`,
    );
}

async function main() {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
        console.error("ANTHROPIC_API_KEY not set");
        Deno.exit(2);
    }

    let entries: Deno.DirEntry[];
    try {
        entries = [];
        for await (const e of Deno.readDir(CANNED_DIR)) entries.push(e);
    } catch (err) {
        console.error(`Cannot read ${CANNED_DIR}: ${(err as Error).message}`);
        Deno.exit(2);
    }

    const txtFiles = entries
        .filter((e) => e.isFile && e.name.endsWith(".txt"))
        .map((e) => e.name)
        .sort();

    if (txtFiles.length === 0) {
        console.error(`No .txt files in ${CANNED_DIR}`);
        Deno.exit(2);
    }

    await Deno.mkdir(OUT_DIR, { recursive: true });

    const failures: string[] = [];
    let firstWrite = 0;
    let totalReads = 0;

    for (let i = 0; i < txtFiles.length; i++) {
        const name = txtFiles[i];
        const basename = name.replace(/\.txt$/, "");
        const topic = inferTopic(name);
        const raw = await Deno.readTextFile(join(CANNED_DIR, name));

        try {
            const resp = await callClaude(apiKey, topic, raw);
            logUsage(name, i, resp.usage);

            if (i === 0) {
                firstWrite = resp.usage.cache_creation_input_tokens ?? 0;
            } else {
                totalReads += resp.usage.cache_read_input_tokens ?? 0;
            }

            const jsonText = extractJSONText(resp);
            let parsed: unknown;
            try {
                parsed = JSON.parse(jsonText);
            } catch (e) {
                failures.push(
                    `${name}: JSON.parse failed — ${(e as Error).message}\n${jsonText}`,
                );
                continue;
            }

            const outPath = join(OUT_DIR, `${basename}.json`);
            await Deno.writeTextFile(
                outPath,
                JSON.stringify(parsed, null, 2) + "\n",
            );
            console.log(`    → ${outPath}`);
        } catch (e) {
            failures.push(`${name}: ${(e as Error).message}`);
        }
    }

    console.log();
    console.log(`Cache write on call 1: ${firstWrite} tokens`);
    console.log(`Total cache reads on calls 2..N: ${totalReads} tokens`);
    if (firstWrite > 0 && txtFiles.length > 1) {
        const expected = firstWrite * (txtFiles.length - 1);
        const ratio = expected > 0 ? totalReads / expected : 0;
        console.log(
            `Cache hit rate: ${(ratio * 100).toFixed(1)}% (target ≥90%)`,
        );
    }

    if (failures.length > 0) {
        console.error(`\n${failures.length} failure(s):`);
        for (const f of failures) console.error(`  - ${f}`);
        Deno.exit(1);
    }
    console.log(`\nAll ${txtFiles.length} articles parsed cleanly.`);
}

await main();
