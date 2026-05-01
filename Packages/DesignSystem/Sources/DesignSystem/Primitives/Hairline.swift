import SwiftUI

public enum HairlineStrength {
    case faint, standard, strong

    var color: Color {
        switch self {
        case .faint: return BreevesColor.hairlineFaint
        case .standard: return BreevesColor.hairlineStandard
        case .strong: return BreevesColor.hairlineStrong
        }
    }
}

public struct Hairline: View {
    let strength: HairlineStrength
    let vertical: Bool

    public init(strength: HairlineStrength = .standard, vertical: Bool = false) {
        self.strength = strength
        self.vertical = vertical
    }

    public var body: some View {
        Rectangle()
            .fill(strength.color)
            .frame(
                width: vertical ? 1 : nil,
                height: vertical ? nil : 1
            )
    }
}

/// 1×24pt vertical accent hairline — the recurring brand mark.
public struct BrassMark: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(BreevesColor.accentPrimary)
            .frame(width: 1, height: 24)
            .accessibilityHidden(true)
    }
}

/// Faint dotted line filling the gap between counter and read-time. Brand signature.
public struct DotLeader: View {
    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let dotSize: CGFloat = 1.5
            let gap: CGFloat = 4
            let count = max(0, Int(geo.size.width / (dotSize + gap)))
            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(BreevesColor.textTertiary)
                        .frame(width: dotSize, height: dotSize)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .opacity(0.4)
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}
