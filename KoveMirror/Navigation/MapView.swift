import SwiftUI
import MapKit
import UniformTypeIdentifiers

struct MapViewContainer: UIViewRepresentable {
    @ObservedObject var navManager: LocationAndNavigationManager
    @Binding var is3DTracking: Bool
    @Binding var cameraDistance: CLLocationDistance
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.showsScale = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.mapType = .standard
        mapView.overrideUserInterfaceStyle = .dark
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update Route Polyline
        uiView.removeOverlays(uiView.overlays)
        if let track = navManager.importedTrack, navManager.isFollowingGPX || navManager.currentRoute == nil {
            uiView.removeAnnotations(uiView.annotations.filter { !($0 is MKUserLocation) })
            for segment in track.segments {
                let coordinates = segment.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                uiView.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count), level: .aboveRoads)
            }
        } else if let route = navManager.currentRoute {
            uiView.addOverlay(route.polyline, level: .aboveRoads)
            
            // Add destination marker annotation
            if let destItem = navManager.destinationItem {
                uiView.removeAnnotations(uiView.annotations.filter { !($0 is MKUserLocation) })
                let anno = MKPointAnnotation()
                anno.coordinate = destItem.location.coordinate
                anno.title = destItem.name
                uiView.addAnnotation(anno)
            }
        } else {
            uiView.removeAnnotations(uiView.annotations.filter { !($0 is MKUserLocation) })
        }
        
        // Update Camera Position & Tracking
        if navManager.isNavigating && is3DTracking, let location = navManager.userLocation {
            let headingDegrees = navManager.userHeading?.trueHeading ?? location.course
            let camera = MKMapCamera(
                lookingAtCenter: location.coordinate,
                fromDistance: cameraDistance,
                pitch: 60, // 3D perspective tilt
                heading: headingDegrees > 0 ? headingDegrees : 0
            )
            uiView.setCamera(camera, animated: true)
        } else if let location = navManager.userLocation, is3DTracking {
            let headingDegrees = navManager.userHeading?.trueHeading ?? location.course
            let camera = MKMapCamera(
                lookingAtCenter: location.coordinate,
                fromDistance: cameraDistance,
                pitch: 45,
                heading: headingDegrees > 0 ? headingDegrees : 0
            )
            uiView.setCamera(camera, animated: true)
        } else if !navManager.isNavigating, let route = navManager.currentRoute, context.coordinator.shouldCenterRoute {
            uiView.setVisibleMapRect(
                route.polyline.boundingMapRect,
                edgePadding: UIEdgeInsets(top: 100, left: 50, bottom: 200, right: 50),
                animated: true
            )
            context.coordinator.shouldCenterRoute = false
        } else if let location = navManager.userLocation, context.coordinator.isInitialCentering {
            let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: cameraDistance, longitudinalMeters: cameraDistance)
            uiView.setRegion(region, animated: true)
            context.coordinator.isInitialCentering = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewContainer
        var isInitialCentering = true
        var shouldCenterRoute = true
        
        init(_ parent: MapViewContainer) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = RivetCockpit.orange.uiColor()
                renderer.lineWidth = 7.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let identifier = "DestinationPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.markerTintColor = .systemOrange
                annotationView?.glyphImage = UIImage(systemName: "flag.fill")
            } else {
                annotationView?.annotation = annotation
            }
            return annotationView
        }
    }
}

struct MapView: View {
    var isOffscreen: Bool = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var navManager = LocationAndNavigationManager.shared
    @ObservedObject private var keyManager = HandlebarKeyManager.shared
    
    @State private var showGPXImporter = false
    @State private var showSearchSheet = false
    @State private var is3DTracking = true
    @State private var cameraDistance: CLLocationDistance = 350.0
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Native Map View Layer
            MapViewContainer(navManager: navManager, is3DTracking: $is3DTracking, cameraDistance: $cameraDistance)
                .ignoresSafeArea()
            
            // UI Overlay Controls
            VStack {
                // Top Header Controls / Navigation Banner
                if navManager.isNavigating, let step = navManager.currentStep {
                    // Turn-by-Turn Motorcycle HUD Banner
                    NavigationTurnBanner(
                        step: step,
                        distanceMeters: navManager.distanceToNextStep
                    )
                } else {
                    // Search Bar & Close Button
                    HStack(spacing: 12) {
                        Button(action: { showSearchSheet = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(RivetCockpit.orange)
                                    .font(.system(size: 16, weight: .bold))
                                
                                Text(navManager.destinationItem?.name ?? "Où veux-tu aller ?")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(RideTheme.ink)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(RivetCockpit.panel.opacity(0.96))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        // Exit Map Button
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(RideTheme.ink)
                                .frame(width: 44, height: 44)
                                .background(RivetCockpit.panel.opacity(0.96))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 50)
                }
                
                // Handlebar Action Toast Notification
                if let toast = keyManager.toastMessage {
                    Text(toast)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(RivetCockpit.lime)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RideTheme.background.opacity(0.9))
                        .cornerRadius(20)
                        .overlay(
                            Capsule()
                                .stroke(RivetCockpit.lime.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 6)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // Floating Side Map Control Buttons (Zoom / Recenter / 3D Mode / Mute)
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        // Zoom In Button (+)
                        Button(action: { zoomIn() }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(RideTheme.ink)
                                .frame(width: 44, height: 44)
                                .background(RivetCockpit.panel.opacity(0.96))
                                .cornerRadius(22)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        
                        // Zoom Out Button (-)
                        Button(action: { zoomOut() }) {
                            Image(systemName: "minus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(RideTheme.ink)
                                .frame(width: 44, height: 44)
                                .background(RivetCockpit.panel.opacity(0.96))
                                .cornerRadius(22)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        
                        // 3D Heading Tracking Toggle / Recenter
                        Button(action: {
                            is3DTracking.toggle()
                            if is3DTracking { cameraDistance = 350.0 }
                        }) {
                            Image(systemName: is3DTracking ? "location.north.line.fill" : "location.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(is3DTracking ? RideTheme.orange : RideTheme.ink)
                                .frame(width: 44, height: 44)
                                .background(RivetCockpit.panel.opacity(0.96))
                                .cornerRadius(22)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                        }
                        
                        // Mute/Unmute Voice Guidance
                        if navManager.isNavigating {
                            Button(action: { navManager.isAudioMuted.toggle() }) {
                                Image(systemName: navManager.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(navManager.isAudioMuted ? .red : .green)
                                    .frame(width: 44, height: 44)
                                    .background(RivetCockpit.panel.opacity(0.96))
                                    .cornerRadius(22)
                                    .shadow(color: .black.opacity(0.3), radius: 4)
                            }
                        }
                    }
                    .padding(.trailing, 16)
                }
                .padding(.bottom, 8)
                
                // GPX following never invents road turns, ETA or remaining distance.
                if navManager.isFollowingGPX {
                    VStack(spacing: 8) {
                        Text(navManager.importedTrack?.name ?? "Trace GPX").font(.headline)
                        Text(navManager.distanceFromGPX.map { String(format: "Écart à la trace : %.0f m (environ)", $0) } ?? "En attente d’une position GPS récente")
                        Text("Suivi de trace · sans recalcul ni instructions de virage").font(.caption)
                        Toggle("TFT indépendant (essai)", isOn: $navManager.independentGPXOutput)
                        Text("Le TFT reçoit le tracé GPX de Double Interface, pas l’image d’OsmAnd ou de Waze.").font(.caption)
                        HStack {
                            Button("Waze sur iPhone") {
                                guard let url = URL(string: "waze://") else { return }
                                UIApplication.shared.open(url, options: [:]) { opened in
                                    if !opened { DispatchQueue.main.async { errorMessage = "Waze n’est pas installé ou ne peut pas être ouvert." } }
                                }
                            }
                            Button("Plans sur iPhone") { MKMapItem.openMaps(with: [], launchOptions: nil) }
                        }
                        Button("Arrêter le suivi") { navManager.stopNavigation() }
                    }
                    .padding().background(RideTheme.background.opacity(0.98)).cornerRadius(16).padding()
                } else if navManager.isNavigating {
                    ActiveNavigationHUD(navManager: navManager)
                } else if let route = navManager.currentRoute, let dest = navManager.destinationItem {
                    RoutePreviewCard(
                        destinationName: dest.name ?? "Destination",
                        route: route,
                        onStart: {
                            navManager.startNavigation(route: route, destination: dest)
                        },
                        onCancel: {
                            navManager.currentRoute = nil
                            navManager.destinationItem = nil
                        }
                    )
                }
                if !navManager.isNavigating {
                    HStack {
                        Button("Importer GPX") { showGPXImporter = true }
                        if navManager.importedTrack != nil {
                            Button("Suivre la trace") { navManager.startFollowingGPX() }
                        }
                    }
                    .buttonStyle(.borderedProminent).tint(RivetCockpit.lime).padding(.bottom, 12)
                    if let track = navManager.importedTrack {
                        Text("GPX : " + track.name).font(.caption).padding(6).background(RideTheme.background.opacity(0.96))
                    }
                }
            }
            
            // Transparent screen overlay & pill status when proximity dimming / offscreen 2nd window mode is active
            if !isOffscreen {
                ProximityTransparentOverlay()
            }
        }
        .preferredColorScheme(.dark)
        .foregroundStyle(RivetCockpit.paper).tint(RivetCockpit.lime)
        .onAppear {
            navManager.restoreGPX()
            navManager.requestLocationPermission()
        }
        .onReceive(keyManager.keySubject) { key in
            handleHandlebarKey(key)
        }
        .sheet(isPresented: $showSearchSheet) {
            DestinationSearchSheet(
                userRegion: navManager.userLocation.map {
                    MKCoordinateRegion(center: $0.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
                },
                onSelectDestination: { item in
                    navManager.calculateRoute(to: item) { result in
                        if case .failure(let err) = result {
                            errorMessage = err.localizedDescription
                        }
                    }
                }
            )
        }
        .fileImporter(isPresented: $showGPXImporter, allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 10_000_000 else { throw GPXError.tooLarge }
                let data = try Data(contentsOf: url)
                try navManager.importGPX(data: data, name: url.deletingPathExtension().lastPathComponent)
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("Navigation", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Le calcul de l’itinéraire a échoué.")
        }
    }
    
    private func zoomIn() {
        cameraDistance = max(100.0, cameraDistance * 0.7)
    }
    
    private func zoomOut() {
        cameraDistance = min(40000.0, cameraDistance * 1.45)
    }
    
    private func handleHandlebarKey(_ key: HandlebarKey) {
        switch key {
        case .up:
            // Handlebar UP (Prev / Key code 2) -> Zoom In
            zoomIn()
        case .down:
            // Handlebar DOWN (Next / Key code 3) -> Zoom Out
            zoomOut()
        case .enter:
            // Handlebar ENTER (status 1 / Play) -> Recenter on rider location
            cameraDistance = 350.0
            is3DTracking = true
        case .esc:
            // Handlebar ESC (status 0 / Pause) -> Stop navigation or exit map
            if navManager.isNavigating {
                navManager.stopNavigation()
            } else if navManager.currentRoute != nil {
                navManager.currentRoute = nil
                navManager.destinationItem = nil
            } else {
                dismiss()
            }
        }
    }
}

// MARK: - Navigation Turn Banner (Motorcycle Cockpit HUD)

struct NavigationTurnBanner: View {
    let step: MKRoute.Step
    let distanceMeters: CLLocationDistance
    
    var formattedDistance: String {
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters)) m"
        } else {
            return String(format: "%.1f km", distanceMeters / 1000.0)
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Maneuver Direction Icon
            Image(systemName: step.maneuverIconName)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 56, height: 56)
                .background(RivetCockpit.orange)
                .cornerRadius(14)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDistance)
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundColor(RivetCockpit.orange)
                
                Text(step.instructions.isEmpty ? "Continue sur l’itinéraire" : step.instructions)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(RideTheme.ink)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
        .background(RideTheme.background.opacity(0.95))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(RivetCockpit.orange.opacity(0.5), lineWidth: 1.5)
        )
        .padding(.horizontal)
        .padding(.top, 50)
        .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Active Navigation HUD Card

struct ActiveNavigationHUD: View {
    @ObservedObject var navManager: LocationAndNavigationManager
    
    var formattedRemainingDistance: String {
        let meters = navManager.distanceRemainingMeters
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            return String(format: "%.1f km", meters / 1000.0)
        }
    }
    
    var formattedETA: String {
        let etaDate = Date().addingTimeInterval(navManager.timeRemainingSeconds)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: etaDate)
    }
    
    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                // Speedometer Gauge
                VStack(spacing: 2) {
                    Text("\(navManager.currentSpeedKmH)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(RideTheme.ink)
                    Text("KM/H")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(RivetCockpit.orange)
                }
                .frame(width: 80)
                
                Divider()
                    .frame(height: 36)
                    .background(Color.white.opacity(0.2))
                
                // Trip Summary (ETA & Distance)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(RivetCockpit.orange)
                        Text("ETA \(formattedETA)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(RideTheme.ink)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundColor(RideTheme.muted)
                        Text(formattedRemainingDistance)
                            .font(.subheadline)
                            .foregroundColor(RideTheme.muted)
                    }
                }
                
                // Telemetry Badges (Altitude & Outdoor Temp)
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(RivetCockpit.lime)
                        Text("\(TelemetrySyncManager.shared.currentAltitudeMeters)m")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(RideTheme.ink)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: TelemetrySyncManager.shared.weatherIconName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(RivetCockpit.orange)
                        Text(TelemetrySyncManager.shared.currentTemperatureCelsius.map { "\($0)°C" } ?? "--°C")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(RideTheme.ink)
                    }
                }
                
                Spacer()
                
                // End Navigation Button
                Button(action: { navManager.stopNavigation() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(RideTheme.background.opacity(0.95))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.bottom, 24)
        .shadow(color: .black.opacity(0.4), radius: 10)
    }
}

// MARK: - Route Preview Card

struct RoutePreviewCard: View {
    let destinationName: String
    let route: MKRoute
    let onStart: () -> Void
    let onCancel: () -> Void
    
    var formattedTime: String {
        let mins = Int(route.expectedTravelTime / 60)
        if mins >= 60 {
            return "\(mins / 60) h \(mins % 60) min"
        }
        return "\(mins) min"
    }
    
    var formattedDistance: String {
        String(format: "%.1f km", route.distance / 1000.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(destinationName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(RideTheme.ink)
                        .lineLimit(1)
                    
                    Text("\(formattedTime) • \(formattedDistance)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(RivetCockpit.orange)
                }
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(RideTheme.muted)
                }
            }
            
            Button(action: onStart) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Démarrer le guidage")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RivetCockpit.orange)
                .cornerRadius(14)
            }
        }
        .padding(16)
        .background(RideTheme.background.opacity(0.95))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(RivetCockpit.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.bottom, 24)
        .shadow(color: .black.opacity(0.4), radius: 10)
    }
}
