import SwiftUI
import DesignSystem
import Models

struct DeliveryTimeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initial: UserPreferences
    let onSave: (UserPreferences) -> Void

    @State private var date: Date

    init(initial: UserPreferences, onSave: @escaping (UserPreferences) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _date = State(initialValue: DeliveryTimeWheel.date(
            hour: initial.notificationHour,
            minute: initial.notificationMinute
        ))
    }

    private var hasChanges: Bool {
        let picked = DeliveryTimeWheel.components(from: date)
        return picked.hour != initial.notificationHour || picked.minute != initial.notificationMinute
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Hairline()

            VStack(alignment: .leading, spacing: 0) {
                Text("DELIVERY TIME")
                    .breevesLabelM()
                    .foregroundStyle(BreevesColor.textTertiary)
                    .padding(.bottom, BreevesSpace.s3)

                DeliveryTimeWheel(date: $date)

                Text("Your brief is generated and ready in your inbox at this local time each morning.")
                    .breevesCaption()
                    .foregroundStyle(BreevesColor.textTertiary)
                    .padding(.top, BreevesSpace.s3)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, BreevesSpace.s5)
            .padding(.top, BreevesSpace.s5)
        }
        .background(BreevesColor.bgCanvas.ignoresSafeArea())
        .interactiveDismissDisabled(hasChanges)
        .presentationDetents([.medium])
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Button { dismiss() } label: {
                Text("Cancel")
                    .breevesBodyM()
                    .foregroundStyle(BreevesColor.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Delivery time")
                .breevesHeadlineS()
                .foregroundStyle(BreevesColor.textPrimary)

            Spacer()

            Button { save() } label: {
                Text("Save")
                    .breevesBodyM()
                    .fontWeight(.semibold)
                    .foregroundStyle(hasChanges ? BreevesColor.accentPrimary : BreevesColor.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!hasChanges)
        }
        .padding(.horizontal, BreevesSpace.s5)
        .padding(.top, BreevesSpace.s4)
        .padding(.bottom, BreevesSpace.s3)
    }

    private func save() {
        let picked = DeliveryTimeWheel.components(from: date)
        var prefs = initial
        prefs.notificationHour = picked.hour
        prefs.notificationMinute = picked.minute
        onSave(prefs)
        dismiss()
    }
}
