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

        // 1. Try to read today's briefing
        struct Row: Decodable {
            let payload: PayloadDTO
        }
        struct PayloadDTO: Decodable {
            let date: String
            let topics: [TopicBriefing]
        }

        do {
            let row: Row = try await client
                .from("daily_briefings")
                .select("payload")
                .eq("user_id", value: user.id)
                .eq("briefing_date", value: today)
                .single()
                .execute()
                .value

            let date = ISO8601DateFormatter.dateOnly.date(from: row.payload.date) ?? Date()
            return DailyBriefing(date: date, topics: row.payload.topics)
        } catch {
            // 2. Trigger generation, then re-read.
            _ = try await client.functions.invoke(
                "generate_daily_briefing",
                options: FunctionInvokeOptions(method: .post)
            ) as Void

            let row: Row = try await client
                .from("daily_briefings")
                .select("payload")
                .eq("user_id", value: user.id)
                .eq("briefing_date", value: today)
                .single()
                .execute()
                .value

            let date = ISO8601DateFormatter.dateOnly.date(from: row.payload.date) ?? Date()
            return DailyBriefing(date: date, topics: row.payload.topics)
        }
    }
}

extension ISO8601DateFormatter {
    static var dateOnly: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }
}
