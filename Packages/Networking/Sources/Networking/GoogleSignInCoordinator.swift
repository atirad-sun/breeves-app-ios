import Foundation
import UIKit
@preconcurrency import GoogleSignIn

/// Wraps the GoogleSignIn iOS SDK in an async API. Configures the shared
/// `GIDSignIn` with the OAuth client ID resolved from `Secrets.plist` via
/// `SupabaseConfig.googleClientID`. The mock backend path bypasses this
/// coordinator entirely (see `BreevesBackend.resolve()` mode gating).
@MainActor
public final class GoogleSignInCoordinator {
    public static let shared = GoogleSignInCoordinator()

    private var configured = false

    private init() {}

    public var isConfigured: Bool { configured }

    public func configure(clientID: String) {
        guard !configured else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        configured = true
    }

    public func signIn(presenting: UIViewController) async throws -> (idToken: String, accessToken: String) {
        // GID crashes hard with NSInvalidArgumentException if configuration
        // is nil. Throw a typed error instead so the UI can show a polite
        // message ("Google Sign-In not set up yet — try Apple instead.").
        guard configured else { throw GoogleSignInError.notConfigured }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.missingIDToken
        }
        return (idToken: idToken, accessToken: result.user.accessToken.tokenString)
    }

    public func handle(url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    public func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}

public enum GoogleSignInError: Error, LocalizedError {
    case missingIDToken
    case noPresentingViewController
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .missingIDToken: return "Google sign-in returned no ID token."
        case .noPresentingViewController: return "Couldn't find a view controller to present sign-in."
        case .notConfigured: return "Google Sign-In isn't set up yet. Try Apple instead."
        }
    }
}
