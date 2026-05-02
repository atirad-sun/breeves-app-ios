import Foundation
import AuthenticationServices
import Supabase

public protocol AuthService: AnyObject, Sendable {
    var currentUser: BreevesUser? { get async }
    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws -> BreevesUser
    func signInWithGoogle(idToken: String, accessToken: String?) async throws -> BreevesUser
    /// Email/password sign-in. Surfaced in the UI behind the
    /// "Continue with Email" entry point; also the only auth path that
    /// works on a free Apple personal team (no Apple-Sign-In entitlement).
    func signInWithEmailPassword(email: String, password: String) async throws -> BreevesUser
    /// Create a new account with email/password. Returns the signed-in
    /// user on success — Supabase auto-signs in after sign-up when email
    /// confirmation is disabled (the default for the dev project).
    func signUpWithEmailPassword(email: String, password: String) async throws -> BreevesUser
    func signOut() async throws
}

// MARK: - Real (Supabase) implementation

public final class SupabaseAuthService: AuthService, @unchecked Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public var currentUser: BreevesUser? {
        get async {
            do {
                let session = try await client.auth.session
                let u = session.user
                return BreevesUser(
                    id: u.id.uuidString,
                    email: u.email,
                    provider: u.appMetadata["provider"]?.stringValue
                )
            } catch {
                return nil
            }
        }
    }

    public func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws -> BreevesUser {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthError.invalidAppleCredential
        }

        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: rawNonce)
        )
        let u = session.user
        return BreevesUser(id: u.id.uuidString, email: u.email, provider: "apple")
    }

    public func signInWithGoogle(idToken: String, accessToken: String?) async throws -> BreevesUser {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
        )
        let u = session.user
        return BreevesUser(id: u.id.uuidString, email: u.email, provider: "google")
    }

    public func signInWithEmailPassword(email: String, password: String) async throws -> BreevesUser {
        let session = try await client.auth.signIn(email: email, password: password)
        let u = session.user
        return BreevesUser(id: u.id.uuidString, email: u.email, provider: "email")
    }

    public func signUpWithEmailPassword(email: String, password: String) async throws -> BreevesUser {
        let response = try await client.auth.signUp(email: email, password: password)
        let u = response.user
        return BreevesUser(id: u.id.uuidString, email: u.email, provider: "email")
    }

    public func signOut() async throws {
        try await client.auth.signOut()
    }
}

public enum AuthError: Error, LocalizedError {
    case invalidAppleCredential
    case notImplemented

    public var errorDescription: String? {
        switch self {
        case .invalidAppleCredential: return "Apple sign-in returned an invalid credential."
        case .notImplemented: return "This sign-in method is not available in this build."
        }
    }
}
