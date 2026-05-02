import Foundation

public enum BriefLength: String, Codable, CaseIterable, Sendable, Identifiable {
    case compact, standard, extended

    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public enum ColorSchemePreference: String, Codable, CaseIterable, Sendable, Identifiable {
    case system, dark, light

    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public struct UserPreferences: Codable, Hashable, Sendable {
    public var notificationEnabled: Bool
    public var notificationHour: Int
    public var notificationMinute: Int
    public var defaultLens: ReadingLens
    public var briefLength: BriefLength
    public var colorScheme: ColorSchemePreference
    public var timezoneIdentifier: String

    public init(
        notificationEnabled: Bool = true,
        notificationHour: Int = 5,
        notificationMinute: Int = 30,
        defaultLens: ReadingLens = .universal,
        briefLength: BriefLength = .standard,
        colorScheme: ColorSchemePreference = .system,
        timezoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.notificationEnabled = notificationEnabled
        self.notificationHour = notificationHour
        self.notificationMinute = notificationMinute
        self.defaultLens = defaultLens
        self.briefLength = briefLength
        self.colorScheme = colorScheme
        self.timezoneIdentifier = timezoneIdentifier
    }
}

public struct UserTopic: Codable, Hashable, Sendable, Identifiable {
    public let name: String
    public let slot: Int
    public let descriptionText: String?

    public var id: String { name }

    public init(name: String, slot: Int, descriptionText: String? = nil) {
        self.name = name
        self.slot = slot
        self.descriptionText = descriptionText
    }
}

/// Result of running a free-typed topic string through the validate_topic
/// Edge Function. `ok=false` carries a user-facing reason; `ok=true`
/// carries the canonical form + a one-line description for the chip UI.
public struct TopicValidation: Codable, Hashable, Sendable {
    public let ok: Bool
    public let canonical: String?
    public let description: String?
    public let reason: String?

    public init(ok: Bool, canonical: String?, description: String?, reason: String?) {
        self.ok = ok
        self.canonical = canonical
        self.description = description
        self.reason = reason
    }
}
