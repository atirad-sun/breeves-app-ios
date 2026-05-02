import Foundation
import SwiftUI
import Models
import Networking
import Persistence

@MainActor
@Observable
public final class AppModel {
    public enum Route: Equatable {
        case splash
        case auth
        case onboardingTopics
        case onboardingPreferences
        case dashboard
    }

    public var route: Route = .splash
    public var user: BreevesUser?
    public var preferences: UserPreferences = UserPreferences()
    public var topics: [UserTopic] = []
    public var briefing: DailyBriefing?
    public var readArticleIds: Set<String> = []
    public var globalLens: ReadingLens = .universal
    public var isLoadingBriefing: Bool = false
    public var briefingError: String?
    public var isCompletionShown: Bool = false

    public let backend: BreevesBackend
    public let cache: BriefingCache

    public init(backend: BreevesBackend, cache: BriefingCache) {
        self.backend = backend
        self.cache = cache
    }

    public var totalRead: Int { readArticleIds.count }
    public var totalArticles: Int { briefing?.totalArticles ?? 18 }

    // MARK: - Boot

    public func bootstrap() async {
        // Try to recover preferences and topics from cache.
        if let cachedPrefs = (try? cache.loadPreferences()) ?? nil {
            preferences = cachedPrefs
        }
        if let cachedReads = try? cache.readArticleIds() {
            readArticleIds = cachedReads
        }

        // 600ms splash, then advance.
        try? await Task.sleep(for: .milliseconds(600))

        // Debug fast-forward — only used when the app is launched with -BREEVES_DEMO=1
        // (mock backend only). Auto signs in and seeds 3 default topics so we can
        // jump straight to the dashboard for screenshot capture.
        let args = ProcessInfo.processInfo.arguments
        let demoMode = args.contains("-BREEVES_DEMO") && backend.mode == .mock

        // Live backend debug bypass: simulator's Apple/Google sign-in flows
        // are broken on iOS 26 (passcode pref pane regression + missing
        // GOOGLE_CLIENT_ID), so this lets us land a real Supabase JWT for
        // backend testing. Reads -BREEVES_DEBUG_EMAIL and
        // -BREEVES_DEBUG_PASSWORD from launch args; never bake credentials
        // into the binary.
        if backend.mode == .live, args.contains("-BREEVES_LIVE_DEBUG_USER") {
            if let email = launchArg(args, "-BREEVES_DEBUG_EMAIL"),
               let password = launchArg(args, "-BREEVES_DEBUG_PASSWORD") {
                do {
                    let u = try await backend.auth.signInWithEmailPassword(email: email, password: password)
                    self.user = u
                    await loadAfterAuth()
                    return
                } catch {
                    print("[BREEVES_LIVE_DEBUG_USER] sign-in failed: \(error)")
                    // Fall through to normal auth screen.
                }
            } else {
                print("[BREEVES_LIVE_DEBUG_USER] missing -BREEVES_DEBUG_EMAIL or -BREEVES_DEBUG_PASSWORD")
            }
        }

        // Direct routes for screenshot capture
        if backend.mode == .mock && args.contains("-BREEVES_TOPICS") {
            try? await Task.sleep(for: .milliseconds(50))
            do {
                let u = try await backend.auth.signInWithGoogle(idToken: "demo", accessToken: nil)
                self.user = u
            } catch {}
            route = .onboardingTopics
            return
        }
        if backend.mode == .mock && args.contains("-BREEVES_PREFS") {
            do {
                let u = try await backend.auth.signInWithGoogle(idToken: "demo", accessToken: nil)
                self.user = u
            } catch {}
            route = .onboardingPreferences
            return
        }
        if demoMode {
            // Bypass Apple SDK; use Google mock path which doesn't need an ASAuthorization.
            do {
                let u = try await backend.auth.signInWithGoogle(idToken: "demo", accessToken: nil)
                self.user = u
                let seed: [UserTopic] = [
                    UserTopic(name: "AI", slot: 1, descriptionText: "Artificial Intelligence — models, research, applications"),
                    UserTopic(name: "Finance", slot: 2, descriptionText: "Global markets, banking, investment"),
                    UserTopic(name: "Geopolitics", slot: 3, descriptionText: "International relations, diplomacy, conflict"),
                ]
                try await backend.profiles.saveTopics(seed, for: u)
                topics = seed

                // Override lens via -BREEVES_LENS=action / deep / universal
                if args.contains("-BREEVES_LENS_ACTION") {
                    globalLens = .executive
                } else if args.contains("-BREEVES_LENS_DEEP") {
                    globalLens = .topicSpecific
                } else {
                    globalLens = .universal
                }
                preferences.defaultLens = globalLens

                await loadBriefing()

                // Mark all articles read to demo completion screen
                if args.contains("-BREEVES_COMPLETE") {
                    if let briefing {
                        readArticleIds = Set(briefing.topics.flatMap { $0.articles.map(\.id) })
                        try? await Task.sleep(for: .milliseconds(50))
                        isCompletionShown = true
                    }
                }

                route = .dashboard
                return
            } catch { /* fall through */ }
        }

        if let user = await backend.auth.currentUser {
            self.user = user
            await loadAfterAuth()
        } else {
            route = .auth
        }
    }

    public func handleSignedIn(_ user: BreevesUser) async {
        self.user = user
        await loadAfterAuth()
    }

    private func loadAfterAuth() async {
        guard let user else { return }
        do {
            let serverPrefs = try await backend.profiles.fetchPreferences(for: user)
            preferences = serverPrefs
            try? cache.savePreferences(serverPrefs)
        } catch { /* fall through with defaults */ }

        do {
            topics = try await backend.profiles.fetchTopics(for: user)
        } catch { topics = [] }

        if topics.count == 3 {
            globalLens = preferences.defaultLens
            await loadBriefing()
            route = .dashboard
        } else {
            route = .onboardingTopics
        }
    }

    // MARK: - Onboarding handoff

    public func saveOnboardingTopics(_ topics: [UserTopic]) async throws {
        guard let user else { throw AuthError.invalidAppleCredential }
        try await backend.profiles.saveTopics(topics, for: user)
        self.topics = topics
        route = .onboardingPreferences
    }

    public func saveOnboardingPreferences(_ prefs: UserPreferences) async throws {
        guard let user else { throw AuthError.invalidAppleCredential }
        try await backend.profiles.updatePreferences(prefs, for: user)
        self.preferences = prefs
        try? cache.savePreferences(prefs)
        globalLens = prefs.defaultLens
        await loadBriefing()
        route = .dashboard
    }

    // MARK: - Dashboard

    public func loadBriefing() async {
        guard let user else { return }
        isLoadingBriefing = true
        briefingError = nil
        defer { isLoadingBriefing = false }

        // Try cache first
        if let cached = try? cache.loadToday() {
            briefing = cached
        }

        do {
            let fresh = try await backend.briefings.fetchToday(for: user, topics: topics)
            briefing = fresh
            try? cache.upsert(fresh)
        } catch {
            if briefing == nil {
                briefingError = "Couldn't refresh. Showing cached brief."
            }
        }
    }

    public func markArticleRead(_ articleId: String) {
        guard !readArticleIds.contains(articleId) else { return }
        readArticleIds.insert(articleId)
        try? cache.markRead(articleId: articleId)
        if readArticleIds.count == totalArticles {
            // Slight delay so the user sees the headline fade before the
            // dashboard hands off to the completion screen.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                isCompletionShown = true
            }
        }
    }

    // MARK: - Settings

    public func updateTopics(_ topics: [UserTopic]) async throws {
        guard let user else { return }
        try await backend.profiles.saveTopics(topics, for: user)
        self.topics = topics
        // Per spec: "Changes will apply to tomorrow's briefing."
    }

    public func updatePreferences(_ prefs: UserPreferences) async throws {
        guard let user else { return }
        try await backend.profiles.updatePreferences(prefs, for: user)
        self.preferences = prefs
        try? cache.savePreferences(prefs)
    }

    public func signOut() async {
        try? await backend.auth.signOut()
        user = nil
        topics = []
        briefing = nil
        readArticleIds = []
        isCompletionShown = false
        route = .auth
    }
}

/// Reads `-Key Value` pairs from process launch arguments. Xcode passes
/// scheme-level arguments as `["-MyKey", "myvalue"]` so the value is
/// always the next array element after the key. Returns nil if missing.
@MainActor
private func launchArg(_ args: [String], _ key: String) -> String? {
    guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
    let v = args[i + 1]
    if v.isEmpty || v.hasPrefix("-") { return nil }
    return v
}
