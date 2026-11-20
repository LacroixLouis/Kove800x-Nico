import SwiftUI

private enum RideHomeSheet: String, Identifiable {
    case connection, settings, help, about, diagnostics, logs, gpsHub
    case maintenance, customize, language, tools
    var id: String { rawValue }
}

struct ConnectionStatusView: View {
    @StateObject var bleController: BleController
    @StateObject private var session = WebCockpitSession.shared
    @AppStorage("pairedMotorcycleSSID") private var pairedSSID = ""
    @AppStorage(DashboardLayout.firstKey) private var firstLayout = ""
    @AppStorage(DashboardLayout.secondKey) private var secondLayout = ""
    @AppStorage("rivet.activeCockpit") private var activeCockpit = 1
    @AppStorage(MotorcycleMaintenance.preferenceKey) private var maintenanceValue = ""
    @State private var sheet: RideHomeSheet?
    @State private var sheetAfterDismiss: RideHomeSheet?
    @State private var editingWidgets = false
    @State private var draggingWidget: DashboardWidget?

    init(bleController: BleController? = nil, currentWifiSSID: String? = nil) {
        _bleController = StateObject(wrappedValue: bleController ?? BleController())
        _ = currentWifiSSID
    }

    private var garage: MotorcycleMaintenance { .load(maintenanceValue) }
    private var layout: DashboardLayout {
        DashboardLayout.load(activeCockpit == 2 ? secondLayout : firstLayout, second: activeCockpit == 2)
    }
    private var layoutBinding: Binding<DashboardLayout> {
        Binding(get: { layout }, set: {
            if activeCockpit == 2 { secondLayout = $0.encoded() } else { firstLayout = $0.encoded() }
        })
    }

    var body: some View {
        WebCockpitView(bleController: bleController) {
            sheet = .tools
        }
        .preferredColorScheme(.dark).tint(RivetCockpit.lime)
        .sheet(item: $sheet, onDismiss: {
            if let next = sheetAfterDismiss { sheetAfterDismiss = nil; sheet = next }
        }) { item in
            switch item {
            case .connection: ProjectionPreparationView(bleController: bleController, pairedSSID: $pairedSSID)
            case .settings: SettingsView()
            case .language: AppLanguageView()
            case .help: HelpView()
            case .about: AboutView()
            case .gpsHub: GPSHubView()
            case .maintenance: MaintenanceView(bleController: bleController)
            case .tools: toolsSheet
            case .customize: DashboardCustomizationView(layout: layoutBinding, cockpitNumber: activeCockpit)
            case .diagnostics:
                RideSheet("Diagnostic du compteur") {
                    ProjectionDiagnosticCard()
                    Button("Journal de connexion") { presentAfterDismissing(.logs) }
                        .buttonStyle(RideButtonStyle(primary: false))
                }
            case .logs: EventLogView(bleController: bleController)
            }
        }
        .onChange(of: activeCockpit) { _, _ in editingWidgets = false; draggingWidget = nil }
        .onAppear {
            if maintenanceValue.isEmpty { maintenanceValue = (try? MotorcycleMaintenance().encoded()) ?? "" }
            if activeCockpit != 1 && activeCockpit != 2 { activeCockpit = 1 }
        }
    }

    private func openScreens() {
        sheetAfterDismiss = nil
        sheet = nil
    }

    private func presentAfterDismissing(_ next: RideHomeSheet) {
        if sheet == nil { sheet = next } else { sheetAfterDismiss = next; sheet = nil }
    }

    private func openNavigation() {
        let navigationID = WebPanelID.allCases.first { session.contents.content($0) == .navigation }
        if let navigationID {
            if navigationID != session.layout.phone { session.exchange() }
        } else {
            if session.contents.content(session.layout.phone) == .website { session.exchange() }
            _ = session.setContent(.navigation, for: session.layout.phone)
        }
        openScreens()
    }

    @ViewBuilder private func widgetContent(_ widget: DashboardWidget) -> some View {
        switch widget {
        case .applications, .screens:
            actionCard(title: "Mes deux écrans", subtitle: "Navigation intégrée et site web.",
                       symbol: "rectangle.on.rectangle", accent: RivetCockpit.lime, action: openScreens)
        case .weather: CockpitWeatherWidget()
        case .maintenance: maintenanceWidget
        case .gps: gpsWidget
        case .connection: connectionCard
        case .map:
            actionCard(title: "Carte et traces GPX", subtitle: "Ouvrir la navigation intégrée.",
                       symbol: "map", accent: RivetCockpit.orange, action: openNavigation)
        }
    }
    private var cockpitSelector: some View {
        HStack(spacing: 6) {
            ForEach(1...2, id: \.self) { number in
                Button { activeCockpit = number } label: {
                    Text("Cockpit \(number)").font(.system(.subheadline, design: .rounded).weight(.bold))
                        .padding(.horizontal, 15).frame(minHeight: 44)
                        .foregroundStyle(activeCockpit == number ? RivetCockpit.asphalt : RivetCockpit.secondary)
                        .background(activeCockpit == number ? RivetCockpit.lime : RivetCockpit.panel)
                        .clipShape(Capsule())
                }.buttonStyle(RivetPressStyle()).accessibilityAddTraits(activeCockpit == number ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
            Button { editingWidgets.toggle() } label: {
                Image(systemName: editingWidgets ? "checkmark" : "slider.horizontal.3")
                    .font(.headline).frame(width: 44, height: 44)
                    .background(RivetCockpit.panel).clipShape(Circle())
            }
            .buttonStyle(RivetPressStyle())
            .accessibilityLabel(editingWidgets ? "Terminer les déplacements" : "Déplacer les widgets")
        }
    }

    private var toolsSheet: some View {
        RideSheet("Mes outils") {
            Text("Pour préparer la route.")
                .font(.system(.title, design: .rounded).weight(.bold))
            cockpitSelector
            if editingWidgets {
                Text("Maintiens une poignée pour déplacer un widget. Le bouton − le masque.")
                    .font(.caption).foregroundStyle(RivetCockpit.secondary)
            }
            ForEach(layout.visible) { widget in
                DashboardWidgetContainer(widget: widget, editing: editingWidgets,
                    layout: layoutBinding, dragging: $draggingWidget) {
                    widgetContent(widget)
                }
            }
            Button("Personnaliser les outils", systemImage: "slider.horizontal.3") {
                presentAfterDismissing(.customize)
            }
            .buttonStyle(RideButtonStyle(primary: false))
            Menu {
                Button("Langue", systemImage: "globe") { presentAfterDismissing(.language) }
                Button("Réglages", systemImage: "gearshape") { presentAfterDismissing(.settings) }
                Button("Diagnostic", systemImage: "waveform.path.ecg") { presentAfterDismissing(.diagnostics) }
                Button("Aide", systemImage: "questionmark.circle") { presentAfterDismissing(.help) }
                Button("À propos", systemImage: "info.circle") { presentAfterDismissing(.about) }
            } label: {
                Label("Réglages et aide", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(RideButtonStyle(primary: false))
        }
    }

    private var maintenanceWidget: some View {
        Button { presentAfterDismissing(.maintenance) } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("L’ATELIER Double Interface", systemImage: "wrench.and.screwdriver.fill")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced)).tracking(1)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.headline)
                }.foregroundStyle(RivetCockpit.lime)
                HStack(alignment: .firstTextBaseline) {
                    Text(garage.mileage.map { $0.formatted() + " km" } ?? "Ta moto, au top.".rivetLocalized)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                    Spacer(minLength: 0)
                    if garage.attentionCount() > 0 {
                        Text("\(garage.attentionCount()) à surveiller").font(.caption.weight(.bold))
                            .foregroundStyle(RivetCockpit.orange)
                    }
                }
                Text(LocalizedStringKey(garage.tasks.contains(where: \.isConfigured)
                    ? "Retrouve tes échéances et ton historique."
                    : "Révisions, chaîne, pneus, filtres : crée ton carnet."))
                    .font(.caption).foregroundStyle(RivetCockpit.secondary)
                if let reading = garage.odometer {
                    HStack {
                        Label("Dernière lecture du compteur", systemImage: "motorcycle.fill")
                        Spacer(minLength: 0)
                        Text(reading.receivedAt, format: .dateTime.day().month().hour().minute())
                    }.font(.caption2).foregroundStyle(RivetCockpit.secondary)
                } else {
                    Text("Kilométrage automatique à la connexion de la moto.")
                        .font(.caption2).foregroundStyle(RivetCockpit.secondary)
                }
            }
            .foregroundStyle(RivetCockpit.paper).padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RivetCockpit.raised).clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(RivetCockpit.lime.opacity(0.22)))
        }.buttonStyle(RivetPressStyle()).accessibilityIdentifier("home.maintenance")
    }

    private var gpsWidget: some View {
        Button { presentAfterDismissing(.gpsHub) } label: {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("UN GPX. TOUTES TES ROUTES.")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced)).tracking(1)
                    Text("Mes GPS\n& mes fichiers").font(.system(.title2, design: .rounded).weight(.heavy))
                    Text("Importer · ouvrir · partager").font(.caption.weight(.semibold))
                }
                Spacer(minLength: 0)
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.system(size: 34, weight: .medium)).padding(.top, 20)
            }
            .foregroundStyle(RivetCockpit.asphalt).padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RivetCockpit.orange).clipShape(RoundedRectangle(cornerRadius: 26))
        }.buttonStyle(RivetPressStyle())
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "motorcycle.fill").font(.title2).foregroundStyle(RivetCockpit.lime)
                Text("Ta Kove").font(.system(.title3, design: .rounded).weight(.bold))
                Spacer()
                Image(systemName: bleController.hasTFTConnection ? "checkmark.circle.fill" : "link")
                    .foregroundStyle(bleController.hasTFTConnection ? RivetCockpit.lime : RivetCockpit.orange)
            }
            Text(LocalizedStringKey(bleController.isStreaming ? "La liaison vidéo avec le compteur est établie."
                 : (bleController.hasTFTConnection ? "Compteur connecté. Préparation du canal vidéo…"
                    : "La liaison avec la moto enregistrée reprend automatiquement.")))
                .font(.subheadline).foregroundStyle(RivetCockpit.secondary)
            Button(LocalizedStringKey(bleController.hasTFTConnection ? "Voir la connexion" : "Connexion"), systemImage: "arrow.right") { presentAfterDismissing(.connection) }
                .font(.subheadline.weight(.bold)).foregroundStyle(RivetCockpit.asphalt)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RivetCockpit.lime).clipShape(RoundedRectangle(cornerRadius: 14))
                .buttonStyle(RivetPressStyle())
            if bleController.isStreaming {
                Button("Arrêter l’envoi", role: .destructive) { bleController.stopMirroring() }
                    .font(.caption.weight(.semibold)).frame(minHeight: 44)
            }
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(RivetCockpit.panel).clipShape(RoundedRectangle(cornerRadius: 26))
    }

    private func actionCard(title: String, subtitle: String, symbol: String, accent: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol).font(.title2).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(title)).font(.system(.headline, design: .rounded))
                    Text(LocalizedStringKey(subtitle)).font(.caption).foregroundStyle(RivetCockpit.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(accent)
            }
            .foregroundStyle(RivetCockpit.paper).padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RivetCockpit.panel).clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(RivetCockpit.line))
        }.buttonStyle(RivetPressStyle())
    }

}
