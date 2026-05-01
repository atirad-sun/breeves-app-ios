import Foundation

public enum ReadingLens: String, Codable, CaseIterable, Sendable, Identifiable {
    case universal
    case topicSpecific = "topic_specific"
    case executive

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .universal: return "Universal"
        case .topicSpecific: return "Deep Dive"
        case .executive: return "Action"
        }
    }

    public var shortDescription: String {
        switch self {
        case .universal: return "Four angles: Gist, Ripple Effect, Personal Impact, Key Metric."
        case .topicSpecific: return "Three topic-specific headers that shift by subject matter."
        case .executive: return "Four executive frames: Intel, Flagged, Questions, Decision."
        }
    }
}
