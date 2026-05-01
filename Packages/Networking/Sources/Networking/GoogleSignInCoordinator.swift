import Foundation
import UIKit
import GoogleSignIn

/// Wraps the GoogleSignIn iOS SDK in an async API. Configures the shared
/// `GIDSignIn` with the OAuth client ID resolved from `Secrets.plist` via
/// `SupabaseConfig.googleClientID`. The mock backend path bypasses this
/// coordinator entirely (see `BreevesBackend.resolve()` mode gating).
@MainActor
public final class GoogleSignInCoordinator {
    public static let shared = GoogleSignInCoordinator()

    private var configured = false

    private init() {}

    public func configure(clientID: String) {
        guard !configured else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        configured = true
    }

    public func signIn(presenting: UIViewController) async throws -> (idToken: String, accessToken: String) {
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

    public var errorDescription: String? {
        switch self {
        case .missingIDToken: return "Google sign-in returned no ID token."
        case .noPresentingViewController: return "Couldn't find a view controller to present sign-in."
        }
    }
}
