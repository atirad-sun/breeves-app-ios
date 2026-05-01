import SwiftUI
import DesignSystem
import Models

struct PreferencesView: View {
    @Environment(AppModel.self) private var app
    @State private var deliveryDate: Date = {
        var c = DateComponents()
        c.hour = 5; c.minute = 30
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var defaultLens: ReadingLens = .universal
    @State private var saving = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("When should we wake you?")
                .breevesDisplayL()
                .foregroundStyle(BreevesColor.textPrimary)
                .padding(.bottom, BreevesSpace.s7)

            Text("DELIVERY TIME")
                .breevesLabelM()
                .foregroundStyle(BreevesColor.textTertiary)
                .padding(.bottom, BreevesSpace.s3)

            DeliveryTimeWheel(date: $deliveryDate)
                .padding(.bottom, BreevesSpace.s7)

            Text("DEFAULT LENS")
                .breevesLabelM()
                .foregroundStyle(BreevesColor.textTertiary)
                .padding(.bottom, BreevesSpace.s2)

            VStack(spacing: 0) {
                ForEach(Array(ReadingLens.allCases.enumerated()), id: \.element.id) { idx, lens in
                    Button { defaultLens = lens } label: {
                        HStack(alignment: .top, spacing: BreevesSpace.s3) {
                            Rectangle()
                                .fill(defaultLens == lens ? BreevesColor.accentPrimary : Color.clear)
                                .frame(width: 2, height: 24)
                                .padding(.top, 1)
                                .animation(.easeInOut(duration: 0.2), value: defaultLens)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lens.displayName)
                                    .breevesHeadlineS()
                                    .foregroundStyle(defaultLens == lens ? BreevesColor.textPrimary : BreevesColor.textSecondary)
                                Text(lens.shortDescription)
                                    .breevesBodyM()
                                    .foregroundStyle(BreevesColor.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, BreevesSpace.s4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if idx < ReadingLens.allCases.count - 1 {
                        Hairline(strength: .faint)
                    }
                }
            }

            Spacer(minLength: 0)

            if let errorText {
                Text(errorText)
                    .breevesCaption()
                    .foregroundStyle(BreevesColor.stateDanger)
                    .padding(.bottom, BreevesSpace.s2)
            }

            PrimaryButton("Begin", isEnabled: !saving) {
                Task { await save() }
            }
        }
        .padding(.horizontal, BreevesSpace.s5)
        .padding(.top, BreevesSpace.s6)
        .padding(.bottom, BreevesSpace.s5)
        .background(BreevesColor.bgCanvas.ignoresSafeArea())
    }

    private func save() async {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: deliveryDate)
        var prefs = app.preferences
        prefs.notificationHour = comps.hour ?? 5
        prefs.notificationMinute = comps.minute ?? 30
        prefs.defaultLens = defaultLens
        prefs.timezoneIdentifier = TimeZone.current.identifier
        saving = true
        defer { saving = false }
        do {
            try await app.saveOnboardingPreferences(prefs)
        } catch {
            errorText = "Couldn't save preferences. Try again."
        }
    }
}
