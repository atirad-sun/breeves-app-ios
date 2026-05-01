import SwiftUI

public struct LensToggle: View {
    @Binding var selection: Int
    let labels: [String]

    public init(selection: Binding<Int>, labels: [String] = ["Universal", "Deep Dive", "Action"]) {
        self._selection = selection
        self.labels = labels
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
                        Text(label)
                            .breevesCaption()
                            .fontWeight(.semibold)
                            .foregroundStyle(idx == selection ? BreevesColor.textPrimary : BreevesColor.textSecondary)
                            .animation(BreevesMotion.lensToggle, value: selection)
                        // Accent underline on the active segment
                        Rectangle()
                            .fill(idx == selection ? BreevesColor.accentPrimary : Color.clear)
                            .frame(width: 16, height: 1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}
