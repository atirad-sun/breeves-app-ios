import SwiftUI

public enum BreevesFont {
    /// New York (Apple's system serif) is exposed via `Font.system(.body, design: .serif)`.
    public static func serif(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// SF Pro is the default. Default design is .default which resolves to SF Pro on iOS.
    public static func sans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    public static func mono(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    public static let displayXL = serif(size: 40, weight: .medium)
    public static let displayL  = serif(size: 32, weight: .medium)
    public static let headlineL = serif(size: 26, weight: .semibold)
    public static let headlineS = serif(size: 20, weight: .semibold)

    public static let bodyL  = sans(size: 17, weight: .regular)
    public static let bodyM  = sans(size: 15, weight: .regular)
    public static let labelM = sans(size: 13, weight: .semibold)
    public static let caption = sans(size: 12, weight: .medium)
    public static let monoS = mono(size: 12, weight: .medium)
}

public extension Text {
    /// Style helpers — each pairs a font with the right tracking + casing where needed.
    func breevesDisplayXL() -> some View {
        self.font(BreevesFont.displayXL).tracking(-0.5)
    }
    func breevesDisplayL() -> some View {
        self.font(BreevesFont.displayL).tracking(-0.4)
    }
    func breevesHeadlineL() -> some View {
        self.font(BreevesFont.headlineL).tracking(-0.3).lineSpacing(2)
    }
    func breevesHeadlineS() -> some View {
        self.font(BreevesFont.headlineS).tracking(-0.2)
    }
    func breevesBodyL() -> some View { self.font(BreevesFont.bodyL).lineSpacing(4) }
    func breevesBodyM() -> some View { self.font(BreevesFont.bodyM).lineSpacing(3) }
    func breevesLabelM() -> some View {
        self.font(BreevesFont.labelM).tracking(0.4).textCase(.uppercase)
    }
    func breevesCaption() -> some View {
        self.font(BreevesFont.caption).tracking(0.2)
    }
    func breevesMonoS() -> some View {
        self.font(BreevesFont.monoS).monospacedDigit()
    }
}
