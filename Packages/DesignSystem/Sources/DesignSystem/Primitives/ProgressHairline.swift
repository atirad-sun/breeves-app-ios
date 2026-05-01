import SwiftUI

public struct ProgressHairline: View {
    let read: Int
    let total: Int
    /// Used to compute the "~N MIN LEFT" label. With 18 articles totalling
    /// ≤30 minutes, default ~1.7 min/article keeps the "30-minute brief"
    /// promise in the metadata.
    let minutesPerArticle: Double

    public init(read: Int, total: Int, minutesPerArticle: Double = 1.7) {
        self.read = read
        self.total = total
        self.minutesPerArticle = minutesPerArticle
    }

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(read) / Double(total)
    }

    private var minutesLeft: Int {
        max(0, Int((Double(total - read) * minutesPerArticle).rounded()))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(twoDigit(read)) / \(twoDigit(total))")
                    .breevesMonoS()
                    .foregroundStyle(BreevesColor.textSecondary)
                Spacer()
                Text("~\(minutesLeft) MIN LEFT")
                    .breevesMonoS()
                    .foregroundStyle(BreevesColor.textTertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(read) of \(total) articles read, about \(minutesLeft) minutes left")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(BreevesColor.hairlineStandard)
                    Rectangle()
                        .fill(BreevesColor.accentPrimary)
                        .frame(width: geo.size.width * CGFloat(fraction))
                        .animation(BreevesMotion.progressBar, value: fraction)
                }
            }
            .frame(height: 1)
        }
        .accessibilityHint("Daily reading progress")
    }

    private func twoDigit(_ n: Int) -> String {
        String(format: "%02d", n)
    }
}

public struct ProgressRing: View {
    let progress: Double
    let diameter: CGFloat
    let lineWidth: CGFloat

    public init(progress: Double, diameter: CGFloat = 120, lineWidth: CGFloat = 3) {
        self.progress = progress
        self.diameter = diameter
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(BreevesColor.hairlineStandard, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(
                    BreevesColor.accentPrimary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))
                .animation(BreevesMotion.progressRing, value: progress)
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BreevesColor.accentPrimary)
                .opacity(progress >= 1 ? 1 : 0)
                .animation(.easeIn(duration: 0.2).delay(0.4), value: progress)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
