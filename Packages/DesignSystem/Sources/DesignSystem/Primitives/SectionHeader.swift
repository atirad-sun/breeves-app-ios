import SwiftUI

public struct SectionHeader: View {
    let label: String
    let topPadding: CGFloat

    public init(_ label: String, topPadding: CGFloat = BreevesSpace.s6) {
        self.label = label
        self.topPadding = topPadding
    }

    public var body: some View {
        Text(label)
            .breevesLabelM()
            .foregroundStyle(BreevesColor.textTertiary)
            .padding(.top, topPadding)
            .padding(.bottom, BreevesSpace.s2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}
