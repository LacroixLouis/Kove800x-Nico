import UIKit
import MapKit
import Combine

/// A real MapKit renderer owned by Double Interface. Its view survives every
/// large/miniature exchange; the TFT snapshots its camera and navigation state.
final class IntegratedNavigationPanel: NSObject, MKMapViewDelegate {
    let view = UIView()
    let map = MKMapView()
    private let hud = IntegratedNavigationHUD()
    private let nav = LocationAndNavigationManager.shared
    private var subscription: AnyCancellable?
    private var routeIdentity: ObjectIdentifier?
    private var trackRevision: UUID?
    private var followingTrack = false
    private var centered = false
    private var snapshotter: MKMapSnapshotter?
    private var snapshotToken = UUID()

    override init() {
        super.init()
        view.backgroundColor = .black
        map.delegate = self
        map.overrideUserInterfaceStyle = .dark
        map.showsUserLocation = true
        map.showsCompass = true
        map.showsScale = true
        map.isPitchEnabled = false
        hud.isUserInteractionEnabled = false
        hud.backgroundColor = .clear
        for child in [map, hud] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
            NSLayoutConstraint.activate([
                child.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                child.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                child.topAnchor.constraint(equalTo: view.topAnchor),
                child.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        subscription = NotificationCenter.default.publisher(for: .nicoNavigationUpdated)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in self?.refresh() }
        refresh()
    }

    func refresh() {
        let routeID = nav.currentRoute.map(ObjectIdentifier.init)
        if routeID != routeIdentity || trackRevision != nav.importedTrackRevision
            || followingTrack != nav.isFollowingGPX {
            routeIdentity = routeID
            trackRevision = nav.importedTrackRevision
            followingTrack = nav.isFollowingGPX
            map.removeOverlays(map.overlays)
            map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
            if let track = nav.importedTrack, nav.isFollowingGPX || nav.currentRoute == nil {
                for segment in track.segments {
                    let coordinates = segment.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    map.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count))
                }
            } else if let route = nav.currentRoute {
                map.addOverlay(route.polyline)
                if let destination = nav.destinationItem {
                    let pin = MKPointAnnotation()
                    pin.coordinate = destination.location.coordinate
                    pin.title = destination.name
                    map.addAnnotation(pin)
                }
            }
        }
        if !centered, let location = nav.userLocation,
           ProjectionPolicy.isFresh(timestamp: location.timestamp, accuracy: location.horizontalAccuracy, now: Date()) {
            centered = true
            recenter()
        }
        hud.state = IntegratedNavigationState(nav: nav)
    }

    func recenter() {
        guard let fix = nav.userLocation,
              ProjectionPolicy.isFresh(timestamp: fix.timestamp, accuracy: fix.horizontalAccuracy, now: Date()) else { return }
        map.setRegion(MKCoordinateRegion(center: fix.coordinate, latitudinalMeters: 1400,
                                        longitudinalMeters: 1400), animated: false)
        map.setUserTrackingMode(nav.isNavigating ? .followWithHeading : .follow, animated: false)
    }

    func showRoute() {
        guard let first = map.overlays.first else { recenter(); return }
        var rect = first.boundingMapRect
        for overlay in map.overlays.dropFirst() { rect = rect.union(overlay.boundingMapRect) }
        map.setUserTrackingMode(.none, animated: false)
        map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 100, left: 24, bottom: 100, right: 24), animated: false)
    }

    func cancelSnapshot() {
        snapshotToken = UUID()
        snapshotter?.cancel()
        snapshotter = nil
    }

    func setHUDTopInset(_ inset: CGFloat) { hud.topInset = inset }

    func snapshot(width: CGFloat, completion: @escaping (UIImage?, Error?) -> Void) {
        refresh()
        guard view.window != nil, view.bounds.width > 0, view.bounds.height > 0 else {
            completion(nil, NSError(domain: "DoubleInterface", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "La carte de navigation n’est pas encore affichée."]))
            return
        }
        cancelSnapshot()
        let token = snapshotToken
        let options = MKMapSnapshotter.Options()
        options.size = view.bounds.size
        options.scale = max(1, width / options.size.width)
        options.camera = map.camera
        options.mapType = map.mapType
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        let segments = map.overlays.compactMap { $0 as? MKPolyline }.map { polyline in
            let step = max(1, (polyline.pointCount + 4095) / 4096)
            var coordinates = stride(from: 0, to: polyline.pointCount, by: step).map { polyline.points()[$0].coordinate }
            if polyline.pointCount > 0 { coordinates.append(polyline.points()[polyline.pointCount - 1].coordinate) }
            return coordinates
        }
        let fix = nav.userLocation
        let state = IntegratedNavigationState(nav: nav)
        let destination = nav.destinationItem?.location.coordinate
        let topInset = hud.topInset
        let task = MKMapSnapshotter(options: options)
        snapshotter = task
        task.start(with: .main) { [weak self] snapshot, error in
            guard let self, self.snapshotToken == token else { return }
            self.snapshotter = nil
            guard let snapshot else { completion(nil, error); return }
            let format = UIGraphicsImageRendererFormat()
            format.scale = options.scale
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: options.size, format: format).image { context in
                snapshot.image.draw(at: .zero)
                let ctx = context.cgContext
                ctx.saveGState()
                ctx.clip(to: CGRect(origin: .zero, size: options.size))
                ctx.setLineWidth(6)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                ctx.setStrokeColor(UIColor.systemOrange.cgColor)
                for coordinates in segments {
                    guard let first = coordinates.first else { continue }
                    ctx.beginPath()
                    ctx.move(to: snapshot.point(for: first))
                    for coordinate in coordinates.dropFirst() { ctx.addLine(to: snapshot.point(for: coordinate)) }
                    ctx.strokePath()
                }
                if let destination {
                    let point = snapshot.point(for: destination)
                    UIColor.systemOrange.setFill()
                    ctx.fillEllipse(in: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14))
                }
                if let fix, ProjectionPolicy.isFresh(timestamp: fix.timestamp,
                                                     accuracy: fix.horizontalAccuracy, now: Date()) {
                    let point = snapshot.point(for: fix.coordinate)
                    UIColor.white.setFill()
                    ctx.fillEllipse(in: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18))
                    UIColor.systemBlue.setFill()
                    ctx.fillEllipse(in: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
                }
                ctx.restoreGState()
                state.draw(in: CGRect(origin: .zero, size: options.size), topInset: topInset)
            }
            completion(image, nil)
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
        let renderer = MKPolylineRenderer(polyline: line)
        renderer.strokeColor = .systemOrange
        renderer.lineWidth = 6
        return renderer
    }
}

private final class IntegratedNavigationHUD: UIView {
    var state = IntegratedNavigationState() { didSet { setNeedsDisplay() } }
    var topInset: CGFloat = 68 { didSet { if topInset != oldValue { setNeedsDisplay() } } }
    override func draw(_ rect: CGRect) { state.draw(in: bounds, topInset: topInset) }
}

private struct IntegratedNavigationState {
    var title = "Navigation Double Interface"
    var detail = "Choisis une destination ou importe une trace GPX."
    var speed = "GPS en attente"

    init() {}
    init(nav: LocationAndNavigationManager) {
        if nav.isFollowingGPX {
            title = nav.importedTrack?.name ?? "Trace GPX"
            detail = nav.distanceFromGPX.map { String(format: "Écart de la trace : %.0f m", $0) } ?? "Position GPS en attente"
        } else if nav.isNavigating {
            title = nav.currentStep?.instructions.isEmpty == false ? nav.currentStep!.instructions : "Suivre l’itinéraire"
            detail = String(format: "Prochaine étape : ≈ %.0f m à vol d’oiseau", max(0, nav.distanceToNextStep))
        }
        if let fix = nav.userLocation,
           ProjectionPolicy.isFresh(timestamp: fix.timestamp, accuracy: fix.horizontalAccuracy, now: Date()) {
            speed = "\(nav.currentSpeedKmH) km/h · GPS ±\(Int(min(1_000_000, max(0, fix.horizontalAccuracy)))) m"
        }
    }

    func draw(in bounds: CGRect, topInset: CGFloat) {
        let top = CGRect(x: 10, y: topInset, width: max(1, bounds.width - 20), height: 90)
        UIColor(red: 16/255, green: 26/255, blue: 24/255, alpha: 0.96).setFill()
        UIBezierPath(roundedRect: top, cornerRadius: 14).fill()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        (title as NSString).draw(in: top.insetBy(dx: 12, dy: 10), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: UIColor.white, .paragraphStyle: paragraph
        ])
        (detail as NSString).draw(in: CGRect(x: top.minX + 12, y: top.minY + 59, width: top.width - 24, height: 25),
            withAttributes: [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.lightGray, .paragraphStyle: paragraph])
        // Leave the bottom corners available for MapKit's legal attribution.
        let bottom = CGRect(x: 10, y: max(top.maxY + 8, bounds.height - 78), width: max(1, bounds.width - 20), height: 42)
        UIColor(red: 16/255, green: 26/255, blue: 24/255, alpha: 0.96).setFill()
        UIBezierPath(roundedRect: bottom, cornerRadius: 12).fill()
        (speed as NSString).draw(in: bottom.insetBy(dx: 12, dy: 11), withAttributes: [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .bold),
            .foregroundColor: UIColor.white, .paragraphStyle: paragraph
        ])
    }
}
