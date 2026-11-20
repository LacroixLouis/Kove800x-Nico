import Foundation

enum DashboardWidget: String, Codable, CaseIterable, Identifiable {
    case applications, weather, maintenance, gps, connection, screens, map
    // Decode the old applications widget, but no longer offer its launcher.
    static let allCases: [Self] = [.screens, .weather, .maintenance, .gps, .connection, .map]
    var id: String { rawValue }
    var title: String {
        switch self {
        case .applications: return "Mes applications"
        case .weather: return "Météo de la sortie"
        case .maintenance: return "Entretien de la moto"
        case .gps: return "Mes GPS & mes fichiers"
        case .connection: return "Connexion au compteur"
        case .screens: return "Mes deux écrans"
        case .map: return "Carte & traces GPX"
        }
    }
    var symbol: String {
        switch self {
        case .applications: return "square.grid.2x2.fill"
        case .weather: return "cloud.sun.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .gps: return "point.topleft.down.to.point.bottomright.curvepath"
        case .connection: return "wifi"
        case .screens: return "rectangle.on.rectangle"
        case .map: return "map.fill"
        }
    }
}

struct DashboardLayout: Codable, Equatable {
    static let firstKey = "rivet.cockpit.layout.1"
    static let secondKey = "rivet.cockpit.layout.2"
    var order: [DashboardWidget]
    var hidden: Set<DashboardWidget>

    static func initial(second: Bool = false) -> Self {
        Self(order: second
            ? [.weather, .maintenance, .gps, .connection, .screens, .map]
            : [.screens, .weather, .maintenance, .gps, .connection, .map],
             hidden: second ? [.screens] : [])
    }

    static func load(_ text: String, second: Bool = false) -> Self {
        guard let data = text.data(using: .utf8),
              var value = try? JSONDecoder().decode(Self.self, from: data) else { return initial(second: second) }
        var seen = Set<DashboardWidget>()
        value.order = value.order.map { $0 == .applications ? .screens : $0 }.filter { seen.insert($0).inserted }
        if value.hidden.remove(.applications) != nil { value.hidden.insert(.screens) }
        value.order += DashboardWidget.allCases.filter { !seen.contains($0) }
        return value
    }

    var visible: [DashboardWidget] { order.filter { !hidden.contains($0) } }
    func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self), let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
    mutating func move(_ widget: DashboardWidget, before other: DashboardWidget) {
        guard widget != other, let source = order.firstIndex(of: widget), order.contains(other) else { return }
        order.remove(at: source)
        guard let destination = order.firstIndex(of: other) else { return }
        order.insert(widget, at: destination)
    }
    mutating func move(_ widget: DashboardWidget, over other: DashboardWidget) {
        guard widget != other, let source = order.firstIndex(of: widget),
              let destination = order.firstIndex(of: other) else { return }
        order.remove(at: source)
        order.insert(widget, at: min(destination, order.count))
    }
    mutating func setVisible(_ visible: Bool, widget: DashboardWidget) {
        if visible { hidden.remove(widget) } else { hidden.insert(widget) }
    }
}
