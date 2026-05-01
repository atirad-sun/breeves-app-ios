import Foundation

public struct BreevesUser: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let email: String?
    public let provider: String?

    public init(id: String, email: String? = nil, provider: String? = nil) {
        self.id = id
        self.email = email
        self.provider = provider
    }
}
