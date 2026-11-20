import Foundation

enum CockpitPage: String, CaseIterable, Identifiable, Codable {
    case navigation, track, dashboard
    var id: String { rawValue }
    var title: String {
        switch self {
        case .navigation: return "Navigation"
        case .track: return "Trace GPX"
        case .dashboard: return "Compteurs"
        }
    }
    var symbol: String {
        switch self {
        case .navigation: return "location.north.line"
        case .track: return "point.topleft.down.to.point.bottomright.curvepath"
        case .dashboard: return "speedometer"
        }
    }
    static func saved(_ raw: String) -> Self { Self(rawValue: raw) ?? .navigation }
}

enum CockpitSettings {
    static let phoneKey = "cockpitPhonePage"
    static let tftKey = "cockpitTFTPage"
    static let enabledKey = "independentCockpitEnabled"
    static let phoneAppKeepsTFTKey = "rivet.phoneAppKeepsRivetTFT"
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var tftPage: CockpitPage { .saved(UserDefaults.standard.string(forKey: tftKey) ?? "") }
}
