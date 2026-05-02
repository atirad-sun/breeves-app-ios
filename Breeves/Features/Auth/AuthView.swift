import SwiftUI
import UIKit
import AuthenticationServices
import DesignSystem
import Networking

struct AuthView: View {
    @Environment(AppModel.self) private var app
    @State private var rawNonce: String = ""
    @State private var errorMessage: String?
    @State private var showEmailSheet: Bool = false

    /// Mock backend always shows Google for the demo. Live backend hides
    /// it when GOOGLE_CLIENT_ID is missing — invoking GID without a
    /// configured clientID crashes the app via NSInvalidArgumentException.
    private var isGoogleAvailable: Bool {
        if app.backend.mode == .mock { return true }
        guard let id = app.backend.googleClientID, !id.isEmpty else { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: BreevesSpace.s3) {
                BrassMark()
                Text("Breeves")
                    .breevesDisplayXL()
                    .foregroundStyle(BreevesColor.textPrimary)
                Text("A 30-minute morning brief.\nThree topics. No noise.")
                    .breevesBodyM()
                    .foregroundStyle(BreevesColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            Spacer(minLength: 0)

            VStack(spacing: BreevesSpace.s3) {
                SignInWithAppleButton(.continue,
                    onRequest: { request in
                        let nonce = NonceGenerator.random()
                        rawNonce = nonce
                        request.requestedScopes = [.email]
                        request.nonce = NonceGenerator.sha256(nonce)
                    },
                    onCompletion: { result in
                        Task {
                            switch result {
                            case .success(let authorization):
                                do {
                                    let user = try await app.backend.auth.signInWithApple(authorization: authorization, rawNonce: rawNonce)
                                    await app.handleSignedIn(user)
                                } catch {
                                    errorMessage = "Apple sign-in failed."
                                }
                            case .failure:
                                errorMessage = "Apple sign-in cancelled."
                            }
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if isGoogleAvailable {
                    Button {
                        Task { await mockGoogleSignIn() }
                    } label: {
                        HStack(spacing: 10) {
                            GoogleGMark().frame(width: 20, height: 20)
                            Text("Continue with Google")
                                .breevesBodyL()
                                .fontWeight(.semibold)
                                .foregroundStyle(BreevesColor.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(BreevesColor.bgElevated1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(BreevesColor.hairlineStandard, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Continue with Google")
                }

                Button {
                    showEmailSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(BreevesColor.textPrimary)
                        Text("Continue with Email")
                            .breevesBodyL()
                            .fontWeight(.semibold)
                            .foregroundStyle(BreevesColor.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(BreevesColor.bgElevated1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BreevesColor.hairlineStandard, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue with Email")

                if let error = errorMessage {
                    Text(error)
                        .breevesCaption()
                        .foregroundStyle(BreevesColor.stateDanger)
                        .padding(.top, BreevesSpace.s2)
                }

                tosLine
                    .padding(.top, BreevesSpace.s2)
            }
            .padding(.horizontal, BreevesSpace.s5)
            .padding(.bottom, BreevesSpace.s5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, BreevesSpace.s7)
        .background(BreevesColor.bgCanvas.ignoresSafeArea())
        .sheet(isPresented: $showEmailSheet) {
            EmailAuthSheet { user in
                await app.handleSignedIn(user)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var tosLine: some View {
        (Text("By continuing, you agree to our ")
         + Text("Terms").underline()
         + Text(" and ")
         + Text("Privacy Policy").underline())
        .font(BreevesFont.caption)
        .foregroundStyle(BreevesColor.textTertiary)
        .multilineTextAlignment(.center)
    }

    private func mockGoogleSignIn() async {
        if app.backend.mode == .live {
            await liveGoogleSignIn()
            return
        }
        do {
            let user = try await app.backend.auth.signInWithGoogle(idToken: "mock", accessToken: nil)
            await app.handleSignedIn(user)
        } catch {
            errorMessage = "Google sign-in failed."
        }
    }

    private func liveGoogleSignIn() async {
        guard GoogleSignInCoordinator.shared.isConfigured else {
            errorMessage = "Google Sign-In isn't set up yet. Use Continue with Apple instead."
            return
        }
        guard let presenter = topViewController() else {
            errorMessage = "Couldn't open Google sign-in."
            return
        }
        do {
            let tokens = try await GoogleSignInCoordinator.shared.signIn(presenting: presenter)
            let user = try await app.backend.auth.signInWithGoogle(
                idToken: tokens.idToken,
                accessToken: tokens.accessToken
            )
            await app.handleSignedIn(user)
        } catch let err as GoogleSignInError {
            errorMessage = err.errorDescription ?? "Google sign-in failed."
        } catch {
            errorMessage = "Google sign-in failed."
        }
    }

    private func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let root = scene?.keyWindow?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

private struct GoogleGMark: View {
    var body: some View {
        ZStack {
            // Approximate Google "G" with vector paths. Brand-color quadrants.
            Image(systemName: "g.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white, .blue)
        }
    }
}
