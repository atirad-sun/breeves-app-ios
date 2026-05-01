import Foundation
import Supabase

public struct BreevesBackend: Sendable {
    public let auth: AuthService
    public let profiles: ProfileService
    public let briefings: BriefingService
    public let mode: Mode
    public let googleClientID: String?

    public enum Mode: String, Sendable { case live, mock }

    public init(
        auth: AuthService,
        profiles: ProfileService,
        briefings: BriefingService,
        mode: Mode,
        googleClientID: String? = nil
    ) {
        self.auth = auth
        self.profiles = profiles
        self.briefings = briefings
        self.mode = mode
        self.googleClientID = googleClientID
    }

    public static func resolve(bundle: Bundle = .main) -> BreevesBackend {
        if let cfg = SupabaseConfig.fromBundle(bundle) {
            let client = SupabaseClient(supabaseURL: cfg.url, supabaseKey: cfg.anonKey)
            return BreevesBackend(
                auth: SupabaseAuthService(client: client),
                profiles: SupabaseProfileService(client: client),
                briefings: SupabaseBriefingService(client: client),
                mode: .live,
                googleClientID: cfg.googleClientID
            )
        } else {
            let backend = MockBackend()
            return BreevesBackend(
                auth: MockAuthService(backend: backend),
                profiles: MockProfileService(backend: backend),
                briefings: MockBriefingService(backend: backend),
                mode: .mock
            )
        }
    }
}
