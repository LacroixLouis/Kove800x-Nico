import SwiftUI

struct ProjectionPreparationView: View {
    @ObservedObject var bleController: BleController
    @ObservedObject private var wifi = MotorcycleWiFiManager.shared
    @Binding var pairedSSID: String
    @State private var showScanner = false
    @State private var password: String?
    @State private var qrError: String?
    @State private var passwordCopied = false
    private var hasSavedSetup: Bool { bleController.hasSavedMotorcycle || wifi.hasSavedNetwork }

    var body: some View {
        RideSheet("Connexion") {
            Text(bleController.isStreaming ? "Ton compteur est connecté." : "Relier ta Kove.")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            if bleController.hasTFTConnection { connectedCard } else { bluetoothCard }
            if !bleController.isStreaming {
                if hasSavedSetup { DisclosureGroup("Configurer ou changer la connexion") { wifiCard } }
                else { wifiCard }
            }
            RideCard {
                Label(bleController.isPhoneScreenSelected ? "L’écran de l’iPhone sur le TFT" : "La petite fenêtre sur le TFT",
                      systemImage: bleController.isPhoneScreenSelected ? "iphone" : "rectangle.inset.bottomtrailing").font(.headline)
                Text(bleController.isPhoneScreenSelected
                     ? "Dans le choix des applications, démarre la diffusion iOS. Le TFT reçoit alors l’écran complet du téléphone, y compris l’application que tu ouvres."
                     : "Retourne dans Mes deux écrans : le contenu de la miniature est envoyé automatiquement. Tu peux préparer les deux fenêtres avant de connecter la moto.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
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
                Text(bleController.isPhoneScreenSelected
                     ? "L’écran du téléphone sera envoyé quand la diffusion iOS et la liaison vidéo seront prêtes."
                     : "La petite fenêtre sera envoyée quand la liaison vidéo sera prête.")
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

}
