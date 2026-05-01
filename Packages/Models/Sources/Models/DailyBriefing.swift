import Foundation

public struct TopicBriefing: Codable, Hashable, Sendable, Identifiable {
    public let topic: String
    public let articles: [Article]

    public var id: String { topic }

    public init(topic: String, articles: [Article]) {
        self.topic = topic
        self.articles = articles
    }
}

public struct DailyBriefing: Codable, Hashable, Sendable {
    public let date: Date
    public let topics: [TopicBriefing]

    public init(date: Date, topics: [TopicBriefing]) {
        self.date = date
        self.topics = topics
    }

    public var totalArticles: Int {
        topics.reduce(0) { $0 + $1.articles.count }
    }
}

public extension JSONDecoder {
    static var briefing: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

public extension JSONEncoder {
    static var briefing: JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }
}
