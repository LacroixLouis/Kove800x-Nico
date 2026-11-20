import SwiftUI

struct ProjectionPreparationView: View {
    @ObservedObject var bleController: BleController
    @ObservedObject private var wifi = MotorcycleWiFiManager.shared
    @Binding var pairedSSID: String
    let appTitle: String?
    var requiresBroadcast = true
    @State private var showScanner = false
    @State private var password: String?
    @State private var qrError: String?
    @State private var passwordCopied = false

    private var step: TFTPreparationStep {
        TFTConnectionPolicy.preparationStep(bluetooth: bleController.connectionState == .connected,
            control: bleController.isTFTControlConnected, video: bleController.isStreaming,
            broadcasting: bleController.isBroadcasting, requiresBroadcast: requiresBroadcast)
    }

    private var hasSavedSetup: Bool { bleController.hasSavedMotorcycle || wifi.hasSavedNetwork }

    private var title: String {
        if let appTitle { return "Afficher " + appTitle }
        return bleController.hasTFTConnection ? "Compteur connecté" : "Connexion à la Kove"
    }

    var body: some View {
        RideSheet(title) {
            Text(appTitle.map { $0 + (requiresBroadcast ? " sur ton compteur." : " sur ton iPhone.") }
                ?? (bleController.isStreaming ? "Ton compteur est prêt." : "La liaison reprend automatiquement."))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            if bleController.hasTFTConnection { connectedCard }
            else { bluetoothCard }
            if !bleController.isStreaming {
                if hasSavedSetup {
                    DisclosureGroup("Configurer ou changer la connexion") { wifiCard }
                } else { wifiCard }
            }
            if step == .startBroadcast { broadcastCard }
            else if step == .ready && requiresBroadcast {
                Label("Diffusion active", systemImage: "record.circle.fill")
                    .font(.headline).foregroundStyle(RivetCockpit.lime)
            } else if !requiresBroadcast {
                RideCard {
                    Label("Le TFT garde sa vue Double Interface", systemImage: "display")
                        .font(.headline)
                    Text("Le partage complet de l’écran n’est pas nécessaire pour ce mode.")
                        .foregroundStyle(RideTheme.muted)
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerSheet(showScanner: $showScanner) { code in
                do {
                    let credentials = try MotorcycleWiFiCredentials.parse(code)
                    pairedSSID = credentials.ssid
                    password = credentials.password
                    passwordCopied = false
                    qrError = nil
                    wifi.configure(credentials)
                    bleController.resumeConnection()
                } catch { qrError = error.localizedDescription }
            }
        }
        .onAppear { bleController.resumeConnection() }
        .onDisappear { password = nil }
    }

    private var connectedCard: some View {
        RideCard {
            Label(bleController.isStreaming ? "Compteur connecté" : "Connexion établie · vidéo en attente",
                  systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(RivetCockpit.lime)
            if bleController.isStreaming {
                Text("La liaison existante est conservée quand tu changes d’application.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
            } else {
                ProgressView("Préparation de l’envoi au compteur…")
                Text("L’application choisie s’ouvrira dès que le canal vidéo sera prêt.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
            }
        }
    }

    private var wifiCard: some View {
        RideCard {
            RideSectionTitle(number: "01", title: "Le Wi-Fi de la moto")
            Text("Pour une première association ou un changement de moto, scanne le QR du compteur. Le réseau est ensuite enregistré.")
                .font(.subheadline).foregroundStyle(RideTheme.muted)
            if let password {
                Button(passwordCopied ? "Mot de passe copié" : "Copier le mot de passe") {
                    UIPasteboard.general.setItems([["public.utf8-plain-text": password]],
                        options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
                    passwordCopied = true
                }
                .font(.subheadline.weight(.semibold))
            }
            Button("Scanner le QR du compteur", systemImage: "qrcode.viewfinder") { showScanner = true }
                .buttonStyle(RideButtonStyle(primary: false))
            if wifi.isConnecting { ProgressView("Connexion…") }
            Text(wifi.message).font(.subheadline).foregroundStyle(RideTheme.muted)
            if !pairedSSID.isEmpty {
                Button("Réessayer la connexion Wi-Fi", systemImage: "wifi") {
                    wifi.retrySavedNetwork()
                    bleController.resumeConnection()
                }
                .buttonStyle(RideButtonStyle(primary: false))
                .disabled(wifi.isConnecting)
            }
            Text("Tu peux aussi rejoindre le Wi-Fi du compteur dans les Réglages de l’iPhone. Double Interface détecte ensuite la liaison automatiquement.")
                .font(.caption).foregroundStyle(RideTheme.muted)
            if let qrError { Text(qrError).font(.subheadline).foregroundStyle(RideTheme.orange) }
        }
    }

    private var bluetoothCard: some View {
        RideCard {
            RideSectionTitle(number: "02", title: "Le compteur")
            if bleController.connectionState == .scanning || bleController.connectionState == .connecting {
                ProgressView(hasSavedSetup ? "Reconnexion au compteur…" : "Recherche du compteur…")
                Text("L’envoi reprendra automatiquement dès que le compteur sera disponible.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
            } else {
                Text(hasSavedSetup ? "La moto enregistrée est recherchée automatiquement."
                    : "Affiche le mode navigation sur la Kove pour la première association.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
                Button(hasSavedSetup ? "Relancer la recherche" : "Associer le compteur") {
                    bleController.resumeConnection()
                }
                .buttonStyle(RideButtonStyle(primary: false))
            }
        }
    }

    private var broadcastCard: some View {
        RideCard {
            RideSectionTitle(number: "03", title: "Diffuser l’écran")
            if bleController.isBroadcasting {
                Label("Diffusion connectée", systemImage: "checkmark.circle.fill").font(.headline)
                if appTitle != nil {
                    Text("L’application choisie va s’ouvrir dès que la liaison vidéo est prête.")
                        .font(.subheadline).foregroundStyle(RideTheme.muted)
                }
            } else {
                HStack(spacing: 16) {
                    ScreenBroadcastControl(enabled: bleController.isStreaming).frame(width: 48, height: 48)
                        .disabled(!bleController.isStreaming)
                        .opacity(bleController.isStreaming ? 1 : 0.3)
                    Text("Touche le bouton rond, sélectionne « " + ScreenBroadcastControl.serviceName + " », puis « Démarrer la diffusion » dans la fenêtre iOS.")
                        .font(.subheadline).foregroundStyle(RideTheme.muted)
                }
                if !bleController.isStreaming {
                    Text("Ce bouton devient disponible quand le compteur est relié.")
                        .font(.caption).foregroundStyle(RideTheme.muted)
                }
            }
            Text("La diffusion reste active pour les applications suivantes jusqu’à son arrêt.")
                .font(.caption).foregroundStyle(RideTheme.muted)
            Text("La diffusion suit l’écran visible de l’iPhone. Tu peux sélectionner une zone à agrandir dans Menu → Cadrage du TFT.")
                .font(.caption).foregroundStyle(RideTheme.muted)
        }
    }
}
