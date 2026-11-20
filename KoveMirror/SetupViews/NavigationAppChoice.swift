import Foundation

/// A saved launcher choice. This does not grant access to another app's windows.
enum NavigationAppChoice: String, CaseIterable, Identifiable, Hashable {
    case osmand, waze, wikiloc, plans, dmdhub

    static let preferenceKey = "preferredProjectionApp"
    static let shortcutsKey = "enabledProjectionApps"
    static let defaultShortcuts = "osmand,waze,wikiloc,plans,dmdhub"
    var id: String { rawValue }

    static func saved(_ value: String) -> Self { Self(rawValue: value) ?? .osmand }

    static func shortcuts(in value: String) -> [Self] {
        let enabled = Set(value.split(separator: ",").map(String.init))
        return allCases.filter { enabled.contains($0.rawValue) }
    }

    static func setting(_ app: Self, enabled: Bool, in value: String) -> String {
        var chosen = Set(shortcuts(in: value))
        if enabled { chosen.insert(app) } else { chosen.remove(app) }
        return allCases.filter { chosen.contains($0) }.map(\.rawValue).joined(separator: ",")
    }

    var title: String {
        switch self {
        case .osmand: return "OsmAnd"
        case .waze: return "Waze"
        case .wikiloc: return "Wikiloc"
        case .plans: return "Plans"
        case .dmdhub: return "DMD HUB"
        }
    }

    var subtitle: String {
        switch self {
        case .osmand: return "Cartes & pistes"
        case .waze: return "Navigation routière"
        case .wikiloc: return "Traces & itinéraires"
        case .plans: return "Plans Apple"
        case .dmdhub: return "À ouvrir sur l’iPhone"
        }
    }

    var symbol: String {
        switch self {
        case .osmand: return "location.north.circle.fill"
        case .waze: return "car.fill"
        case .wikiloc: return "figure.hiking"
        case .plans: return "map.fill"
        case .dmdhub: return "globe.europe.africa.fill"
        }
    }

    /// Bundled original artwork: available offline, without querying installed apps.
    var iconAssetName: String {
        switch self {
        case .osmand: return "AppOsmAnd"
        case .waze: return "AppWaze"
        case .wikiloc: return "AppWikiloc"
        case .plans: return "AppPlans"
        case .dmdhub: return "AppDMDHub"
        }
    }

    var launchURL: URL? {
        switch self {
        case .osmand: return URL(string: "osmandmaps://")!
        case .waze: return URL(string: "waze://")!
        // Wikiloc advertises /openApp in its own apple-app-site-association.
        // universalLinksOnly prevents silently opening Safari instead.
        case .wikiloc: return URL(string: "https://www.wikiloc.com/openApp")!
        case .plans: return URL(string: "maps://")!
        case .dmdhub: return nil
        }
    }

    var universalLinkOnly: Bool { self == .wikiloc }
}

struct UserNavigationShortcut: Codable, Identifiable, Equatable {
    static let preferenceKey = "customProjectionShortcuts"
    let id: UUID
    var title: String
    var shortcutName: String
    var enabled: Bool

    init?(title: String, shortcutName: String = "", id: UUID = UUID(), enabled: Bool = true) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 80, name.count <= 80,
              title.rangeOfCharacter(from: .controlCharacters) == nil,
              name.rangeOfCharacter(from: .controlCharacters) == nil else { return nil }
        self.id = id
        self.title = title
        self.shortcutName = name
        self.enabled = enabled
    }

    static func load(_ text: String) -> [Self] {
        guard let data = text.data(using: .utf8),
              let values = try? JSONDecoder().decode([Self].self, from: data) else { return [] }
        var ids = Set<UUID>()
        return values.prefix(50).compactMap { value in
            guard ids.insert(value.id).inserted else { return nil }
            return Self(title: value.title, shortcutName: value.shortcutName, id: value.id, enabled: value.enabled)
        }
    }

    static func encode(_ values: [Self]) -> String {
        guard let data = try? JSONEncoder().encode(values), let text = String(data: data, encoding: .utf8)
        else { return "[]" }
        return text
    }

    static func url(for name: String, errorCallback: URL? = nil) -> URL {
        var parts = URLComponents()
        parts.scheme = "shortcuts"
        parts.host = "x-callback-url"
        parts.path = "/run-shortcut"
        parts.queryItems = [URLQueryItem(name: "name", value: name)]
        if let errorCallback { parts.queryItems?.append(URLQueryItem(name: "x-error", value: errorCallback.absoluteString)) }
        // No x-success: returning to our app would pull focus away from the
        // navigation application that the user's Open App shortcut just opened.
        return parts.url!
    }
}

enum ProjectionShortcutTarget: Identifiable {
    case builtIn(NavigationAppChoice)
    case custom(UserNavigationShortcut)

    var id: String {
        switch self {
        case .builtIn(let app): return app.rawValue
        case .custom(let shortcut): return "custom:" + shortcut.id.uuidString
        }
    }
    var title: String {
        switch self { case .builtIn(let app): return app.title; case .custom(let item): return item.title }
    }
    var subtitle: String {
        switch self {
        case .builtIn(let app): return app.subtitle
        case .custom: return requiresManualOpen ? "À ouvrir sur l’iPhone" : "Mon application"
        }
    }
    var symbol: String {
        switch self { case .builtIn(let app): return app.symbol; case .custom: return "app.fill" }
    }
    var iconAssetName: String? {
        if case .builtIn(let app) = self { return app.iconAssetName }
        return nil
    }
    var usesAppleMaps: Bool {
        if case .builtIn(.plans) = self { return true }; return false
    }
    var universalLinkOnly: Bool {
        if case .builtIn(let app) = self { return app.universalLinkOnly }; return false
    }
    var iOSShortcutName: String? {
        switch self {
        case .custom(let item) where !item.shortcutName.isEmpty: return item.shortcutName
        default: return nil
        }
    }
    var requiresManualOpen: Bool {
        switch self {
        case .builtIn(let app): return app.launchURL == nil
        case .custom(let item): return item.shortcutName.isEmpty
        }
    }

    func launchURL(errorCallback: URL?) -> URL? {
        if let name = iOSShortcutName { return UserNavigationShortcut.url(for: name, errorCallback: errorCallback) }
        if case .builtIn(let app) = self { return app.launchURL }
        return nil
    }
}

extension Notification.Name {
    static let rivetShortcutFailed = Notification.Name("RivetShortcutFailed")
}

enum ExternalProjectionAvailability: Equatable {
    case waitingForTFT, waitingForBroadcast, openingApp, ready

    static func evaluate(videoConnected: Bool, broadcastConnected: Bool,
                         openingApp: Bool, requiresBroadcast: Bool = true) -> Self {
        guard videoConnected else { return .waitingForTFT }
        guard !requiresBroadcast || broadcastConnected else { return .waitingForBroadcast }
        return openingApp ? .openingApp : .ready
    }

    var canOpenApp: Bool { self == .ready }
}
