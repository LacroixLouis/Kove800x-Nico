import SwiftUI

struct ProjectionDiagnosticCard: View {
    @ObservedObject private var diagnostics = ProjectionDiagnostics.shared
    @State private var reportURL: URL?
    @State private var sharing = false
    @State private var exportError: String?

    var body: some View {
        RideCard {
            Label("Sortie vers le TFT", systemImage: "display").font(.headline)
            Text(diagnostics.mode.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(RideTheme.orange)
            LabeledContent("Bluetooth", value: diagnostics.bluetoothConnected ? "Connecté" : "À reconnecter")
            LabeledContent("Contrôle TFT", value: diagnostics.controlConnected ? "Connecté" : "Déconnecté")
            LabeledContent("Canal vidéo", value: diagnostics.videoConnected ? "Connecté" : "Déconnecté")
            LabeledContent("Position en arrière-plan", value: diagnostics.backgroundLocationEnabled ? "Autorisée" : "Inactive")
            LabeledContent("Images de navigation", value: String(diagnostics.encodedFrames))
            LabeledContent("Vidéo envoyée", value: "\(diagnostics.sentVideoBytes / 1024) Ko")
            if let fix = diagnostics.lastFix {
                LabeledContent("Dernier GPS", value: fix.formatted(date: .omitted, time: .standard))
            }
            if let error = diagnostics.lastError { Text(error).font(.caption).foregroundStyle(RideTheme.orange) }
            Text("Ces observations viennent de l’iPhone. Elles ne confirment pas le décodage de l’image par le compteur.")
                .font(.caption).foregroundStyle(RideTheme.muted)
            Button("Partager le diagnostic", systemImage: "square.and.arrow.up") {
                do {
                    reportURL = try diagnostics.exportReport()
                    exportError = nil
                    sharing = true
                } catch { exportError = error.localizedDescription }
            }
            .buttonStyle(RideButtonStyle())
            if let exportError { Text(exportError).font(.caption).foregroundStyle(RideTheme.orange) }
        }
        .sheet(isPresented: $sharing) {
            if let reportURL { ActivityViewController(activityItems: [reportURL]) }
        }
    }
}
