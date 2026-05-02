import Foundation
import Models
import Supabase

public protocol ProfileService: AnyObject, Sendable {
    func fetchPreferences(for user: BreevesUser) async throws -> UserPreferences
    func updatePreferences(_ prefs: UserPreferences, for user: BreevesUser) async throws

    func fetchTopics(for user: BreevesUser) async throws -> [UserTopic]
    func saveTopics(_ topics: [UserTopic], for user: BreevesUser) async throws

    /// Validates and canonicalizes a free-typed topic string via the
    /// validate_topic Edge Function (Haiku). Returns ok=false with a
    /// user-facing `reason` if the topic is gibberish, off-policy, or
    /// otherwise rejected. Implementations should fail open on transient
    /// errors so the user isn't blocked by a backend hiccup.
    func validateTopic(_ raw: String) async throws -> TopicValidation
}

public final class SupabaseProfileService: ProfileService, @unchecked Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) { self.client = client }

    public func fetchPreferences(for user: BreevesUser) async throws -> UserPreferences {
        struct Row: Decodable {
            let notificationEnabled: Bool
            let notificationTime: String
            let defaultLens: String
            let briefLength: String
            let colorScheme: String
            let tz: String

            enum CodingKeys: String, CodingKey {
                case notificationEnabled = "notification_enabled"
                case notificationTime = "notification_time"
                case defaultLens = "default_lens"
                case briefLength = "brief_length"
                case colorScheme = "color_scheme"
                case tz
            }
        }

        let row: Row = try await client
            .from("profiles")
            .select("notification_enabled, notification_time, default_lens, brief_length, color_scheme, tz")
            .eq("id", value: user.id)
            .single()
            .execute()
            .value

        let parts = row.notificationTime.split(separator: ":")
        let hour = Int(parts.first ?? "5") ?? 5
        let minute = parts.count > 1 ? (Int(parts[1]) ?? 30) : 30

        return UserPreferences(
            notificationEnabled: row.notificationEnabled,
            notificationHour: hour,
            notificationMinute: minute,
            defaultLens: ReadingLens(rawValue: row.defaultLens) ?? .universal,
            briefLength: BriefLength(rawValue: row.briefLength) ?? .standard,
            colorScheme: ColorSchemePreference(rawValue: row.colorScheme) ?? .system,
            timezoneIdentifier: row.tz
        )
    }

    public func updatePreferences(_ prefs: UserPreferences, for user: BreevesUser) async throws {
        struct Update: Encodable {
            let notificationEnabled: Bool
            let notificationTime: String
            let defaultLens: String
            let briefLength: String
            let colorScheme: String
            let tz: String

            enum CodingKeys: String, CodingKey {
                case notificationEnabled = "notification_enabled"
                case notificationTime = "notification_time"
                case defaultLens = "default_lens"
                case briefLength = "brief_length"
                case colorScheme = "color_scheme"
                case tz
            }
        }
        let payload = Update(
            notificationEnabled: prefs.notificationEnabled,
            notificationTime: String(format: "%02d:%02d:00", prefs.notificationHour, prefs.notificationMinute),
            defaultLens: prefs.defaultLens.rawValue,
            briefLength: prefs.briefLength.rawValue,
            colorScheme: prefs.colorScheme.rawValue,
            tz: prefs.timezoneIdentifier
        )
        try await client.from("profiles").update(payload).eq("id", value: user.id).execute()
    }

    public func fetchTopics(for user: BreevesUser) async throws -> [UserTopic] {
        struct Row: Decodable {
            let topic: String
            let slot: Int
            let description: String?
        }
        let rows: [Row] = try await client
            .from("user_topics")
            .select("topic, slot, description")
            .eq("user_id", value: user.id)
            .order("slot")
            .execute()
            .value
        return rows.map { UserTopic(name: $0.topic, slot: $0.slot, descriptionText: $0.description) }
    }

    public func saveTopics(_ topics: [UserTopic], for user: BreevesUser) async throws {
        struct Row: Encodable {
            let userId: String
            let slot: Int
            let topic: String
            let description: String?

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case slot, topic, description
            }
        }
        try await client.from("user_topics").delete().eq("user_id", value: user.id).execute()
        let rows = topics.map { Row(userId: user.id, slot: $0.slot, topic: $0.name, description: $0.descriptionText) }
        try await client.from("user_topics").insert(rows).execute()
    }

    public func validateTopic(_ raw: String) async throws -> TopicValidation {
        struct Body: Encodable { let topic: String }
        // supabase-swift's functions.invoke handles auth header injection
        // (current session JWT) automatically.
        let resp: TopicValidation = try await client.functions
            .invoke(
                "validate_topic",
                options: FunctionInvokeOptions(method: .post, body: Body(topic: raw))
            )
        return resp
    }
}
