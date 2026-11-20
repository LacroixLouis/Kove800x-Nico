import Foundation

enum RivetLanguage: String, CaseIterable, Identifiable {
    case system, french = "fr", english = "en"
    static let preferenceKey = "rivet.interface.language"
    var id: String { rawValue }
    var name: String {
        switch self {
        case .system: return "Langue de l’iPhone".rivetLocalized
        case .french: return "Français"
        case .english: return "English"
        }
    }
    static func saved(_ value: String) -> Self { Self(rawValue: value) ?? .system }
    var localeIdentifier: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.lowercased().hasPrefix("fr") ? "fr" : "en"
        case .french: return "fr"
        case .english: return "en"
        }
    }
    static var current: Self { saved(UserDefaults.standard.string(forKey: preferenceKey) ?? "system") }
}

extension String {
    /// Runtime labels (weather, model statuses and errors) use the same in-app
    /// choice as SwiftUI, without changing the system language or rebuilding BLE.
    var rivetLocalized: String {
        let language = RivetLanguage.current.localeIdentifier
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return self }
        return bundle.localizedString(forKey: self, value: self, table: "Localizable")
    }
}
