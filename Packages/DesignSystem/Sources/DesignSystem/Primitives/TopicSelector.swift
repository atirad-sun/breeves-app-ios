import SwiftUI

public struct TopicSelector: View {
    @Binding var selection: Int
    let labels: [String]
    let topicColors: [Color]
    let compact: Bool

    public init(
        selection: Binding<Int>,
        labels: [String],
        topicColors: [Color],
        compact: Bool = false
    ) {
        self._selection = selection
        self.labels = labels
        self.topicColors = topicColors
        self.compact = compact
    }

    /// First-three-letters abbreviation used in compact mode (e.g.
    /// "Finance" → "Fin", "Geopolitics" → "Geo", "AI" stays "AI").
    private func displayLabel(_ raw: String) -> String {
        guard compact else { return raw }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.count <= 3 { return trimmed }
        return String(trimmed.prefix(3))
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { idx, label in
                Button {
                    withAnimation(BreevesMotion.lensToggle) {
                        selection = idx
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(displayLabel(label))
                            .breevesCaption()
                            .fontWeight(.semibold)
                            .foregroundStyle(idx == selection ? BreevesColor.textPrimary : BreevesColor.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .animation(BreevesMotion.lensToggle, value: selection)
                        Rectangle()
                            .fill(idx == selection ? topicColor(idx) : Color.clear)
                            .frame(width: 16, height: 1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 4)
                    .background(
                        Rectangle()
                            .fill(idx == selection ? BreevesColor.bgCanvas : Color.clear)
                            .animation(BreevesMotion.lensToggle, value: selection)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityAddTraits(idx == selection ? [.isSelected, .isButton] : [.isButton])
            }
        }
        .frame(height: 40)
        .background(BreevesColor.bgElevated1)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(BreevesColor.hairlineStandard, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func topicColor(_ idx: Int) -> Color {
        guard topicColors.indices.contains(idx) else { return BreevesColor.accentPrimary }
        return topicColors[idx]
    }
}
