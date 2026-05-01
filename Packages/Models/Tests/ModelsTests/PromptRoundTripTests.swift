import XCTest
@testable import Models

/// Round-trips Claude's JSON output (from supabase/functions/_shared/canned/_out/)
/// through the production `Article` Codable struct.
///
/// Claude's output omits `id` and `source` because the upsert pipeline injects
/// them. This test mirrors that by injecting placeholders before decoding —
/// if the round-trip fails after injection, the prompt is wrong, not the schema.
///
/// The test SKIPS cleanly when no smoke output exists (i.e., the user hasn't
/// run prompt_smoke.ts yet). Run the smoke script to populate _out/ first:
///   ANTHROPIC_API_KEY=... deno run --allow-net --allow-read --allow-write \
///     --allow-env supabase/functions/_shared/prompt_smoke.ts
final class PromptRoundTripTests: XCTestCase {

    /// Walks up from the test file to the workspace root, then descends to
    /// the canned outputs. Avoids needing SPM resource declarations.
    private func smokeOutputDir() -> URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while dir.pathComponents.count > 1 {
            let candidate = dir
                .appendingPathComponent("supabase")
                .appendingPathComponent("functions")
                .appendingPathComponent("_shared")
                .appendingPathComponent("canned")
                .appendingPathComponent("_out")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    func testSmokeOutputsRoundTrip() throws {
        guard let outDir = smokeOutputDir() else {
            throw XCTSkip("No smoke output found — run prompt_smoke.ts to generate.")
        }

        let files = try FileManager.default
            .contentsOfDirectory(at: outDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !files.isEmpty else {
            throw XCTSkip("Smoke output dir is empty — run prompt_smoke.ts.")
        }

        for url in files {
            let data = try Data(contentsOf: url)
            let withFields = try injectPipelineFields(into: data, source: "smoke")

            do {
                let article = try JSONDecoder.briefing.decode(Article.self, from: withFields)
                XCTAssertFalse(article.headline.isEmpty, "Empty headline in \(url.lastPathComponent)")
                XCTAssertGreaterThan(article.estimatedReadTimeMinutes, 0, "Bad read time in \(url.lastPathComponent)")
                XCTAssertFalse(article.universalMode.gist.isEmpty, "Empty gist in \(url.lastPathComponent)")
                XCTAssertFalse(article.topicSpecificMode.bullet1Header.isEmpty, "Empty topic bullet in \(url.lastPathComponent)")
                XCTAssertFalse(article.executiveMode.theIntel.isEmpty, "Empty intel in \(url.lastPathComponent)")
            } catch {
                XCTFail("Failed to decode \(url.lastPathComponent): \(error)")
            }
        }
    }

    /// Injects synthetic `id` and `source` into a JSON object emitted by Claude,
    /// matching what the upsert pipeline does in production.
    private func injectPipelineFields(into data: Data, source: String) throws -> Data {
        guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(
                domain: "PromptRoundTripTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Top-level JSON is not an object"]
            )
        }
        dict["id"] = UUID().uuidString
        dict["source"] = source
        return try JSONSerialization.data(withJSONObject: dict)
    }
}
