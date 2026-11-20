import Foundation
import CoreLocation
import MapKit
import AVFoundation
import Combine
import UIKit

struct NavigationStepInfo: Identifiable {
    let id = UUID()
    let instruction: String
    let distanceMeters: CLLocationDistance
    let iconName: String
}

class LocationAndNavigationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationAndNavigationManager()
    
    private let locationManager = CLLocationManager()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var tftRideActive = false
    private var dashboardWeatherOnlyRequest = false
    private var backgroundActivitySession: CLBackgroundActivitySession?
    private var locationServiceSession: CLServiceSession?
    
    // Location & Heading
    @Published var userLocation: CLLocation?
    @Published var userHeading: CLHeading?
    @Published var currentSpeedKmH: Int = 0
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Route & Navigation State
    @Published var independentGPXOutput = true {
        didSet { NotificationCenter.default.post(name: .nicoNavigationUpdated, object: nil) }
    }
    @Published var importedTrack: GPXTrack?
    @Published private(set) var importedTrackRevision = UUID()
    @Published var isFollowingGPX = false
    @Published var distanceFromGPX: Double?
    @Published var isNavigating: Bool = false

    private var savedGPXURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NicoMirror", isDirectory: true).appendingPathComponent("last-track.gpx")
    }

    func importGPX(data: Data, name: String) throws {
        let track = try GPXTrack.parse(data, fallbackName: name)
        let url = savedGPXURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        // Loading a trace for the other display must not cancel a road route.
        if isFollowingGPX { stopNavigation() }
        if !isNavigating {
            currentRoute = nil
            destinationItem = nil
        }
        importedTrack = track
        importedTrackRevision = UUID()
        distanceFromGPX = nil
        NotificationCenter.default.post(name: .nicoNavigationUpdated, object: nil)
    }

    func restoreGPX() {
        guard importedTrack == nil, let data = try? Data(contentsOf: savedGPXURL) else { return }
        importedTrack = try? GPXTrack.parse(data, fallbackName: "Trace enregistrée")
        importedTrackRevision = UUID()
        NotificationCenter.default.post(name: .nicoNavigationUpdated, object: nil)
    }

    /// Shares the original document: do not lose waypoints or vendor extensions
    /// by re-encoding only the simplified geometry used by our preview.
    func gpxForSharing() throws -> URL {
        guard importedTrack != nil else { throw GPXError.empty }
        let data = try Data(contentsOf: savedGPXURL)
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Double-Interface-GPX-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("Trace-Double-Interface.gpx")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }

    func startFollowingGPX() {
        guard importedTrack != nil else { return }
        if isNavigating { stopNavigation() }
        currentRoute = nil
        destinationItem = nil
        isFollowingGPX = true
        isNavigating = true
        distanceFromGPX = nil
        if let location = userLocation { updateGPX(location) }
        startUpdating()
        NotificationCenter.default.post(name: .nicoNavigationUpdated, object: nil)
    }

    private func updateGPX(_ location: CLLocation) {
        guard ProjectionPolicy.isFresh(timestamp: location.timestamp, accuracy: location.horizontalAccuracy, now: Date()) else {
            distanceFromGPX = nil
            return
        }
        distanceFromGPX = importedTrack?.distanceFromTrace(to: GPXPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
    }
    @Published var destinationItem: MKMapItem?
    @Published var currentRoute: MKRoute?
    @Published var currentStepIndex: Int = 0
    @Published var distanceToNextStep: CLLocationDistance = 0
    @Published var distanceRemainingMeters: CLLocationDistance = 0
    @Published var timeRemainingSeconds: TimeInterval = 0
    @Published var isAudioMuted: Bool = false
    
    // Computed Current Step
    var currentStep: MKRoute.Step? {
        guard let route = currentRoute, currentStepIndex < route.steps.count else { return nil }
        return route.steps[currentStepIndex]
    }
    
    var nextStep: MKRoute.Step? {
        guard let route = currentRoute, (currentStepIndex + 1) < route.steps.count else { return nil }
        return route.steps[currentStepIndex + 1]
    }
    
    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 2.0 // Update every 2 meters
        locationManager.headingFilter = 3.0   // Update every 3 degrees
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.activityType = .automotiveNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
        
        self.authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        dashboardWeatherOnlyRequest = false
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        } else {
            startUpdating()
        }
    }

    /// Embedded web maps only need location while their screen is open.
    func requestWebMapLocation() {
        dashboardWeatherOnlyRequest = false
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdating()
        default:
            break
        }
    }

    /// A foreground one-shot fix for the weather widget, without starting a ride.
    func requestDashboardWeatherLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            dashboardWeatherOnlyRequest = !isNavigating && !tftRideActive
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        default: break
        }
    }
    
    func startUpdating() {
        dashboardWeatherOnlyRequest = false
        updateBackgroundActivity()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    /// The TFT consumes real speed/altitude updates even without an entered destination.
    func setTFTRideActive(_ active: Bool) {
        guard tftRideActive != active else { return }
        tftRideActive = active
        if active {
            requestLocationPermission()
            startUpdating()
        } else {
            updateBackgroundActivity()
            if !isNavigating { stopUpdating() }
        }
    }

    private func updateBackgroundActivity() {
        let needed = isNavigating || tftRideActive
        let authorized = locationManager.authorizationStatus == .authorizedAlways
            || locationManager.authorizationStatus == .authorizedWhenInUse
        locationManager.allowsBackgroundLocationUpdates = needed && authorized
        if needed && authorized {
            // Start the visible ride session before the person locks the phone.
            if backgroundActivitySession == nil && UIApplication.shared.applicationState != .background {
                locationServiceSession = CLServiceSession(authorization: .whenInUse)
                backgroundActivitySession = CLBackgroundActivitySession()
            }
        } else {
            backgroundActivitySession?.invalidate()
            backgroundActivitySession = nil
            locationServiceSession?.invalidate()
            locationServiceSession = nil
        }
        ProjectionDiagnostics.shared.setBackgroundLocation(needed && authorized)
    }
    
    func stopUpdating() {
        guard !isNavigating, !tftRideActive else { return }
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        updateBackgroundActivity()
    }
    
    // MARK: - Route Calculation
    
    func calculateRoute(to destination: MKMapItem, completion: @escaping (Result<MKRoute, Error>) -> Void) {
        guard let originLocation = userLocation else {
            let error = NSError(domain: "LocationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User location unavailable. Make sure location permissions are enabled."])
            completion(.failure(error))
            return
        }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(location: originLocation, address: nil)
        request.destination = destination
        request.transportType = .automobile // Default to road routing suitable for motorcycles
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let route = response?.routes.first else {
                let err = NSError(domain: "LocationManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No route found to destination."])
                completion(.failure(err))
                return
            }
            
            DispatchQueue.main.async {
                self?.destinationItem = destination
                self?.currentRoute = route
            }
            completion(.success(route))
        }
    }
    
    // MARK: - Navigation Control
    
    func startNavigation(route: MKRoute, destination: MKMapItem) {
        self.isFollowingGPX = false
        self.currentRoute = route
        self.destinationItem = destination
        
        // Skip initial departure step if it has empty instructions or 0 distance
        var initialIndex = 0
        if route.steps.count > 1 && (route.steps[0].instructions.isEmpty || route.steps[0].distance == 0) {
            initialIndex = 1
        }
        self.currentStepIndex = initialIndex
        self.isNavigating = true
        self.distanceRemainingMeters = route.distance
        self.timeRemainingSeconds = route.expectedTravelTime
        
        if initialIndex < route.steps.count {
            let step = route.steps[initialIndex]
            if let userLoc = userLocation {
                let endPt = getStepCoordinate(step: step)
                self.distanceToNextStep = userLoc.distance(from: endPt)
            } else {
                self.distanceToNextStep = step.distance
            }
        }
        
        startUpdating()
        
        // Announce navigation start
        let destName = destination.name ?? "destination"
        speakInstruction("Départ vers \(destName). Bonne route.")
        
        // Sync turn-by-turn navigation with Kove TFT Dashboard over BLE
        NavigationSyncManager.shared.startNavigation(route: route, destination: destination)
        
        if let firstStep = currentStep {
            updateStepInfo(step: firstStep)
        }
        NotificationCenter.default.post(name: .nicoNavigationUpdated, object: nil)
    }
    
    func stopNavigation() {
        isNavigating = false
        updateBackgroundActivity()
        isFollowingGPX = false
        distanceFromGPX = nil
        currentRoute = nil
        destinationItem = nil
        currentStepIndex = 0
        speakInstruction("Navigation ended.")
        
        // Notify Kove TFT Dashboard that navigation ended
        NavigationSyncManager.shared.stopNavigation()
        NotificationCenter.default.post(name: .nicoNavigationUpdated, object: nil)
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                if self.dashboardWeatherOnlyRequest && !self.isNavigating && !self.tftRideActive {
                    self.dashboardWeatherOnlyRequest = false
                    manager.requestLocation()
                } else { self.startUpdating() }
            } else {
                self.updateBackgroundActivity()
                if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                    ProjectionDiagnostics.shared.recordError("Localisation désactivée : la continuité du trajet écran verrouillé est indisponible.")
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // One-shot weather fixes can fail indoors. Keep the last real fix and
        // let the widget show its waiting/error state instead of a fake position.
        ProjectionDiagnostics.shared.recordError("Position GPS momentanément indisponible.")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.userLocation = location
            ProjectionDiagnostics.shared.recordFix(location.timestamp)
            
            // Speed in km/h
            let speedMs = max(0, location.speed)
            self.currentSpeedKmH = Int(speedMs * 3.6)
            
            // If navigating, update route progress & step transitions
            if self.isNavigating {
                if self.isFollowingGPX { self.updateGPX(location) }
                else { self.updateNavigationProgress(currentLocation: location) }
            }
            NotificationCenter.default.post(name: .nicoNavigationUpdated, object: nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.userHeading = newHeading
        }
    }
    
    // MARK: - Navigation Step Tracking
    
    private func updateNavigationProgress(currentLocation: CLLocation) {
        guard let route = currentRoute else { return }
        
        // Check distance to destination
        let totalRemaining: CLLocationDistance
        if let destLocation = destinationItem?.location {
            totalRemaining = currentLocation.distance(from: destLocation)
            self.distanceRemainingMeters = totalRemaining
            
            // Proportionally update remaining travel time
            let routeTotalDist = max(1.0, route.distance)
            self.timeRemainingSeconds = max(0, route.expectedTravelTime * (totalRemaining / routeTotalDist))
            
            // Arrival threshold (30 meters)
            if totalRemaining < 30 {
                NavigationSyncManager.shared.triggerArrival()
                speakInstruction("You have arrived at your destination.")
                return
            }
        } else {
            totalRemaining = distanceRemainingMeters
        }
        
        guard currentStepIndex < route.steps.count else { return }
        var step = route.steps[currentStepIndex]
        
        // Calculate distance to end of current step
        var stepEndPoint = getStepCoordinate(step: step)
        var distanceToStepEnd = currentLocation.distance(from: stepEndPoint)
        
        // Advance step if within 25m of maneuver point
        if distanceToStepEnd < 25 && currentStepIndex < (route.steps.count - 1) {
            currentStepIndex += 1
            if let newStep = currentStep {
                step = newStep
                stepEndPoint = getStepCoordinate(step: newStep)
                distanceToStepEnd = currentLocation.distance(from: stepEndPoint)
                updateStepInfo(step: newStep)
            }
        }
        
        self.distanceToNextStep = distanceToStepEnd
        
        // Sync live progress with Kove Dashboard Navigation Manager
        NavigationSyncManager.shared.updateProgress(
            stepIndex: currentStepIndex,
            distanceToStep: distanceToStepEnd,
            totalRemainingDistance: totalRemaining,
            timeRemaining: self.timeRemainingSeconds,
            speedKmH: self.currentSpeedKmH
        )
    }
    
    private func updateStepInfo(step: MKRoute.Step) {
        guard !step.instructions.isEmpty else { return }
        let distanceKm = String(format: "%.1f km", step.distance / 1000.0)
        let distText = step.distance < 1000 ? "\(Int(step.distance)) meters" : distanceKm
        
        speakInstruction("In \(distText), \(step.instructions)")
    }
    
    private func getStepCoordinate(step: MKRoute.Step) -> CLLocation {
        let pointCount = step.polyline.pointCount
        guard pointCount > 0 else { return userLocation ?? CLLocation() }
        let points = step.polyline.points()
        let lastPoint = points[pointCount - 1]
        return CLLocation(latitude: lastPoint.coordinate.latitude, longitude: lastPoint.coordinate.longitude)
    }
    
    private func speakInstruction(_ text: String) {
        guard !isAudioMuted else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        speechSynthesizer.speak(utterance)
    }
}

// Helper extension for maneuver icon mapping
extension MKRoute.Step {
    var maneuverIconName: String {
        let lower = instructions.lowercased()
        if lower.contains("right") {
            return "arrow.turn.up.right"
        } else if lower.contains("left") {
            return "arrow.turn.up.left"
        } else if lower.contains("roundabout") || lower.contains("circle") {
            return "arrow.triangle.turn.clockwise.around.railway"
        } else if lower.contains("u-turn") {
            return "arrow.uturn.backward"
        } else if lower.contains("merge") || lower.contains("keep") {
            return "arrow.triangle.merge"
        } else if lower.contains("arrive") || lower.contains("destination") {
            return "mappin.circle.fill"
        } else {
            return "arrow.up"
        }
    }
}
