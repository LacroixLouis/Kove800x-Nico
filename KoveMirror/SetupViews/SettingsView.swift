import SwiftUI

struct SettingsView: View {
    @AppStorage("enableFileLogging") private var fileLogging = false
    @AppStorage("enableProximitySensor") private var dimWhenCovered = false
    @AppStorage("enableProximitySecondScreen") private var secondScreen = false
    @AppStorage(LockedNavigationStream.enabledKey) private var lockedNavigation = true
    @AppStorage(TFTConnectionPolicy.automaticKey) private var automaticConnection = true
    @AppStorage(TFTConnectionPolicy.lockedKey) private var keepWhenLocked = true
    @AppStorage(TelemetrySyncManager.weatherEnabledKey) private var weatherEnabled = false
    @State private var preset = KoveScreenPreset.current
    @State private var topPadding = KoveScreenPreset.topPadding
    @State private var bottomPadding = KoveScreenPreset.bottomPadding
    @State private var keepAspect = KoveScreenPreset.keepAspectRatio
    @State private var sharingLog = false
    @State private var missingLog = false
    @State private var choosingLanguage = false
    @State private var choosingCrop = false

    private var logURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KoveMirror.log")
    }

    var body: some View {
        RideSheet("Réglages") {
            RideCard {
                Button { choosingLanguage = true } label: {
                    HStack {
                        Label("Langue", systemImage: "globe")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }.frame(minHeight: 44)
                }.buttonStyle(.plain)
            }
            RideCard {
                Label("Connexion à la Kove", systemImage: "motorcycle.fill").font(.headline)
                Toggle("Se reconnecter au contact", isOn: $automaticConnection)
                Toggle("Maintenir la liaison écran verrouillé", isOn: $keepWhenLocked)
                Toggle("Météo sur le compteur", isOn: $weatherEnabled)
                Text("La météo est facultative. Si tu l’actives, une position arrondie à deux décimales est transmise à Open-Meteo.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
                Text("Le trajet utilise la position pour la vitesse et l’altitude du TFT. Autorise la localisation avant de verrouiller l’iPhone. Le miroir d’une autre app peut s’arrêter au verrouillage.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
            }
            RideCard {
                Label("L’écran du compteur", systemImage: "display").font(.headline)
                Picker("Modèle", selection: $preset) {
                    ForEach(KoveScreenPreset.allCases) { value in Text(value.displayName).tag(value) }
                }
                .pickerStyle(.menu)
                Text("Après un changement de format, reconnecte la vidéo au compteur.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
                Divider()
                Button("Cadrer une fenêtre pour le TFT", systemImage: "crop") { choosingCrop = true }
                    .font(.subheadline.weight(.semibold))
                Toggle("Conserver les proportions", isOn: $keepAspect)
                marginSlider("Marge haute", value: $topPadding, identifier: "screen.topMargin")
                marginSlider("Marge basse", value: $bottomPadding, identifier: "screen.bottomMargin")
                Button("Remettre les marges à zéro", systemImage: "arrow.counterclockwise") {
                    topPadding = 0
                    bottomPadding = 0
                }
                .font(.subheadline)
            }
            RideCard {
                Label("Le téléphone", systemImage: "iphone").font(.headline)
                Toggle("Assombrir quand il est couvert", isOn: $dimWhenCovered)
                Text("La caméra détecte la faible lumière. Cela réduit la luminosité sans verrouiller l’iPhone.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
                Toggle("Carte intégrée quand il est couvert", isOn: $secondScreen)
                    .disabled(!dimWhenCovered)
                Text("Cette option concerne notre carte, pas une autre app de navigation.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
            }
            RideCard {
                Label("Navigation intégrée", systemImage: "location.north.line").font(.headline)
                Toggle("Continuer les consignes en arrière-plan", isOn: $lockedNavigation)
                Text("Mode d’essai pour la navigation intégrée. La continuité réelle sur l’iPhone et le TFT reste à vérifier ; il ne récupère pas l’écran d’OsmAnd ou de Waze.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
            }
            RideCard {
                Label("Pour dépanner", systemImage: "waveform.path.ecg").font(.headline)
                Toggle("Conserver le journal de connexion", isOn: $fileLogging)
                Button("Partager le journal") {
                    if FileManager.default.fileExists(atPath: logURL.path) { sharingLog = true }
                    else { missingLog = true }
                }
                .buttonStyle(RideButtonStyle(primary: false))
                if missingLog {
                    Text("Aucun journal enregistré pour le moment. Active l’option puis refais une connexion.")
                        .font(.caption).foregroundStyle(RideTheme.muted)
                }
            }
        }
        .tint(RivetCockpit.lime)
        .onChange(of: preset) { _, value in KoveScreenPreset.current = value }
        .onChange(of: topPadding) { _, value in KoveScreenPreset.topPadding = value }
        .onChange(of: bottomPadding) { _, value in KoveScreenPreset.bottomPadding = value }
        .onChange(of: keepAspect) { _, value in KoveScreenPreset.keepAspectRatio = value }
        .onChange(of: dimWhenCovered) { _, value in CameraProximityManager.shared.isEnabled = value }
        .onChange(of: weatherEnabled) { _, value in TelemetrySyncManager.shared.setWeatherEnabled(value) }
        .sheet(isPresented: $sharingLog) { ActivityViewController(activityItems: [logURL]) }
        .sheet(isPresented: $choosingLanguage) { AppLanguageView() }
        .sheet(isPresented: $choosingCrop, onDismiss: { keepAspect = KoveScreenPreset.keepAspectRatio }) { ScreenCropView() }
    }

    private func marginSlider(_ title: String, value: Binding<Int>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) px").monospacedDigit().foregroundStyle(RideTheme.muted)
            }
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0.rounded()) }
            ), in: 0...300, step: 1)
            .accessibilityLabel(title)
            .accessibilityValue("\(value.wrappedValue) pixels")
            .accessibilityIdentifier(identifier)
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
