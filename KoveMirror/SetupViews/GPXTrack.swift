import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

struct GPXPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

/// Keeps segment boundaries: no invented line across recording gaps.
struct GPXTrack: Codable {
    let name: String
    let segments: [[GPXPoint]]
    var pointCount: Int { segments.reduce(0) { $0 + $1.count } }

    static func parse(_ data: Data, fallbackName: String) throws -> GPXTrack {
        guard data.count <= 10_000_000 else { throw GPXError.tooLarge }
        let delegate = GPXReader()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), !delegate.invalid else { throw GPXError.invalid }
        let segments = (delegate.tracks.isEmpty ? delegate.routes : delegate.tracks).filter { $0.count >= 2 }
        guard !segments.isEmpty else { throw GPXError.empty }
        let name = delegate.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return GPXTrack(name: name.isEmpty ? fallbackName : name, segments: segments)
    }

    /// Distance to the closest recorded segment, not a road-routing distance.
    func distanceFromTrace(to point: GPXPoint) -> Double {
        let radians = Double.pi / 180
        let scaleX = 6_371_000 * radians * cos(point.latitude * radians)
        let scaleY = 6_371_000 * radians
        func xy(_ p: GPXPoint) -> (Double, Double) {
            var delta = p.longitude - point.longitude
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            return (delta * scaleX, (p.latitude - point.latitude) * scaleY)
        }
        var best = Double.infinity
        for segment in segments {
            for index in 1..<segment.count {
                let a = xy(segment[index - 1]), b = xy(segment[index])
                let dx = b.0 - a.0, dy = b.1 - a.1
                let lengthSquared = dx * dx + dy * dy
                let fraction = lengthSquared > 0 ? min(1, max(0, -(a.0 * dx + a.1 * dy) / lengthSquared)) : 0
                best = min(best, hypot(a.0 + fraction * dx, a.1 + fraction * dy))
            }
        }
        return best
    }
}

enum GPXError: LocalizedError {
    case tooLarge, invalid, empty
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "GPX trop volumineux (10 Mo ou 30 000 points maximum)."
        case .invalid: return "GPX invalide : vérifier les coordonnées et le format XML (30 000 points maximum)."
        case .empty: return "Aucune trace ou route GPX contenant au moins deux points."
        }
    }
}

private final class GPXReader: NSObject, XMLParserDelegate {
    var tracks: [[GPXPoint]] = []
    var routes: [[GPXPoint]] = []
    var title = ""
    var invalid = false
    private var path: [String] = []
    private var points: [GPXPoint] = []
    private var count = 0
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let tag = elementName.components(separatedBy: ":").last ?? elementName
        path.append(tag)
        text = ""
        if path == ["gpx", "trk", "trkseg"] || path == ["gpx", "rte"] { points = [] }
        guard path == ["gpx", "trk", "trkseg", "trkpt"] || path == ["gpx", "rte", "rtept"] else { return }
        count += 1
        guard count <= 30_000,
              let latitude = Double(attributes["lat"] ?? ""),
              let longitude = Double(attributes["lon"] ?? ""),
              latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            invalid = true
            parser.abortParsing()
            return
        }
        points.append(GPXPoint(latitude: latitude, longitude: longitude))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if title.isEmpty && (path == ["gpx", "trk", "name"] || path == ["gpx", "rte", "name"]) {
            title = String(text.prefix(160))
        }
        if path == ["gpx", "trk", "trkseg"] { tracks.append(points); points = [] }
        if path == ["gpx", "rte"] { routes.append(points); points = [] }
        if !path.isEmpty { path.removeLast() }
        text = ""
    }
}
