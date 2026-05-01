import SwiftUI
import DesignSystem

struct CompletionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var ringProgress: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(formattedDate())
                    .breevesCaption()
                    .foregroundStyle(BreevesColor.textTertiary)
                    .textCase(.uppercase)
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

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                ProgressRing(progress: ringProgress)
                    .padding(.bottom, BreevesSpace.s7)

                Text("You're all caught up for today.")
                    .breevesDisplayXL()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BreevesColor.textPrimary)
                    .padding(.bottom, BreevesSpace.s4)
                    .padding(.horizontal, BreevesSpace.s5)

                Text("Tomorrow's brief lands at \(deliveryTime()).")
                    .breevesBodyL()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BreevesColor.textSecondary)
                    .padding(.bottom, BreevesSpace.s6)

                Text(statsLine())
                    .breevesMonoS()
                    .foregroundStyle(BreevesColor.textTertiary)
                    .textCase(.uppercase)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BreevesColor.bgCanvas.ignoresSafeArea())
        .onAppear {
            ringProgress = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                ringProgress = 1.0
            }
        }
    }

    private func deliveryTime() -> String {
        var c = DateComponents()
        c.hour = app.preferences.notificationHour
        c.minute = app.preferences.notificationMinute
        let date = Calendar.current.date(from: c) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · dd MMM"
        return f.string(from: Date()).uppercased()
    }

    private func statsLine() -> String {
        // Time *saved*: full-article minutes minus the ~30-min summary brief.
        let articleCount = app.totalArticles
        let totalFullMinutes = (app.briefing?.topics.flatMap(\.articles) ?? [])
            .reduce(0) { $0 + $1.estimatedReadTimeMinutes }
        let saved = max(0, totalFullMinutes - Int(Double(articleCount) * 1.7))
        let words = totalFullMinutes * 240  // ~240 wpm at executive read pace
        return "\(saved) MIN SAVED · \(formatNumber(words)) WORDS · \(articleCount) / \(articleCount)"
    }

    private func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
