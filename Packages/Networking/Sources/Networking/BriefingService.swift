import Foundation
import Models
import Supabase

public protocol BriefingService: AnyObject, Sendable {
    /// Fetch today's briefing for the current user (or generate via Edge Function if missing).
    func fetchToday(for user: BreevesUser, topics: [UserTopic]) async throws -> DailyBriefing
}

public final class SupabaseBriefingService: BriefingService, @unchecked Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func fetchToday(for user: BreevesUser, topics: [UserTopic]) async throws -> DailyBriefing {
        let today = ISO8601DateFormatter.dateOnly.string(from: Date())

        do {
            return try await readBriefing(userID: user.id, today: today)
        } catch {
            // Try generating, then re-read.
            _ = try await client.functions.invoke(
                "generate_daily_briefing",
                options: FunctionInvokeOptions(method: .post)
            ) as Void
            return try await readBriefing(userID: user.id, today: today)
        }
    }

    /// Fetch the briefing row and decode through `JSONDecoder.briefing` so
    /// snake_case keys (estimated_read_time_minutes, universal_mode, etc.)
    /// map to camelCase Swift properties. PostgREST's default decoder
    /// doesn't apply convertFromSnakeCase, which silently fails the entire
    /// payload decode.
    private func readBriefing(userID: String, today: String) async throws -> DailyBriefing {
        // Fetch as raw Data so we can apply our own decoder.
        let response = try await client
            .from("daily_briefings")
            .select("payload")
            .eq("user_id", value: userID)
            .eq("briefing_date", value: today)
            .single()
            .execute()

        struct Row: Decodable {
            let payload: PayloadDTO
        }
        struct PayloadDTO: Decodable {
            let date: String
            let topics: [TopicBriefing]
        }

        let row = try JSONDecoder.briefing.decode(Row.self, from: response.data)
        let date = ISO8601DateFormatter.dateOnly.date(from: row.payload.date) ?? Date()
        return DailyBriefing(date: date, topics: row.payload.topics)
    }
}

extension ISO8601DateFormatter {
    static var dateOnly: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }
}
