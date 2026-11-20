import Foundation

/// A panel keeps its identity and web session when its position changes.
enum WebPanelID: Int, CaseIterable, Codable, Identifiable {
    case first, second
    var id: Int { rawValue }
    var other: Self { self == .first ? .second : .first }
}

struct WebPanelLayout: Codable, Equatable {
    private(set) var phone: WebPanelID = .first
    private(set) var miniX: Double = 1
    private(set) var miniY: Double = 1
    var tft: WebPanelID { phone.other }

    mutating func exchange() { phone = phone.other }

    mutating func moveMini(x: Double, y: Double) {
        guard x.isFinite, y.isFinite else { return }
        miniX = min(1, max(0, x))
        miniY = min(1, max(0, y))
    }
}

enum WebMapProvider: String, CaseIterable, Codable, Identifiable {
    case waze, wikiloc
    var id: String { rawValue }
    var title: String { self == .waze ? "Waze" : "Wikiloc" }
}

struct WebPanelPage: Codable, Equatable {
    var provider: WebMapProvider
    var address = ""

    /// Accept a public URL or the src from the provider's official embed code.
    /// Never execute pasted HTML or open a native-app URL.
    func resolvedURL(latitude: Double? = nil, longitude: Double? = nil) -> URL? {
        let input = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !input.isEmpty {
            let candidate: String
            if input.lowercased().contains("<iframe") {
                guard let expression = try? NSRegularExpression(pattern: #"\bsrc\s*=\s*["']([^"']+)["']"#, options: [.caseInsensitive]),
                      let match = expression.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
                      let range = Range(match.range(at: 1), in: input) else { return nil }
                candidate = String(input[range]).replacingOccurrences(of: "&amp;", with: "&")
            } else { candidate = input }
            guard let url = URL(string: candidate), Self.allows(url, provider: provider) else { return nil }
            return url
        }
        let validFix = latitude.map { $0.isFinite && (-90...90).contains($0) } == true
            && longitude.map { $0.isFinite && (-180...180).contains($0) } == true
        if provider == .wikiloc {
            guard validFix else { return URL(string: "https://fr.wikiloc.com/") }
            var parts = URLComponents(string: "https://fr.wikiloc.com/wikiloc/map.do")!
            parts.queryItems = [
                URLQueryItem(name: "lt", value: String(latitude!)),
                URLQueryItem(name: "ln", value: String(longitude!)),
                URLQueryItem(name: "z", value: "13")
            ]
            return parts.url
        }
        var parts = URLComponents(string: "https://embed.waze.com/fr/iframe")!
        parts.queryItems = [
            URLQueryItem(name: "lat", value: String(validFix ? latitude! : 46.6)),
            URLQueryItem(name: "lon", value: String(validFix ? longitude! : 2.5)),
            URLQueryItem(name: "zoom", value: validFix ? "12" : "5")
        ]
        return parts.url
    }

    static func allows(_ url: URL, provider: WebMapProvider) -> Bool {
        guard url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443, let host = url.host?.lowercased() else { return false }
        let domain = provider == .waze ? "waze.com" : "wikiloc.com"
        return host == domain || host.hasSuffix("." + domain)
    }
}
