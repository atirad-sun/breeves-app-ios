import Foundation
import SwiftData
import Models

@Model
public final class CachedBriefing {
    @Attribute(.unique) public var dateKey: String
    public var payloadData: Data
    public var fetchedAt: Date

    public init(dateKey: String, payloadData: Data, fetchedAt: Date = .now) {
        self.dateKey = dateKey
        self.payloadData = payloadData
        self.fetchedAt = fetchedAt
    }
}

@Model
public final class ReadArticle {
    @Attribute(.unique) public var compoundKey: String
    public var dateKey: String
    public var articleId: String
    public var readAt: Date

    public init(dateKey: String, articleId: String, readAt: Date = .now) {
        self.dateKey = dateKey
        self.articleId = articleId
        self.compoundKey = "\(dateKey)#\(articleId)"
        self.readAt = readAt
    }
}

@Model
public final class CachedPreferences {
    @Attribute(.unique) public var id: String  // always "self"
    public var notificationEnabled: Bool
    public var notificationHour: Int
    public var notificationMinute: Int
    public var defaultLensRaw: String
    public var briefLengthRaw: String
    public var colorSchemeRaw: String

    public init(prefs: UserPreferences) {
        self.id = "self"
        self.notificationEnabled = prefs.notificationEnabled
        self.notificationHour = prefs.notificationHour
        self.notificationMinute = prefs.notificationMinute
        self.defaultLensRaw = prefs.defaultLens.rawValue
        self.briefLengthRaw = prefs.briefLength.rawValue
        self.colorSchemeRaw = prefs.colorScheme.rawValue
    }

    public func apply(_ prefs: UserPreferences) {
        self.notificationEnabled = prefs.notificationEnabled
        self.notificationHour = prefs.notificationHour
        self.notificationMinute = prefs.notificationMinute
        self.defaultLensRaw = prefs.defaultLens.rawValue
        self.briefLengthRaw = prefs.briefLength.rawValue
        self.colorSchemeRaw = prefs.colorScheme.rawValue
    }

    public func toPreferences() -> UserPreferences {
        UserPreferences(
            notificationEnabled: notificationEnabled,
            notificationHour: notificationHour,
            notificationMinute: notificationMinute,
            defaultLens: ReadingLens(rawValue: defaultLensRaw) ?? .universal,
            briefLength: BriefLength(rawValue: briefLengthRaw) ?? .standard,
            colorScheme: ColorSchemePreference(rawValue: colorSchemeRaw) ?? .system
        )
    }
}
