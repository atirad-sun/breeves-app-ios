import Foundation

public struct SupabaseConfig: Sendable {
    public let url: URL
    public let anonKey: String
    public let googleClientID: String?

    public init(url: URL, anonKey: String, googleClientID: String? = nil) {
        self.url = url
        self.anonKey = anonKey
        self.googleClientID = googleClientID
    }

    /// Reads `Secrets.plist` from the main bundle. Returns `nil` when absent —
    /// callers must fall back to the local mock backend in that case.
    public static func fromBundle(_ bundle: Bundle = .main) -> SupabaseConfig? {
        guard
            let path = bundle.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
            let urlString = dict["SUPABASE_URL"] as? String,
            let url = URL(string: urlString),
            let key = dict["SUPABASE_ANON_KEY"] as? String,
            !urlString.isEmpty,
            !key.isEmpty
        else { return nil }
        return SupabaseConfig(
            url: url,
            anonKey: key,
            googleClientID: dict["GOOGLE_CLIENT_ID"] as? String
        )
    }
}
