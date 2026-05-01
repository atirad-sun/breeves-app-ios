import SwiftUI

public enum BreevesColor {
    public static let bgCanvas       = Color("BgCanvas",       bundle: .module)
    public static let bgElevated1    = Color("BgElevated1",    bundle: .module)
    public static let bgElevated2    = Color("BgElevated2",    bundle: .module)
    public static let bgScrim        = Color("BgScrim",        bundle: .module)

    public static let hairlineFaint    = Color("HairlineFaint",    bundle: .module)
    public static let hairlineStandard = Color("HairlineStandard", bundle: .module)
    public static let hairlineStrong   = Color("HairlineStrong",   bundle: .module)

    public static let textPrimary   = Color("TextPrimary",   bundle: .module)
    public static let textSecondary = Color("TextSecondary", bundle: .module)
    public static let textTertiary  = Color("TextTertiary",  bundle: .module)
    public static let textInverse   = Color("TextInverse",   bundle: .module)

    public static let accentPrimary = Color("AccentPrimary", bundle: .module)
    public static let accentMuted   = Color("AccentMuted",   bundle: .module)

    public static let topic1 = Color("Topic1", bundle: .module)
    public static let topic2 = Color("Topic2", bundle: .module)
    public static let topic3 = Color("Topic3", bundle: .module)

    public static let stateRead    = Color("StateRead",    bundle: .module)
    public static let stateSuccess = Color("StateSuccess", bundle: .module)
    public static let stateDanger  = Color("StateDanger",  bundle: .module)

    public static func topic(slot: Int) -> Color {
        switch slot {
        case 0: return topic1
        case 1: return topic2
        default: return topic3
        }
    }
}

public enum BreevesSpace {
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let s5: CGFloat = 24
    public static let s6: CGFloat = 32
    public static let s7: CGFloat = 48
    public static let s8: CGFloat = 64
}

public enum BreevesRadius {
    public static let standard: CGFloat = 12
    public static let card: CGFloat = 16
    public static let pill: CGFloat = 999
}

public enum BreevesMotion {
    public static let lensToggle: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 0.22)
    public static let topicFade: Animation = .easeOut(duration: 0.18)
    public static let progressRing: Animation = .interpolatingSpring(stiffness: 120, damping: 14)
    public static let progressBar: Animation = .easeOut(duration: 0.4)
}
