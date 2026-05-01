import SwiftUI

public struct PrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    public init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .breevesBodyL()
                .fontWeight(.semibold)
                .foregroundStyle(BreevesColor.accentPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(BreevesColor.bgElevated1)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEnabled ? BreevesColor.accentPrimary : BreevesColor.hairlineStandard, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

public struct GhostTextButton: View {
    let title: String
    let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .breevesCaption()
                .fontWeight(.semibold)
                .foregroundStyle(BreevesColor.accentPrimary)
        }
        .buttonStyle(.plain)
    }
}
