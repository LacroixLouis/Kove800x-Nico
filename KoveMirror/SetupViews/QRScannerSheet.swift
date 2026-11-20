import SwiftUI

struct QRScannerSheet: View {
    @Binding var showScanner: Bool
    var onScanSuccess: (String) -> Void
    @State private var scanError: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Le QR de ta Kove.")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("Cadre le QR de connexion Wi-Fi affiché sur le compteur.")
                    .foregroundStyle(RideTheme.muted)
                if let scanError {
                    RideCard {
                        Label("Accès à la caméra", systemImage: "camera.fill").font(.headline)
                        Text(scanError).font(.subheadline)
                        Button("Fermer") { showScanner = false }.buttonStyle(RideButtonStyle())
                    }
                } else {
                    QRCodeScannerView(onScan: { code in
                        onScanSuccess(code)
                        showScanner = false
                    }, onFailure: { scanError = $0 })
                    .frame(height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(RideTheme.orange, lineWidth: 4))
                    Label("Connexion Wi-Fi, pas téléchargement de THINKERRIDE", systemImage: "wifi")
                        .font(.caption.weight(.semibold)).foregroundStyle(RideTheme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(24).background(RideTheme.background).foregroundStyle(RideTheme.ink)
            .toolbarBackground(RivetCockpit.asphalt, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("Scanner le compteur").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showScanner = false }
                }
            }
        }
        .tint(RivetCockpit.lime).preferredColorScheme(.dark)
    }
}
