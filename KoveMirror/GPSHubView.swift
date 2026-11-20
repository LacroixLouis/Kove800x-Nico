import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

/// Exchanges files and places with existing GPS apps through the iOS share sheet.
struct GPSHubView: View {
    @ObservedObject private var nav = LocationAndNavigationManager.shared
    @State private var importing = false
    @State private var sharing = false
    @State private var items: [Any] = []
    @State private var message: String?

    var body: some View {
        RideSheet("Mes GPS & mes fichiers") {
            Text("Une trace, tes GPS.")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("Rassemble une trace ici, puis ouvre-la dans l’application de ton choix.")
                .foregroundStyle(RideTheme.muted)
            RideCard {
                Label("Ma trace GPX", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.headline)
                Text(nav.importedTrack?.name ?? "Choisis un fichier GPX")
                    .font(.title3.weight(.semibold))
                Button("Choisir une trace", systemImage: "folder") { importing = true }
                    .buttonStyle(RideButtonStyle(primary: false))
                Button("Ouvrir dans mon GPS", systemImage: "square.and.arrow.up") {
                    do {
                        items = [try nav.gpxForSharing()]
                        sharing = true
                    } catch { message = error.localizedDescription }
                }
                .buttonStyle(RideButtonStyle())
                .disabled(nav.importedTrack == nil)
                Text("Choisis ton GPS dans la liste de partage iOS. Le fichier d’origine est transmis, avec ses points et ses informations supplémentaires.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
            }
            RideCard {
                Label("Ma position", systemImage: "location").font(.headline)
                Text("Transmets le même point à une autre appli ou à un compagnon de route.")
                    .foregroundStyle(RideTheme.muted)
                Button("Partager ma position", systemImage: "square.and.arrow.up") { shareLocation() }
                    .buttonStyle(RideButtonStyle(primary: false))
                Text("Une position GPS récente est nécessaire. Les applications proposées dépendent de ce qu’elles acceptent de recevoir.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
            }
        }
        .onAppear { nav.restoreGPX(); nav.requestLocationPermission() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                try nav.importGPX(data: Data(contentsOf: url, options: .mappedIfSafe),
                                  name: url.deletingPathExtension().lastPathComponent)
            } catch { message = error.localizedDescription }
        }
        .sheet(isPresented: $sharing) { ActivityViewController(activityItems: items) }
        .alert("Partage GPS", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private func shareLocation() {
        guard let location = nav.userLocation,
              ProjectionPolicy.isFresh(timestamp: location.timestamp, accuracy: location.horizontalAccuracy, now: Date()) else {
            message = "Attends une position GPS récente, puis réessaie."
            return
        }
        var parts = URLComponents()
        parts.scheme = "https"
        parts.host = "maps.apple.com"
        parts.path = "/"
        parts.queryItems = [
            URLQueryItem(name: "ll", value: "\(location.coordinate.latitude),\(location.coordinate.longitude)"),
            URLQueryItem(name: "q", value: "Position partagée")
        ]
        guard let url = parts.url else { return }
        items = [url]
        sharing = true
    }
}
