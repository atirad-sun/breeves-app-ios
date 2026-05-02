import SwiftUI
import DesignSystem
import Networking

/// Email + password sign-in / sign-up sheet. Surfaced from AuthView's
/// "Continue with Email" entry point. Used when Apple Sign-In is
/// unavailable (free Apple personal team can't sign the entitlement) or
/// when the user prefers email auth.
///
/// Scope intentionally narrow: no password reset, no magic links, no
/// social-account-link UI. Those land in a later auth pass.
struct EmailAuthSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign in"
        case signUp = "Create account"
        var id: String { rawValue }
    }

    let onSignedIn: (BreevesUser) async -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?
    private enum Field { case email, password }

    private var canSubmit: Bool {
        let emailLooksValid = email.contains("@") && email.contains(".")
        return emailLooksValid && password.count >= 8 && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BreevesSpace.s5) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in errorMessage = nil }

                VStack(alignment: .leading, spacing: BreevesSpace.s4) {
                    fieldGroup(title: "EMAIL") {
                        TextField("you@example.com", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }
                    fieldGroup(title: "PASSWORD") {
                        SecureField("at least 8 characters", text: $password)
                            .textContentType(mode == .signIn ? .password : .newPassword)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit {
                                if canSubmit { Task { await submit() } }
                            }
                    }
                }

                if let err = errorMessage {
                    Text(err)
                        .breevesCaption()
                        .foregroundStyle(BreevesColor.stateDanger)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: BreevesSpace.s2) {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text(isSubmitting ? "Working…" : mode.rawValue)
                            .breevesBodyL()
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSubmit ? BreevesColor.accentPrimary : BreevesColor.accentMuted)
                    .foregroundStyle(BreevesColor.textInverse)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, BreevesSpace.s5)
            .padding(.top, BreevesSpace.s5)
            .navigationTitle(mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
            }
            .background(BreevesColor.bgCanvas.ignoresSafeArea())
            .onAppear { focusedField = .email }
        }
    }

    private func fieldGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BreevesSpace.s2) {
            Text(title)
                .breevesLabelM()
                .foregroundStyle(BreevesColor.textTertiary)
            content()
                .font(BreevesFont.bodyM)
                .foregroundStyle(BreevesColor.textPrimary)
                .padding(.horizontal, BreevesSpace.s3)
                .frame(height: 48)
                .background(BreevesColor.bgElevated1)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(BreevesColor.hairlineStandard, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func submit() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let user: BreevesUser
            switch mode {
            case .signIn:
                user = try await app.backend.auth.signInWithEmailPassword(email: trimmedEmail, password: password)
            case .signUp:
                user = try await app.backend.auth.signUpWithEmailPassword(email: trimmedEmail, password: password)
            }
            await onSignedIn(user)
            dismiss()
        } catch {
            // Supabase returns localized messages; show those when present,
            // fall back to a generic line otherwise. Bad-credential and
            // duplicate-email errors both flow through here.
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let raw = (error as NSError).localizedDescription.lowercased()
        if raw.contains("invalid") && raw.contains("credentials") {
            return "Email or password is incorrect."
        }
        if raw.contains("already") || raw.contains("registered") {
            return "An account with that email already exists. Try signing in."
        }
        if raw.contains("password") && raw.contains("short") {
            return "Password must be at least 8 characters."
        }
        return error.localizedDescription
    }
}
