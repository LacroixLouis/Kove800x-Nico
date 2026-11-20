import Foundation
import CoreLocation
import MapKit
import CoreGraphics
import CoreText
import CoreVideo
import CoreMedia

extension Notification.Name {
    static let nicoNavigationUpdated = Notification.Name("NicoNavigationUpdated")
}

/// Experimental navigation renderer: no UIWindow, screen capture, GPU or MapKit
/// snapshots. Work is driven by real navigation location callbacks, never by a
/// background timer. Encoding/network availability still needs device testing.
final class LockedNavigationStream: H264EncoderDelegate {
    static let enabledKey = "lockedNavigationEnabled"
    private let server: TcpServerManager
    private let encoder = H264Encoder()
    private let queue = DispatchQueue(label: "com.nicolasrivet.locked-navigation")
    private var observer: NSObjectProtocol?
    // Session state is confined to main. Encoder access is confined to queue.
    private var active = false
    private var lastFrameUptime = -Double.infinity
    private var streamWidth = 600
    private var streamHeight = 1024
    // These three encoder fields are accessed only on queue.
    private var encoderReady = false
    private var encoderAttempts = 0
    private var nextEncoderAttempt = 0.0
    private var routeIdentity: ObjectIdentifier?
    private var routePoints: [CGPoint] = []
    private var cachedGPXRevision: UUID?
    private var gpxSegments: [[CGPoint]] = []

    init(server: TcpServerManager) {
        self.server = server
        encoder.delegate = self
        encoder.onError = { [weak self] status in
            let message = "Navigation verrouillée : erreur encodeur \(status). Déverrouiller l'iPhone."
            ProjectionDiagnostics.shared.recordError(message)
            self?.server.onLog?(message)
            self?.queue.async { [weak self] in
                self?.encoderReady = false
                self?.nextEncoderAttempt = ProcessInfo.processInfo.systemUptime + 5
            }
        }
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        let nav = LocationAndNavigationManager.shared
        let allowed = CockpitSettings.isEnabled || (nav.isFollowingGPX && nav.independentGPXOutput)
            || (UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true)
        guard !active, allowed, nav.isNavigating || CockpitSettings.isEnabled else { return }
        active = true
        lastFrameUptime = -Double.infinity
        let preset = KoveScreenPreset.current
        streamWidth = preset.width
        streamHeight = preset.height
        queue.async { [self] in
            encoderReady = false
            encoderAttempts = 0
            nextEncoderAttempt = 0
        }
        observer = NotificationCenter.default.addObserver(
            forName: .nicoNavigationUpdated, object: nil, queue: .main
        ) { [weak self] _ in self?.sendUpdate() }
        sendUpdate()
    }

    func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard active else { return }
        active = false
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        routeIdentity = nil
        routePoints = []
        cachedGPXRevision = nil
        gpxSegments = []
        // Drain queued frames before another encoder can use the TFT stream.
        queue.sync {
            encoder.stop()
            encoderReady = false
        }
    }

    private func sendUpdate() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard active else { return }
        let nav = LocationAndNavigationManager.shared
        guard nav.isNavigating || CockpitSettings.isEnabled else { stop(); return }
        let now = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        guard uptime - lastFrameUptime >= 1 else { return }
        lastFrameUptime = uptime
        let page = CockpitSettings.isEnabled ? CockpitSettings.tftPage
            : (nav.isFollowingGPX ? CockpitPage.track : CockpitPage.navigation)
        let showTrack = page == .track || (page == .navigation && nav.isFollowingGPX)
        let location = nav.userLocation
        let fresh = location.map {
            ProjectionPolicy.isFresh(timestamp: $0.timestamp, accuracy: $0.horizontalAccuracy, now: now)
        } ?? false
        if let location { ProjectionDiagnostics.shared.recordFix(location.timestamp) }

        if let route = nav.currentRoute {
            if routeIdentity != ObjectIdentifier(route) {
                routeIdentity = ObjectIdentifier(route)
                let points = route.polyline.points()
                let count = route.polyline.pointCount
                let step = max(1, (count + 1999) / 2000)
                routePoints = stride(from: 0, to: count, by: step).map {
                    CGPoint(x: points[$0].x, y: points[$0].y)
                }
                if count > 0 { routePoints.append(CGPoint(x: points[count - 1].x, y: points[count - 1].y)) }
            }
        } else {
            routeIdentity = nil
            routePoints = []
        }
        if showTrack, let track = nav.importedTrack, cachedGPXRevision != nav.importedTrackRevision {
            cachedGPXRevision = nav.importedTrackRevision
            gpxSegments = track.segments.map { segment in
                let step = max(1, (segment.count + 1999) / 2000)
                var points = stride(from: 0, to: segment.count, by: step).map { index -> CGPoint in
                    let p = MKMapPoint(CLLocationCoordinate2D(latitude: segment[index].latitude, longitude: segment[index].longitude))
                    return CGPoint(x: p.x, y: p.y)
                }
                if let last = segment.last {
                    let p = MKMapPoint(CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude))
                    points.append(CGPoint(x: p.x, y: p.y))
                }
                return points
            }
        }
        let trackStart = nav.importedTrack?.segments.first?.first
        let fallback = trackStart.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        } ?? nav.currentRoute?.polyline.coordinate
        let coordinate = location?.coordinate ?? fallback
        let mapCenter = coordinate.map { MKMapPoint($0) }
        let latitude = coordinate?.latitude ?? 0
        let mapUnitsPerMeter = MKMapPointsPerMeterAtLatitude(latitude)
        let distanceFromTrack: String
        if fresh, let location, let track = nav.importedTrack {
            let distance = track.distanceFromTrace(to: GPXPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
            distanceFromTrack = String(format: "Écart trace ≈ %.0f m", distance)
        } else { distanceFromTrack = "Position GPS en attente" }
        let instruction: String
        if !fresh { instruction = location == nil ? "EN ATTENTE DU GPS" : "POSITION GPS PÉRIMÉE" }
        else if showTrack { instruction = nav.importedTrack == nil ? "Importer une trace sur le téléphone" : "Suivre la trace GPX" }
        else { instruction = nav.isNavigating ? (nav.currentStep?.instructions ?? "Suivre l’itinéraire") : "Choisir une destination sur le téléphone" }
        let frame = NavigationFrame(
            width: streamWidth, height: streamHeight,
            top: KoveScreenPreset.topPadding, bottom: KoveScreenPreset.bottomPadding,
            page: page,
            instruction: instruction,
            destination: showTrack ? (nav.importedTrack?.name ?? "Trace GPX")
                : (nav.destinationItem?.name ?? "Navigation intégrée"),
            distance: showTrack ? distanceFromTrack
                : (fresh && nav.isNavigating ? String(format: "%.0f m à vol d’oiseau", max(0, nav.distanceToNextStep)) : "Aucun itinéraire actif"),
            speed: fresh ? "\(nav.currentSpeedKmH) km/h" : "-- km/h",
            altitude: fresh ? location.map { String(format: "%.0f m", $0.altitude) } ?? "-- m" : "-- m",
            odometer: BleController.shared?.odoDistanceKm.map { String(format: "%.0f km", $0.rounded(.down)) } ?? "-- km",
            trip: BleController.shared?.tripDistanceKm.map { String(format: "%.1f km", $0) } ?? "-- km",
            fix: location.map { "GPS " + DateFormatter.localizedString(from: $0.timestamp, dateStyle: .none, timeStyle: .medium) } ?? "GPS en attente",
            center: CGPoint(x: mapCenter?.x ?? 0, y: mapCenter?.y ?? 0),
            span: max(1, mapUnitsPerMeter * 1400),
            segments: showTrack ? gpxSegments : [routePoints],
            fresh: fresh
        )
        queue.async { [self] in
            let time = ProcessInfo.processInfo.systemUptime
            if !encoderReady {
                guard encoderAttempts < 3, time >= nextEncoderAttempt else { return }
                encoderAttempts += 1
                encoderReady = encoder.start(width: Int32(frame.width), height: Int32(frame.height), fps: 1)
                nextEncoderAttempt = time + 5
            }
            guard encoderReady else { return }
            guard let buffer = frame.render() else {
                ProjectionDiagnostics.shared.recordError("Impossible de créer l’image du compteur.")
                return
            }
            if !encoder.encode(pixelBuffer: buffer, pts: CMTime(value: Int64(time * 1000), timescale: 1000)) {
                encoderReady = false
                nextEncoderAttempt = time + 5
            }
        }
    }

    func encoderDidOutputNALUnit(data: Data) {
        ProjectionDiagnostics.shared.recordEncodedFrame()
        server.streamVideoFrame(data: data, source: .navigation)
    }
}

/// CoreGraphics bitmap + CoreText only; deliberately avoids UI rendering in background.
private struct NavigationFrame {
    // CoreGraphics colors remain usable on the render queue without UIKit.
    private static let asphalt = CGColor(red: 16.0 / 255, green: 26.0 / 255, blue: 24.0 / 255, alpha: 1)
    private static let panel = CGColor(red: 27.0 / 255, green: 41.0 / 255, blue: 37.0 / 255, alpha: 1)
    private static let paper = CGColor(red: 243.0 / 255, green: 242.0 / 255, blue: 231.0 / 255, alpha: 1)
    private static let lime = CGColor(red: 210.0 / 255, green: 243.0 / 255, blue: 107.0 / 255, alpha: 1)
    private static let orange = CGColor(red: 1, green: 121.0 / 255, blue: 79.0 / 255, alpha: 1)
    private static let secondary = CGColor(red: 180.0 / 255, green: 195.0 / 255, blue: 183.0 / 255, alpha: 1)
    let width: Int
    let height: Int
    let top: Int
    let bottom: Int
    let page: CockpitPage
    let instruction: String
    let destination: String
    let distance: String
    let speed: String
    let altitude: String
    let odometer: String
    let trip: String
    let fix: String
    let center: CGPoint
    let span: Double
    let segments: [[CGPoint]]
    let fresh: Bool

    func render() -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: true,
                          kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                  kCVPixelFormatType_32BGRA, attributes, &buffer) == kCVReturnSuccess,
              let buffer else { return nil }
        guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        ctx.setFillColor(Self.asphalt)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let usable = max(10, height - top - bottom)
        ctx.translateBy(x: 0, y: CGFloat(height - top))
        ctx.scaleBy(x: CGFloat(width) / 600, y: -CGFloat(usable) / 1024)
        ctx.clip(to: CGRect(x: 0, y: 0, width: 600, height: 1024))
        text("Double Interface · " + page.title.uppercased(), rect: CGRect(x: 24, y: 20, width: 552, height: 42), size: 24, color: Self.lime, context: ctx)
        if page == .dashboard {
            text("VITESSE GPS", rect: CGRect(x: 24, y: 105, width: 552, height: 40), size: 24, context: ctx)
            text(speed, rect: CGRect(x: 24, y: 180, width: 552, height: 145), size: 82, color: fresh ? Self.lime : Self.secondary, context: ctx)
            text(fresh ? "Position actualisée" : instruction, rect: CGRect(x: 24, y: 345, width: 552, height: 75), size: 27, context: ctx)
            text("ALTITUDE", rect: CGRect(x: 24, y: 455, width: 552, height: 38), size: 22, context: ctx)
            text(altitude, rect: CGRect(x: 24, y: 505, width: 552, height: 85), size: 57, context: ctx)
            text("TOTAL MOTO  " + odometer, rect: CGRect(x: 24, y: 665, width: 552, height: 65), size: 33, context: ctx)
            text("TRAJET MOTO  " + trip, rect: CGRect(x: 24, y: 755, width: 552, height: 65), size: 33, context: ctx)
            text(fix, rect: CGRect(x: 24, y: 905, width: 552, height: 42), size: 25, context: ctx)
            text("ESSAI · Vérifier que l’heure GPS évolue", rect: CGRect(x: 24, y: 965, width: 552, height: 42), size: 22, context: ctx)
            return buffer
        }
        text(destination, rect: CGRect(x: 24, y: 75, width: 552, height: 74), size: 30, context: ctx)
        text(instruction.isEmpty ? "Suivre l'itinéraire" : instruction,
             rect: CGRect(x: 24, y: 165, width: 552, height: 145), size: 37, context: ctx)
        text(distance, rect: CGRect(x: 24, y: 325, width: 552, height: 50), size: 29, context: ctx)
        let plot = CGRect(x: 24, y: 400, width: 552, height: 395)
        ctx.saveGState()
        ctx.clip(to: plot)
        ctx.setFillColor(Self.panel)
        ctx.fill(plot)
        ctx.setStrokeColor(Self.lime)
        ctx.setLineWidth(6)
        ctx.setLineJoin(.round)
        ctx.beginPath()
        for points in segments {
            for (i, point) in points.enumerated() {
                let p = CGPoint(x: plot.midX + (point.x - center.x) / span * plot.width,
                                y: plot.midY + (point.y - center.y) / span * plot.width)
                if i == 0 { ctx.move(to: p) } else { ctx.addLine(to: p) }
            }
        }
        ctx.strokePath()
        ctx.setFillColor(fresh ? Self.orange : Self.secondary)
        ctx.fillEllipse(in: CGRect(x: plot.midX - 10, y: plot.midY - 10, width: 20, height: 20))
        ctx.restoreGState()
        text("N ↑ · TRACÉ SIMPLIFIÉ · 1,4 km de large", rect: CGRect(x: 30, y: 748, width: 540, height: 44), size: 19, context: ctx)
        text(speed, rect: CGRect(x: 24, y: 820, width: 552, height: 70), size: 48, context: ctx)
        text(fix, rect: CGRect(x: 24, y: 905, width: 552, height: 42), size: 25, context: ctx)
        text("ESSAI · Si l'heure se fige, déverrouiller", rect: CGRect(x: 24, y: 965, width: 552, height: 42), size: 22, context: ctx)
        return buffer
    }

    private func text(_ value: String, rect: CGRect, size: CGFloat, color: CGColor? = nil, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, size, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color ?? Self.paper
        ]
        let string = NSAttributedString(string: value, attributes: attributes)
        let setter = CTFramesetterCreateWithAttributedString(string)
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.textMatrix = .identity
        let path = CGPath(rect: CGRect(origin: .zero, size: rect.size), transform: nil)
        CTFrameDraw(CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil), context)
        context.restoreGState()
    }
}
