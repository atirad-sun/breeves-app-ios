import Foundation

public struct UniversalMode: Codable, Hashable, Sendable {
    public let gist: String
    public let rippleEffect: String
    public let personalImpact: String
    public let keyMetric: String

    public init(gist: String, rippleEffect: String, personalImpact: String, keyMetric: String) {
        self.gist = gist
        self.rippleEffect = rippleEffect
        self.personalImpact = personalImpact
        self.keyMetric = keyMetric
    }

    public var orderedBullets: [String] {
        [gist, rippleEffect, personalImpact, keyMetric]
    }
}

public struct TopicSpecificMode: Codable, Hashable, Sendable {
    public let bullet1Header: String
    public let bullet1Text: String
    public let bullet2Header: String
    public let bullet2Text: String
    public let bullet3Header: String
    public let bullet3Text: String

    public init(
        bullet1Header: String, bullet1Text: String,
        bullet2Header: String, bullet2Text: String,
        bullet3Header: String, bullet3Text: String
    ) {
        self.bullet1Header = bullet1Header
        self.bullet1Text = bullet1Text
        self.bullet2Header = bullet2Header
        self.bullet2Text = bullet2Text
        self.bullet3Header = bullet3Header
        self.bullet3Text = bullet3Text
    }

    public var orderedBullets: [(header: String, text: String)] {
        [
            (bullet1Header, bullet1Text),
            (bullet2Header, bullet2Text),
            (bullet3Header, bullet3Text),
        ]
    }
}

public struct ExecutiveMode: Codable, Hashable, Sendable {
    public let theIntel: String
    public let whyFlagged: String
    public let openQuestions: String
    public let decisionAction: String

    public init(theIntel: String, whyFlagged: String, openQuestions: String, decisionAction: String) {
        self.theIntel = theIntel
        self.whyFlagged = whyFlagged
        self.openQuestions = openQuestions
        self.decisionAction = decisionAction
    }

    public var orderedBullets: [(header: String, text: String)] {
        [
            ("THE INTEL", theIntel),
            ("WHY FLAGGED", whyFlagged),
            ("OPEN QUESTIONS", openQuestions),
            ("DECISION / ACTION", decisionAction),
        ]
    }
}

public struct Article: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let headline: String
    public let estimatedReadTimeMinutes: Int
    public let source: String?
    public let universalMode: UniversalMode
    public let topicSpecificMode: TopicSpecificMode
    public let executiveMode: ExecutiveMode

    public init(
        id: String,
        headline: String,
        estimatedReadTimeMinutes: Int,
        source: String? = nil,
        universalMode: UniversalMode,
        topicSpecificMode: TopicSpecificMode,
        executiveMode: ExecutiveMode
    ) {
        self.id = id
        self.headline = headline
        self.estimatedReadTimeMinutes = estimatedReadTimeMinutes
        self.source = source
        self.universalMode = universalMode
        self.topicSpecificMode = topicSpecificMode
        self.executiveMode = executiveMode
    }
}
