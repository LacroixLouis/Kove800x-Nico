import SwiftUI
import ReplayKit
import MapKit

enum NativePhoneApp: String, CaseIterable, Identifiable {
    case waze, wikiloc, osmand, plans
    static let selectionKey = "doubleInterface.selectedPhoneApp"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .waze: return "Waze"
        case .wikiloc: return "Wikiloc"
        case .osmand: return "OsmAnd"
        case .plans: return "Plans"
        }
    }
    var icon: String {
        switch self {
        case .waze: return "AppWaze"
        case .wikiloc: return "AppWikiloc"
        case .osmand: return "AppOsmAnd"
        case .plans: return "AppPlans"
        }
    }

    /// Native launches only. A failed app link never turns into a website.
    @MainActor
    func open(completion: @escaping (Bool) -> Void) {
        switch self {
        case .plans:
            completion(MKMapItem.openMaps(with: [], launchOptions: nil))
        case .wikiloc:
            // An official universal link avoids assuming an undocumented URL
            // scheme. iOS reports failure if its installed app cannot handle it.
            UIApplication.shared.open(URL(string: "https://www.wikiloc.com/openApp")!,
                                      options: [.universalLinksOnly: true], completionHandler: completion)
        case .waze, .osmand:
            let url = URL(string: self == .waze ? "waze://" : "osmandmaps://")!
            guard UIApplication.shared.canOpenURL(url) else { completion(false); return }
            UIApplication.shared.open(url, options: [:], completionHandler: completion)
        }
    }
}

/// Locate the actually embedded extension, including in an already signed
/// project whose bundle identifier differs from the distributed template.
private enum EmbeddedBroadcastExtension {
    static var identifier: String? {
        guard let directory = Bundle.main.builtInPlugInsURL,
              let urls = try? FileManager.default.contentsOfDirectory(at: directory,
                  includingPropertiesForKeys: nil) else { return nil }
        return urls.compactMap { url -> Bundle? in
            guard url.pathExtension == "appex", let bundle = Bundle(url: url),
                  let configuration = bundle.object(forInfoDictionaryKey: "NSExtension") as? [String: Any],
                  configuration["NSExtensionPointIdentifier"] as? String == "com.apple.broadcast-services-upload"
            else { return nil }
            return bundle
        }.first?.bundleIdentifier
    }
}

private struct SystemScreenBroadcastButton: UIViewRepresentable {
    let extensionIdentifier: String
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 52, height: 52))
        picker.preferredExtension = extensionIdentifier
        picker.showsMicrophoneButton = false
        picker.tintColor = UIColor(RivetCockpit.lime)
        picker.accessibilityLabel = "Démarrer ou arrêter la diffusion de l’iPhone"
        return picker
    }
    func updateUIView(_ picker: RPSystemBroadcastPickerView, context: Context) {}
}

struct PhoneProjectionView: View {
    @ObservedObject var bleController: BleController
    @AppStorage(NativePhoneApp.selectionKey) private var selectedAppID = ""
    @AppStorage("pairedMotorcycleSSID") private var pairedSSID = ""
    @Environment(\.dismiss) private var dismiss
    @State private var pendingAutoOpen = false
    @State private var visible = false
    @State private var showConnection = false
    @State private var error: String?
    private var selectedApp: NativePhoneApp? { NativePhoneApp(rawValue: selectedAppID) }

    var body: some View {
        RideSheet("Écran de l’iPhone") {
            if let app = selectedApp {
                HStack(spacing: 14) {
                    Image(app.icon).resizable().scaledToFit().frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.title).font(.title.bold())
                        Text("Application iPhone").foregroundStyle(RivetCockpit.secondary)
                    }
                }
            } else {
                Label("Tout l’écran du téléphone", systemImage: "iphone")
                    .font(.title2.bold())
            }
            Text("Ce mode envoie l’écran complet de l’iPhone au TFT. L’application choisie s’ouvre en plein écran sur le téléphone.")
                .font(.subheadline).foregroundStyle(RivetCockpit.secondary)

            RideCard {
                if let identifier = EmbeddedBroadcastExtension.identifier {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(bleController.isBroadcasting ? "Diffusion iOS démarrée" : "Démarrer la diffusion")
                                .font(.headline)
                            Text("Touche le bouton rond puis confirme dans la fenêtre de l’iPhone. Le même bouton permet d’arrêter.")
                                .font(.caption).foregroundStyle(RivetCockpit.secondary)
                        }
                        Spacer(minLength: 0)
                        SystemScreenBroadcastButton(extensionIdentifier: identifier)
                            .frame(width: 52, height: 52)
                    }
                } else {
                    Label("Le service de diffusion est absent de cette installation.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(RivetCockpit.orange)
                }
                Label(bleController.isStreaming ? "Canal vidéo TFT connecté" : "Compteur en attente de connexion",
                      systemImage: bleController.isStreaming ? "link" : "wifi")
                    .font(.subheadline)
                if !bleController.isStreaming {
                    Button("Connexion au compteur", systemImage: "link") { showConnection = true }
                        .buttonStyle(RideButtonStyle(primary: false))
                }
            }
            if let app = selectedApp {
                Button("Ouvrir " + app.title, systemImage: "arrow.up.forward.app") {
                    pendingAutoOpen = false
                    open(app)
                }
                .buttonStyle(RideButtonStyle())
                Text("Tu peux ouvrir l’app avant de connecter la moto. Pour l’afficher sur le TFT, démarre aussi la diffusion iOS.")
                    .font(.caption).foregroundStyle(RivetCockpit.secondary)
            } else {
                Text("Après le démarrage, tu peux revenir à l’accueil de l’iPhone et ouvrir l’application de ton choix.")
                    .font(.subheadline).foregroundStyle(RivetCockpit.secondary)
            }
            if let error { Text(error).foregroundStyle(RivetCockpit.orange) }
            Button("Reprendre la petite fenêtre sur le TFT", systemImage: "rectangle.inset.bottomtrailing") {
                pendingAutoOpen = false
                bleController.selectMiniature()
                dismiss()
            }
            .buttonStyle(RideButtonStyle(primary: false))
            Text("Tes deux fenêtres et leur contenu restent mémorisés. La petite fenêtre reprend l’envoi quand tu refermes les menus. La diffusion iOS peut être arrêtée avec le bouton rond ci-dessus.")
                .font(.caption).foregroundStyle(RivetCockpit.secondary)
        }
        .onAppear {
            visible = true
            pendingAutoOpen = selectedApp != nil
            bleController.selectPhoneScreen()
            scheduleAutoOpen()
        }
        .onDisappear { visible = false; pendingAutoOpen = false }
        .onChange(of: showConnection) { _, showing in
            if !showing { scheduleAutoOpen() }
        }
        .onChange(of: bleController.isBroadcasting) { _, _ in scheduleAutoOpen() }
        .onChange(of: bleController.isStreaming) { _, _ in scheduleAutoOpen() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            scheduleAutoOpen()
        }
        .sheet(isPresented: $showConnection) {
            ProjectionPreparationView(bleController: bleController, pairedSSID: $pairedSSID)
        }
    }

    private func scheduleAutoOpen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard visible, !showConnection, pendingAutoOpen,
                  bleController.isPhoneScreenSelected, bleController.isBroadcasting,
                  bleController.isStreaming, UIApplication.shared.applicationState == .active,
                  let app = selectedApp else { return }
            pendingAutoOpen = false
            open(app)
        }
    }

    private func open(_ app: NativePhoneApp) {
        error = nil
        app.open { success in
            DispatchQueue.main.async {
                if !success {
                    error = "L’iPhone n’a pas pu ouvrir " + app.title + ". Vérifie que l’application est installée. Tu peux aussi l’ouvrir depuis l’accueil après avoir démarré la diffusion."
                }
            }
        }
    }
}
