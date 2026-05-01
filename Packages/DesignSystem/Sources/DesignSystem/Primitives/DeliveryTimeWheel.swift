import SwiftUI

/// Wheel-style hour/minute picker styled to sit on `bgCanvas`. Shared between
/// onboarding `PreferencesView` and the Settings delivery-time sheet.
public struct DeliveryTimeWheel: View {
    @Binding var date: Date

    public init(date: Binding<Date>) {
        self._date = date
    }

    public var body: some View {
        DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: 168)
            .background(BreevesColor.bgElevated1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BreevesColor.hairlineStandard, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .colorScheme(.dark)
    }
}

extension DeliveryTimeWheel {
    /// Build a `Date` for today at the given hour/minute. Convenience for callers
    /// that store the time as components.
    public static func date(hour: Int, minute: Int) -> Date {
        var c = DateComponents()
        c.hour = hour
        c.minute = minute
        return Calendar.current.date(from: c) ?? Date()
    }

    /// Decompose a `Date` into hour/minute. Convenience for save paths.
    public static func components(from date: Date) -> (hour: Int, minute: Int) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 5, c.minute ?? 30)
    }
}
