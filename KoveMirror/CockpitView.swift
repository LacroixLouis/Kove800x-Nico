import SwiftUI
import MapKit
import UniformTypeIdentifiers

/// The two selectors control our own renderers, never other installed apps.
struct CockpitView: View {
    @ObservedObject var bleController: BleController
    let onChooseApplication: () -> Void
    var phoneDisplayOnly = false
    @ObservedObject private var nav = LocationAndNavigationManager.shared
    @ObservedObject private var telemetry = TelemetrySyncManager.shared
    @AppStorage(CockpitSettings.phoneKey) private var phoneValue = CockpitPage.navigation.rawValue
    @AppStorage(CockpitSettings.tftKey) private var tftValue = CockpitPage.navigation.rawValue
    @AppStorage(CockpitSettings.enabledKey) private var independentOutput = false
    @AppStorage(CockpitSettings.phoneAppKeepsTFTKey) private var phoneAppKeepsTFT = false
    @State private var showMap = false
    @State private var importingTrack = false
    @State private var importError: String?

    private var phonePage: CockpitPage { .saved(phoneValue) }
    private var showingIndependentTFT: Bool { independentOutput && !bleController.externalAppMirroringRequested }

    var body: some View {
        RideSheet(phoneDisplayOnly ? "Mon écran iPhone" : "Mes deux écrans") {
            if !phoneDisplayOnly {
                RideCard {
                    Label("Une application sur le TFT", systemImage: "app.connected.to.app.below.fill")
                        .font(.headline)
                    Text("Choisis ton application depuis l’accueil. Le TFT peut la recopier ou garder sa vue Double Interface.")
                        .foregroundStyle(RideTheme.muted)
                    Button("Choisir une application", systemImage: "square.grid.2x2.fill", action: onChooseApplication)
                        .buttonStyle(RideButtonStyle())
                        .accessibilityIdentifier("cockpit.chooseApplication")
            }
            Text("Les vues de Double Interface.")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("Choisis séparément la vue du téléphone et celle du compteur parmi nos trois outils intégrés.")
                .foregroundStyle(RideTheme.muted)
            RideCard {
                HStack {
                    Label("Téléphone", systemImage: "iphone")
                    Spacer()
                    Label("Compteur", systemImage: "display")
                }
                .font(.caption.weight(.bold)).foregroundStyle(RideTheme.muted)
                ForEach(CockpitPage.allCases) { page in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(page.title, systemImage: page.symbol).font(.headline)
                        HStack(spacing: 12) {
                            selectionButton("Téléphone", selected: phonePage == page, symbol: "iphone") {
                                phoneAppKeepsTFT = false
                                phoneValue = page.rawValue
                            }
                            selectionButton("TFT", selected: showingIndependentTFT && tftValue == page.rawValue, symbol: "display") {
                                bleController.sendCockpitPage(page)
                            }
                        }
                    }
                    if page != CockpitPage.allCases.last { Divider() }
                }
            }
            }
            TimelineView(.periodic(from: .now, by: 1)) { _ in phonePreview }
            if !phoneDisplayOnly {
                RideCard {
                    Label(showingIndependentTFT ? "TFT : " + CockpitPage.saved(tftValue).title : "TFT : miroir du téléphone",
                          systemImage: "display").font(.headline)
                    Text(bleController.isStreaming ? "Le canal vidéo est connecté. Vérifie l’image et l’heure GPS sur le TFT."
                         : "Le choix est enregistré. Il sera appliqué à la prochaine connexion vidéo.")
                        .font(.subheadline).foregroundStyle(RideTheme.muted)
                    Button("Revenir au miroir du téléphone", systemImage: "rectangle.on.rectangle") {
                        bleController.returnToPhoneMirror()
                    }
                    .buttonStyle(RideButtonStyle(primary: false))
            }
            Text("Les vues Double Interface peuvent être différentes sur les deux écrans. Pour une autre application, utilise le bouton « Choisir une application » en haut de cette page.")
                .font(.caption).foregroundStyle(RideTheme.muted)
            }
        }
        .onAppear { nav.restoreGPX(); nav.requestLocationPermission() }
        .fullScreenCover(isPresented: $showMap) { MapView() }
        .onChange(of: showMap) { _, visible in bleController.isMapViewVisible = visible }
        .fileImporter(isPresented: $importingTrack, allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                try nav.importGPX(data: data, name: url.deletingPathExtension().lastPathComponent)
                phoneAppKeepsTFT = false
                phoneValue = CockpitPage.track.rawValue
            } catch { importError = error.localizedDescription }
        }
        .alert("Trace GPX", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "") }
    }

    private func selectionButton(_ title: String, selected: Bool, symbol: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(selected ? title + " ✓" : title, systemImage: symbol)
        }
        .buttonStyle(RideButtonStyle(primary: selected))
    }

    @ViewBuilder private var phonePreview: some View {
        RideCard {
            Label("Sur le téléphone : " + phonePage.title, systemImage: "iphone").font(.headline)
            if phonePage == .dashboard {
                let fresh = nav.userLocation.map {
                    ProjectionPolicy.isFresh(timestamp: $0.timestamp, accuracy: $0.horizontalAccuracy, now: Date())
                } ?? false
                Text(fresh ? String(nav.currentSpeedKmH) : "—")
                    .font(.system(size: 76, weight: .black, design: .rounded)).monospacedDigit()
                Text("km/h").font(.title3).foregroundStyle(RideTheme.muted)
                HStack {
                    metric("Altitude", value: fresh ? "\(telemetry.currentAltitudeMeters) m" : "—")
                    metric("Température", value: telemetry.currentTemperatureCelsius.map { "\($0) °C" } ?? "—")
                }
                HStack {
                    metric("Total moto", value: bleController.odoDistanceKm.map { String(format: "%.0f km", $0.rounded(.down)) } ?? "—")
                    metric("Trajet moto", value: bleController.tripDistanceKm.map { String(format: "%.1f km", $0) } ?? "—")
                }
                if let fix = nav.userLocation?.timestamp {
                    Text("GPS " + fix.formatted(date: .omitted, time: .standard))
                        .font(.caption).foregroundStyle(RideTheme.muted)
                }
            } else {
                CockpitMap(nav: nav, page: phonePage)
                    .frame(height: phoneDisplayOnly ? 420 : 310).clipShape(RoundedRectangle(cornerRadius: 18))
                if phonePage == .navigation {
                    Text(nav.currentStep?.instructions ?? "Prépare un itinéraire dans la carte.")
                        .font(.headline)
                    Button("Ouvrir la carte et choisir une destination", systemImage: "map") { showMap = true }
                        .buttonStyle(RideButtonStyle())
                } else {
                    Text(nav.importedTrack?.name ?? "Aucune trace chargée").font(.headline)
                    if let track = nav.importedTrack {
                        Text("\(track.pointCount) points · \(track.segments.count) segments")
                            .font(.caption).foregroundStyle(RideTheme.muted)
                    }
                    Button("Importer un GPX", systemImage: "square.and.arrow.down") { importingTrack = true }
                        .buttonStyle(RideButtonStyle())
                    if nav.importedTrack != nil {
                        Button(nav.isFollowingGPX ? "Arrêter le suivi" : "Suivre cette trace", systemImage: "location.north") {
                            if nav.isFollowingGPX { nav.stopNavigation() }
                            else { nav.startFollowingGPX() }
                        }
                        .buttonStyle(RideButtonStyle(primary: false))
                    }
                }
            }
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(RideTheme.muted)
            Text(value).font(.title3.bold()).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CockpitMap: UIViewRepresentable {
    @ObservedObject var nav: LocationAndNavigationManager
    let page: CockpitPage

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsScale = true
        map.overrideUserInterfaceStyle = .dark
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let identity: String
        if page == .track {
            identity = "track:" + nav.importedTrackRevision.uuidString
        } else {
            identity = nav.currentRoute.map { String(describing: ObjectIdentifier($0)) } ?? "no-route"
        }
        if context.coordinator.identity != identity {
            context.coordinator.identity = identity
            map.removeOverlays(map.overlays)
            if page == .track, let track = nav.importedTrack {
                for segment in track.segments {
                    let points = segment.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    map.addOverlay(MKPolyline(coordinates: points, count: points.count))
                }
            } else if let route = nav.currentRoute { map.addOverlay(route.polyline) }
            if let first = map.overlays.first {
                var rect = first.boundingMapRect
                for overlay in map.overlays.dropFirst() { rect = rect.union(overlay.boundingMapRect) }
                map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 25, left: 25, bottom: 25, right: 25), animated: false)
            }
        }
        if map.overlays.isEmpty, let location = nav.userLocation, !context.coordinator.centeredOnLocation {
            context.coordinator.centeredOnLocation = true
            map.setRegion(MKCoordinateRegion(center: location.coordinate,
                latitudinalMeters: 1500, longitudinalMeters: 1500), animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject, MKMapViewDelegate {
        var identity: String?
        var centeredOnLocation = false
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: line)
            renderer.strokeColor = RideTheme.orange.uiColor()
            renderer.lineWidth = 5
            return renderer
        }
    }
}
