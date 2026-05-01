import SwiftUI
import DesignSystem
import Models

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var showTopicAlert = false
    @State private var showSignOutAlert = false
    @State private var showManageTopics = ProcessInfo.processInfo.arguments.contains("-BREEVES_MANAGE_TOPICS")
    @State private var didSaveTopics = false
    @State private var showTimeSheet = ProcessInfo.processInfo.arguments.contains("-BREEVES_DELIVERY_TIME")
    @State private var comingSoonTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Hairline()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topicsSection
                    deliverySection
                    lensSection
                    appearanceSection
                    accountSection
                    aboutSection
                    Spacer().frame(height: BreevesSpace.s7)
                }
                .padding(.horizontal, BreevesSpace.s5)
            }
        }
        .background(BreevesColor.bgCanvas.ignoresSafeArea())
        .alert("Topic changes will apply to tomorrow's brief.", isPresented: $showTopicAlert) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $showManageTopics, onDismiss: {
            if didSaveTopics {
                didSaveTopics = false
                showTopicAlert = true
            }
        }) {
            ManageTopicsView(didSave: $didSaveTopics)
                .environment(app)
        }
        .sheet(isPresented: $showTimeSheet) {
            DeliveryTimeSheet(initial: app.preferences) { newPrefs in
                Task { try? await app.updatePreferences(newPrefs) }
            }
        }
        .alert(
            comingSoonTitle ?? "",
            isPresented: Binding(
                get: { comingSoonTitle != nil },
                set: { if !$0 { comingSoonTitle = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Coming soon.")
        }
        .alert("Sign out of Breeves?", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    dismiss()
                    await app.signOut()
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .breevesDisplayL()
                .foregroundStyle(BreevesColor.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(BreevesColor.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, BreevesSpace.s5)
        .padding(.top, BreevesSpace.s4)
        .padding(.bottom, BreevesSpace.s3)
    }

    // MARK: - Topics

    private var topicsSection: some View {
        Group {
            SectionHeader("YOUR TOPICS")

            VStack(spacing: 0) {
                ForEach(Array(app.topics.enumerated()), id: \.element.id) { idx, topic in
                    HStack(alignment: .top, spacing: BreevesSpace.s3) {
                        Rectangle()
                            .fill(BreevesColor.topic(slot: idx))
                            .frame(width: 2, height: 28)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(topic.name)
                                .breevesBodyM()
                                .fontWeight(.semibold)
                                .foregroundStyle(BreevesColor.textPrimary)
                            if let desc = topic.descriptionText {
                                Text(desc)
                                    .breevesCaption()
                                    .foregroundStyle(BreevesColor.textTertiary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(BreevesColor.textTertiary)
                    }
                    .padding(.horizontal, BreevesSpace.s4)
                    .padding(.vertical, BreevesSpace.s3)
                    if idx < app.topics.count - 1 {
                        Hairline(strength: .faint)
                    }
                }
            }
            .background(BreevesColor.bgElevated1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BreevesColor.hairlineStandard, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                showManageTopics = true
            } label: {
                HStack(spacing: BreevesSpace.s2) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Manage topics")
                        .breevesCaption()
                        .fontWeight(.semibold)
                }
                .foregroundStyle(BreevesColor.accentPrimary)
                .padding(.vertical, BreevesSpace.s2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Delivery

    @ViewBuilder
    private var deliverySection: some View {
        @Bindable var bindable = app
        SectionHeader("DAILY DELIVERY")

        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Morning notification")
                        .breevesBodyM()
                        .fontWeight(.semibold)
                        .foregroundStyle(BreevesColor.textPrimary)
                    Text("Alert when brief is ready")
                        .breevesCaption()
                        .foregroundStyle(BreevesColor.textTertiary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { app.preferences.notificationEnabled },
                    set: { newValue in
                        var p = app.preferences
                        p.notificationEnabled = newValue
                        Task { try? await app.updatePreferences(p) }
                    }
                ))
                .labelsHidden()
                .tint(BreevesColor.accentPrimary)
            }
            .padding(BreevesSpace.s4)

            Hairline(strength: .faint)

            Button { showTimeSheet = true } label: {
                HStack {
                    Text("Delivery time")
                        .breevesBodyM()
                        .fontWeight(.semibold)
                        .foregroundStyle(BreevesColor.textPrimary)
                    Spacer()
                    let time = formattedTime(hour: app.preferences.notificationHour, minute: app.preferences.notificationMinute)
                    Text(time)
                        .breevesBodyM()
                        .fontWeight(.semibold)
                        .foregroundStyle(BreevesColor.accentPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BreevesColor.textTertiary)
                }
                .padding(BreevesSpace.s4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!app.preferences.notificationEnabled)
            .opacity(app.preferences.notificationEnabled ? 1 : 0.4)

            Hairline(strength: .faint)

            VStack(alignment: .leading, spacing: BreevesSpace.s3) {
                HStack {
                    Text("Brief length")
                        .breevesBodyM()
                        .fontWeight(.semibold)
                        .foregroundStyle(BreevesColor.textPrimary)
                    Spacer()
                    Text(app.preferences.briefLength.displayName)
                        .breevesCaption()
                        .foregroundStyle(BreevesColor.accentPrimary)
                }
                HStack(spacing: BreevesSpace.s2) {
                    ForEach(BriefLength.allCases) { length in
                        let isOn = app.preferences.briefLength == length
                        Button {
                            var p = app.preferences
                            p.briefLength = length
                            Task { try? await app.updatePreferences(p) }
                        } label: {
                            Text(length.displayName)
                                .breevesCaption()
                                .fontWeight(.semibold)
                                .foregroundStyle(isOn ? BreevesColor.textInverse : BreevesColor.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .background(isOn ? BreevesColor.accentPrimary : .clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isOn ? BreevesColor.accentPrimary : BreevesColor.hairlineStrong, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(BreevesSpace.s4)
        }
        .background(BreevesColor.bgElevated1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BreevesColor.hairlineStandard, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Lens

    private var lensSection: some View {
        Group {
            SectionHeader("DEFAULT READING LENS")
            VStack(spacing: 0) {
                ForEach(Array(ReadingLens.allCases.enumerated()), id: \.element.id) { idx, lens in
                    let active = app.preferences.defaultLens == lens
                    Button {
                        var p = app.preferences
                        p.defaultLens = lens
                        Task { try? await app.updatePreferences(p) }
                    } label: {
                        HStack(spacing: BreevesSpace.s3) {
                            Rectangle()
                                .fill(active ? BreevesColor.accentPrimary : .clear)
                                .frame(width: 2, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lens.displayName)
                                    .breevesBodyM()
                                    .fontWeight(.semibold)
                                    .foregroundStyle(active ? BreevesColor.textPrimary : BreevesColor.textSecondary)
                                Text(lens.shortDescription)
                                    .breevesCaption()
                                    .foregroundStyle(BreevesColor.textTertiary)
                            }
                            Spacer()
                            if active {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(BreevesColor.accentPrimary)
                            }
                        }
                        .padding(.horizontal, BreevesSpace.s4)
                        .padding(.vertical, BreevesSpace.s3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if idx < ReadingLens.allCases.count - 1 {
                        Hairline(strength: .faint)
                    }
                }
            }
            .background(BreevesColor.bgElevated1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BreevesColor.hairlineStandard, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Group {
            SectionHeader("APPEARANCE")
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Text size")
                            .breevesBodyM()
                            .fontWeight(.semibold)
                            .foregroundStyle(BreevesColor.textPrimary)
                        Text("Follows system Dynamic Type")
                            .breevesCaption()
                            .foregroundStyle(BreevesColor.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BreevesColor.textTertiary)
                }
                .padding(BreevesSpace.s4)

                Hairline(strength: .faint)

                HStack {
                    Text("Colour scheme")
                        .breevesBodyM()
                        .fontWeight(.semibold)
                        .foregroundStyle(BreevesColor.textPrimary)
                    Spacer()
                    Menu {
                        ForEach(ColorSchemePreference.allCases) { scheme in
                            Button(scheme.displayName) {
                                var p = app.preferences
                                p.colorScheme = scheme
                                Task { try? await app.updatePreferences(p) }
                            }
                        }
                    } label: {
                        HStack(spacing: BreevesSpace.s2) {
                            Text(app.preferences.colorScheme.displayName)
                                .breevesBodyM()
                                .foregroundStyle(BreevesColor.accentPrimary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(BreevesColor.textTertiary)
                        }
                    }
                }
                .padding(BreevesSpace.s4)
            }
            .background(BreevesColor.bgElevated1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BreevesColor.hairlineStandard, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Group {
            SectionHeader("ACCOUNT")
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Signed in as")
                        .breevesCaption()
                        .foregroundStyle(BreevesColor.textTertiary)
                    Text(app.user?.email ?? "anonymous")
                        .breevesBodyM()
                        .fontWeight(.semibold)
                        .foregroundStyle(BreevesColor.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BreevesSpace.s4)

                Hairline(strength: .faint)

                HStack {
                    Text("Subscription")
                        .breevesBodyM()
                        .fontWeight(.semibold)
                        .foregroundStyle(BreevesColor.textPrimary)
                    Spacer()
                    Text("PRO")
                        .breevesCaption()
                        .fontWeight(.semibold)
                        .foregroundStyle(BreevesColor.accentPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(BreevesColor.accentPrimary.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(BreevesColor.accentPrimary.opacity(0.4), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(BreevesSpace.s4)

                Hairline(strength: .faint)

                Button { comingSoonTitle = "Privacy & data" } label: {
                    HStack {
                        Text("Privacy & data")
                            .breevesBodyM()
                            .fontWeight(.semibold)
                            .foregroundStyle(BreevesColor.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(BreevesColor.textTertiary)
                    }
                    .padding(BreevesSpace.s4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Hairline(strength: .faint)

                Button { showSignOutAlert = true } label: {
                    HStack {
                        Text("Sign Out")
                            .breevesBodyM()
                            .fontWeight(.semibold)
                            .foregroundStyle(BreevesColor.stateDanger)
                        Spacer()
                    }
                    .padding(BreevesSpace.s4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(BreevesColor.bgElevated1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BreevesColor.hairlineStandard, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var aboutSection: some View {
        Group {
            SectionHeader("ABOUT")
            VStack(spacing: 0) {
                HStack {
                    Text("Version")
                        .breevesBodyM()
                        .fontWeight(.semibold)
                        .foregroundStyle(BreevesColor.textPrimary)
                    Spacer()
                    Text("1.0.0 (build 42)")
                        .breevesBodyM()
                        .foregroundStyle(BreevesColor.textTertiary)
                }
                .padding(BreevesSpace.s4)

                Hairline(strength: .faint)

                aboutRow("Terms of Service") { comingSoonTitle = "Terms of Service" }
                Hairline(strength: .faint)
                aboutRow("Privacy Policy") { comingSoonTitle = "Privacy Policy" }
            }
            .background(BreevesColor.bgElevated1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BreevesColor.hairlineStandard, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func aboutRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .breevesBodyM()
                    .fontWeight(.semibold)
                    .foregroundStyle(BreevesColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BreevesColor.textTertiary)
            }
            .padding(BreevesSpace.s4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        var c = DateComponents()
        c.hour = hour; c.minute = minute
        guard let d = Calendar.current.date(from: c) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: d)
    }
}
