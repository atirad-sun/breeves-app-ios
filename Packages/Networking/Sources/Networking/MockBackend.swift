import Foundation
import Models

/// In-memory mock implementation of all backend services. Used when
/// `Secrets.plist` is missing — gives a fully demoable vertical slice with
/// no Supabase project required.
public actor MockBackend {
    private var user: BreevesUser?
    private var topics: [UserTopic] = []
    private var prefs: UserPreferences = UserPreferences()
    private var briefingCache: [String: DailyBriefing] = [:]

    public init() {}

    fileprivate func setUser(_ u: BreevesUser?) { self.user = u }
    fileprivate func getUser() -> BreevesUser? { user }

    fileprivate func setTopics(_ t: [UserTopic]) { self.topics = t }
    fileprivate func getTopics() -> [UserTopic] { topics }

    fileprivate func setPrefs(_ p: UserPreferences) { self.prefs = p }
    fileprivate func getPrefs() -> UserPreferences { prefs }

    fileprivate func generateBriefing(for date: String) -> DailyBriefing {
        if let cached = briefingCache[date] { return cached }
        let resolved = topics.map { topic -> TopicBriefing in
            let articles = MockFixtureLoader.load(topic: topic.name)
            return TopicBriefing(topic: topic.name, articles: articles)
        }
        let parsed = ISO8601DateFormatter.dateOnly.date(from: date) ?? Date()
        let briefing = DailyBriefing(date: parsed, topics: resolved)
        briefingCache[date] = briefing
        return briefing
    }
}

// MARK: - Fixture loader

enum MockFixtureLoader {
    static func load(topic: String) -> [Article] {
        let key = topic.lowercased()
        let candidates = [key, "ai", "finance", "geopolitics"]
        for name in candidates {
            if let url = Bundle.module.url(forResource: name, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let articles = try? JSONDecoder.briefing.decode([Article].self, from: data) {
                if name == key { return articles }
                // Default fallback — relabel ids/headlines for unknown topics
                return articles.enumerated().map { idx, a in
                    Article(
                        id: "\(key.replacingOccurrences(of: " ", with: "-"))-\(idx + 1)",
                        headline: "\(topic): \(a.headline)",
                        estimatedReadTimeMinutes: a.estimatedReadTimeMinutes,
                        source: a.source,
                        universalMode: a.universalMode,
                        topicSpecificMode: a.topicSpecificMode,
                        executiveMode: a.executiveMode
                    )
                }
            }
        }
        return []
    }
}

// MARK: - AuthService

public final class MockAuthService: AuthService, @unchecked Sendable {
    private let backend: MockBackend
    public init(backend: MockBackend) { self.backend = backend }

    public var currentUser: BreevesUser? {
        get async { await backend.getUser() }
    }

    public func signInWithApple(authorization: AuthenticationServicesShim, rawNonce: String) async throws -> BreevesUser {
        let user = BreevesUser(id: "mock-apple-user", email: "alex.morgan@icloud.com", provider: "apple")
        await backend.setUser(user)
        return user
    }

    public func signInWithGoogle(idToken: String, accessToken: String?) async throws -> BreevesUser {
        let user = BreevesUser(id: "mock-google-user", email: "alex.morgan@gmail.com", provider: "google")
        await backend.setUser(user)
        return user
    }

    public func signOut() async throws {
        await backend.setUser(nil)
    }
}

import AuthenticationServices

extension MockAuthService {
    // Conform to the protocol-required Apple sign-in entry point. The mock
    // ignores the credentials and just returns a fake user.
    public func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws -> BreevesUser {
        return try await signInWithApple(authorization: AuthenticationServicesShim(), rawNonce: rawNonce)
    }
}

/// Empty shim — the mock doesn't read the real authorization payload, but we
/// keep a typed parameter so signatures match in test/demo paths.
public struct AuthenticationServicesShim {}

// MARK: - ProfileService

public final class MockProfileService: ProfileService, @unchecked Sendable {
    private let backend: MockBackend
    public init(backend: MockBackend) { self.backend = backend }

    public func fetchPreferences(for user: BreevesUser) async throws -> UserPreferences {
        await backend.getPrefs()
    }
    public func updatePreferences(_ prefs: UserPreferences, for user: BreevesUser) async throws {
        await backend.setPrefs(prefs)
    }
    public func fetchTopics(for user: BreevesUser) async throws -> [UserTopic] {
        await backend.getTopics()
    }
    public func saveTopics(_ topics: [UserTopic], for user: BreevesUser) async throws {
        await backend.setTopics(topics)
    }
}

// MARK: - BriefingService

public final class MockBriefingService: BriefingService, @unchecked Sendable {
    private let backend: MockBackend
    public init(backend: MockBackend) { self.backend = backend }

    public func fetchToday(for user: BreevesUser, topics: [UserTopic]) async throws -> DailyBriefing {
        // Make sure the backend has the latest topics — useful when caller
        // passes the freshly-edited list.
        await backend.setTopics(topics)
        let today = ISO8601DateFormatter.dateOnly.string(from: Date())
        return await backend.generateBriefing(for: today)
    }
}
