import Foundation
import SwiftData
import Models

@MainActor
public final class BriefingCache {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public static func dateKey(for date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: date)
    }

    // MARK: - Briefings

    public func upsert(_ briefing: DailyBriefing) throws {
        let key = Self.dateKey(for: briefing.date)
        let payload = try JSONEncoder.briefing.encode(briefing)
        let descriptor = FetchDescriptor<CachedBriefing>(
            predicate: #Predicate { $0.dateKey == key }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.payloadData = payload
            existing.fetchedAt = .now
        } else {
            context.insert(CachedBriefing(dateKey: key, payloadData: payload))
        }
        try context.save()
    }

    public func loadToday() throws -> DailyBriefing? {
        let key = Self.dateKey(for: Date())
        let descriptor = FetchDescriptor<CachedBriefing>(
            predicate: #Predicate { $0.dateKey == key }
        )
        guard let row = try context.fetch(descriptor).first else { return nil }
        return try JSONDecoder.briefing.decode(DailyBriefing.self, from: row.payloadData)
    }

    // MARK: - Read state

    public func markRead(articleId: String, on date: Date = Date()) throws {
        let key = Self.dateKey(for: date)
        let compound = "\(key)#\(articleId)"
        let descriptor = FetchDescriptor<ReadArticle>(
            predicate: #Predicate { $0.compoundKey == compound }
        )
        if try context.fetch(descriptor).first == nil {
            context.insert(ReadArticle(dateKey: key, articleId: articleId))
            try context.save()
        }
    }

    public func readArticleIds(on date: Date = Date()) throws -> Set<String> {
        let key = Self.dateKey(for: date)
        let descriptor = FetchDescriptor<ReadArticle>(
            predicate: #Predicate { $0.dateKey == key }
        )
        return Set(try context.fetch(descriptor).map { $0.articleId })
    }

    // MARK: - Preferences

    public func loadPreferences() throws -> UserPreferences? {
        let descriptor = FetchDescriptor<CachedPreferences>(
            predicate: #Predicate { $0.id == "self" }
        )
        return try context.fetch(descriptor).first?.toPreferences()
    }

    public func savePreferences(_ prefs: UserPreferences) throws {
        let descriptor = FetchDescriptor<CachedPreferences>(
            predicate: #Predicate { $0.id == "self" }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.apply(prefs)
        } else {
            context.insert(CachedPreferences(prefs: prefs))
        }
        try context.save()
    }
}

public enum BreevesSchema {
    public static let allModels: [any PersistentModel.Type] = [
        CachedBriefing.self,
        ReadArticle.self,
        CachedPreferences.self,
    ]
}
