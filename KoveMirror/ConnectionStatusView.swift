import SwiftUI
import MapKit

private enum RideHomeSheet: String, Identifiable {
    case apps, connection, preparation, settings, help, about, diagnostics, logs, manualApp, cockpit, gpsHub
    case maintenance, customize, language, chooseApp, choosePhoneApp, tools, framing
    var id: String { rawValue }
}

struct ConnectionStatusView: View {
    @StateObject var bleController: BleController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var heroTitleSize = 34.0
    @AppStorage("pairedMotorcycleSSID") private var pairedSSID = ""
    @AppStorage(NavigationAppChoice.preferenceKey) private var selectedValue = NavigationAppChoice.osmand.rawValue
    @AppStorage("rivet.phoneApplication") private var selectedPhoneValue = ""
    @AppStorage(NavigationAppChoice.shortcutsKey) private var shortcutsValue = NavigationAppChoice.defaultShortcuts
    @AppStorage(UserNavigationShortcut.preferenceKey) private var customValue = "[]"
    @AppStorage(DashboardLayout.firstKey) private var firstLayout = ""
    @AppStorage(DashboardLayout.secondKey) private var secondLayout = ""
    @AppStorage("rivet.activeCockpit") private var activeCockpit = 1
    @AppStorage(CockpitSettings.phoneKey) private var phonePageValue = CockpitPage.navigation.rawValue
    @AppStorage(CockpitSettings.tftKey) private var tftPageValue = CockpitPage.navigation.rawValue
    @AppStorage("rivet.showApplicationChoices") private var showingApplications = true
    @AppStorage(CockpitSettings.phoneAppKeepsTFTKey) private var phoneAppKeepsTFT = false
    @AppStorage(MotorcycleMaintenance.preferenceKey) private var maintenanceValue = ""
    @State private var sheet: RideHomeSheet?
    @State private var sheetAfterDismiss: RideHomeSheet?
    @State private var editingWidgets = false
    @State private var draggingWidget: DashboardWidget?
    @State private var scrollToTopToken = 0
    @State private var showMap = false
    @State private var showPhoneDisplay = false
    @State private var showWebCockpit = false
    @State private var pendingApp: ProjectionShortcutTarget?
    @State private var openAfterDismiss = false
    @State private var openingApp = false
    @State private var configurationOnly = false
    @State private var pendingAppKeepsTFT = false
    @State private var launchError: String?
    @State private var manualAppTitle = ""
    @State private var manualAppForSetup = false
    @State private var manualAppKeepsTFT = false
    @State private var openMapAfterDismiss = false
    @State private var returnHomeAfterExternalApp = false
    @State private var broadcastFraming = KoveScreenPreset.broadcastFraming

    init(bleController: BleController? = nil, currentWifiSSID: String? = nil) {
        _bleController = StateObject(wrappedValue: bleController ?? BleController())
        _ = currentWifiSSID
    }

    private var apps: [ProjectionShortcutTarget] {
        NavigationAppChoice.shortcuts(in: shortcutsValue).map { .builtIn($0) }
        + UserNavigationShortcut.load(customValue).filter(\.enabled).map { .custom($0) }
    }
    private var garage: MotorcycleMaintenance { .load(maintenanceValue) }
    private var selectedApp: ProjectionShortcutTarget? {
        if let app = NavigationAppChoice(rawValue: selectedValue) { return .builtIn(app) }
        return UserNavigationShortcut.load(customValue)
            .first { "custom:" + $0.id.uuidString == selectedValue }.map { .custom($0) }
    }
    private var selectedPhoneApp: ProjectionShortcutTarget? {
        if let app = NavigationAppChoice(rawValue: selectedPhoneValue) { return .builtIn(app) }
        return UserNavigationShortcut.load(customValue)
            .first { "custom:" + $0.id.uuidString == selectedPhoneValue }.map { .custom($0) }
    }
    private var outputModeTitle: String {
        if showingApplications { return phoneAppKeepsTFT ? "Application iPhone + vue TFT" : "Application en miroir" }
        return "Deux vues Double Interface séparées"
    }
    private var activeVideoTitle: String? {
        switch bleController.projectionMode {
        case .screen: return bleController.isWebPanelProjectionActive
            ? "Miniature de la carte web" : "Écran Double Interface en miroir"
        case .broadcast: return broadcastFraming.requiresBroadcast ? "Zone sélectionnée de l’iPhone" : "Écran visible de l’iPhone"
        case .navigation: return "Vue Double Interface indépendante"
        case .paused: return "Envoi en pause"
        case .disconnected: return nil
        }
    }
    private var layout: DashboardLayout {
        DashboardLayout.load(activeCockpit == 2 ? secondLayout : firstLayout, second: activeCockpit == 2)
    }
    private var layoutBinding: Binding<DashboardLayout> {
        Binding(get: { layout }, set: { value in
            if activeCockpit == 2 { secondLayout = value.encoded() } else { firstLayout = value.encoded() }
        })
    }
    private var availability: ExternalProjectionAvailability {
        .evaluate(videoConnected: bleController.isStreaming,
                  broadcastConnected: bleController.isBroadcasting, openingApp: openingApp,
                  requiresBroadcast: !pendingAppKeepsTFT)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header.id("homeTop")
                        actionCard(title: "Deux écrans · essai web",
                                   subtitle: "Waze et Wikiloc. Touche la miniature pour échanger les écrans.",
                                   symbol: "rectangle.on.rectangle", accent: RivetCockpit.lime) {
                            showWebCockpit = true
                        }
                        DualScreenOverview(
                            phoneTitle: showingApplications
                                ? selectedPhoneApp?.title ?? "Choisir une application" : CockpitPage.saved(phonePageValue).title.rivetLocalized,
                            tftTitle: showingApplications && !phoneAppKeepsTFT ? selectedApp?.title ?? "Application"
                                : "Double Interface · " + CockpitPage.saved(tftPageValue).title.rivetLocalized,
                            modeTitle: outputModeTitle, videoConnected: bleController.isStreaming,
                            activeVideoTitle: activeVideoTitle,
                            onPhone: openPhoneDisplay,
                            onTFT: { sheet = showingApplications ? .chooseApp : .cockpit })
                        statusStrip
                        screenSourceControls
                        actionCard(title: "Mes outils", subtitle: "Météo, entretien et préparation du voyage.",
                                   symbol: "square.grid.2x2", accent: RivetCockpit.secondary) { sheet = .tools }
                        HStack {
                            Text("Double Interface").font(.system(size: 13, weight: .black, design: .rounded)).tracking(0.5)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Spacer()
                            Button("Un coup de main ?") { sheet = .help }.font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(RivetCockpit.secondary).padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showingApplications)
                }
                .onChange(of: scrollToTopToken) { _, _ in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { proxy.scrollTo("homeTop", anchor: .top) }
                }
            }
            .background(RivetCockpit.asphalt).foregroundStyle(RivetCockpit.paper)
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomDock }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 10) {
                        Image("RideMark").resizable().scaledToFit().frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Double Interface").font(.system(size: 17, weight: .black, design: .rounded)).tracking(0.4)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Text("LE LIEN ENTRE TES ÉCRANS").font(.system(size: 8, weight: .bold, design: .monospaced))
                                .tracking(1.2).foregroundStyle(RivetCockpit.secondary)
                        }
                    }.foregroundStyle(RivetCockpit.paper)
                }
                ToolbarItem(placement: .topBarTrailing) { appMenu }
            }
            .toolbarBackground(RivetCockpit.asphalt, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark).tint(RivetCockpit.lime)
        .sheet(item: $sheet, onDismiss: sheetDismissed) { item in
            switch item {
            case .apps:
                NavigationAppMenu(onOpenForSetup: requestConfiguration,
                    onChooseForDisplay: { presentAfterDismissing(.chooseApp) })
            case .chooseApp:
                ProjectionAppPicker(apps: apps, selectedValue: selectedValue, openingApp: openingApp,
                    independentTFTTitle: phoneAppKeepsTFT ? CockpitPage.saved(tftPageValue).title.rivetLocalized : nil,
                    onOpen: requestShortcut, onConfigure: requestConfiguration,
                    onManage: { presentAfterDismissing(.apps) })
            case .choosePhoneApp:
                ProjectionAppPicker(apps: apps, selectedValue: selectedPhoneValue, openingApp: openingApp,
                    independentTFTTitle: bleController.projectionMode == .navigation ? "Vue intégrée" : nil,
                    phoneSelection: true,
                    onOpen: requestPhoneApplication, onConfigure: requestPhoneApplication,
                    onManage: { presentAfterDismissing(.apps) })
            case .connection, .preparation:
                ProjectionPreparationView(bleController: bleController,
                    pairedSSID: $pairedSSID,
                    appTitle: item == .preparation ? pendingApp?.title : nil,
                    requiresBroadcast: item == .preparation ? !pendingAppKeepsTFT
                        : showingApplications && !phoneAppKeepsTFT)
                    .onAppear { if item == .preparation { tryPendingShortcut() } }
            case .settings: SettingsView()
            case .framing: ScreenCropView()
            case .language: AppLanguageView()
            case .help: HelpView()
            case .about: AboutView()
            case .cockpit:
                CockpitView(bleController: bleController,
                    onChooseApplication: { presentAfterDismissing(.chooseApp) })
            case .gpsHub: GPSHubView()
            case .maintenance: MaintenanceView(bleController: bleController)
            case .tools: toolsSheet
            case .customize: DashboardCustomizationView(layout: layoutBinding, cockpitNumber: activeCockpit)
            case .manualApp:
                ManualAppOpenView(title: manualAppTitle, forSetup: manualAppForSetup, keepsTFT: manualAppKeepsTFT)
            case .diagnostics:
                RideSheet("Diagnostic du compteur") {
                    ProjectionDiagnosticCard()
                    Button("Journal de connexion") { presentAfterDismissing(.logs) }
                        .buttonStyle(RideButtonStyle(primary: false))
                }
            case .logs: EventLogView(bleController: bleController)
            }
        }
        .fullScreenCover(isPresented: $showMap) { MapView() }
        .fullScreenCover(isPresented: $showPhoneDisplay) {
            CockpitView(bleController: bleController, onChooseApplication: {}, phoneDisplayOnly: true)
        }
        .fullScreenCover(isPresented: $showWebCockpit) { WebCockpitView(bleController: bleController) }
        .onChange(of: showMap) { _, value in bleController.isMapViewVisible = value }
        .onChange(of: bleController.isBroadcasting) { _, _ in tryPendingShortcut() }
        .onChange(of: bleController.isStreaming) { _, _ in tryPendingShortcut() }
        .onChange(of: activeCockpit) { _, _ in editingWidgets = false; draggingWidget = nil }
        .onChange(of: editingWidgets) { _, editing in if !editing { draggingWidget = nil } }
        .sensoryFeedback(.selection, trigger: selectedValue)
        .sensoryFeedback(.selection, trigger: activeCockpit)
        .onReceive(NotificationCenter.default.publisher(for: .rivetShortcutFailed)) { note in
            launchError = (note.object as? String) ?? "Le raccourci iOS n’a pas pu être exécuté. Vérifie son nom dans Raccourcis."
        }
        .onReceive(NotificationCenter.default.publisher(for: KoveScreenPreset.configChangedNotification)) { _ in
            broadcastFraming = KoveScreenPreset.broadcastFraming
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if sheet == .manualApp { returnHomeAfterExternalApp = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard returnHomeAfterExternalApp else { return }
            returnHomeAfterExternalApp = false
            // The iOS back link returns to the home screen, without ending
            // ReplayKit, changing the TFT source or starting another connection.
            sheetAfterDismiss = nil
            openAfterDismiss = false
            openMapAfterDismiss = false
            pendingApp = nil
            configurationOnly = false
            pendingAppKeepsTFT = false
            sheet = nil
            showMap = false
            showPhoneDisplay = false
            scrollToTopToken += 1
        }
        .alert("Application à afficher", isPresented: Binding(
            get: { launchError != nil }, set: { if !$0 { launchError = nil } }
        )) {
            Button("OK", role: .cancel) { launchError = nil }
        } message: { Text(LocalizedStringKey(launchError ?? "")) }
        .onAppear {
            if maintenanceValue.isEmpty { maintenanceValue = (try? MotorcycleMaintenance().encoded()) ?? "" }
            if activeCockpit != 1 && activeCockpit != 2 { activeCockpit = 1 }
            guard !bleController.isPreview, !bleController.isStreaming else { return }
            bleController.resumeAutomaticConnection()
        }
    }

    private var appMenu: some View {
        Menu {
            Button("Mes deux écrans", systemImage: "rectangle.on.rectangle") { sheet = .cockpit }
            Button("Choisir une application", systemImage: "square.grid.2x2") { sheet = .chooseApp }
            Button("Mes outils", systemImage: "square.grid.2x2.fill") { sheet = .tools }
            Button("Personnaliser les outils", systemImage: "slider.horizontal.3") { sheet = .customize }
            Button("Entretien de la moto", systemImage: "wrench.and.screwdriver") { sheet = .maintenance }
            Button("Langue", systemImage: "globe") { sheet = .language }
            Divider()
            Button("Connexion à la Kove", systemImage: "wifi") { sheet = .connection }
            Button("Cadrage du TFT", systemImage: "crop") { sheet = .framing }
            Button("Réglages", systemImage: "slider.horizontal.3") { sheet = .settings }
            Button("Diagnostic", systemImage: "waveform.path.ecg") { sheet = .diagnostics }
            Button("Aide", systemImage: "questionmark.circle") { sheet = .help }
            Button("À propos", systemImage: "info.circle") { sheet = .about }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18, weight: .bold)).foregroundStyle(RivetCockpit.paper)
                .frame(width: 44, height: 44).background(RivetCockpit.panel).clipShape(Circle())
        }
        .accessibilityLabel("Menu").accessibilityIdentifier("home.menu")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("LE CŒUR DE Double Interface").font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.7).foregroundStyle(RivetCockpit.lime)
                Spacer()
                Image(systemName: "link").font(.system(size: 20, weight: .bold))
                    .foregroundStyle(RivetCockpit.lime)
            }
            Text("DEUX ÉCRANS.\nTON COCKPIT.")
                .font(.system(size: heroTitleSize, weight: .black, design: .rounded)).italic()
                .tracking(-1).fixedSize(horizontal: false, vertical: true)
            Text("Choisis ton affichage. Relie ta moto. Prends la route.")
                .font(.caption).foregroundStyle(RivetCockpit.secondary)
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(colors: [RivetCockpit.raised, RivetCockpit.panel], startPoint: .topLeading, endPoint: .bottomTrailing)
                RivetContours()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(RivetCockpit.lime.opacity(0.18)))
        .accessibilityElement(children: .combine)
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

    private var screenSourceControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("Type d’affichage", selection: $showingApplications) {
                Text("Applications").tag(true)
                Text("Vues Double Interface").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("home.displaySource")
            if showingApplications {
                RideCard {
                    Picker("Sur le TFT", selection: Binding(get: {
                        phoneAppKeepsTFT ? tftPageValue : "mirror"
                    }, set: { value in
                        phoneAppKeepsTFT = value != "mirror"
                        if value != "mirror" { tftPageValue = value }
                    })) {
                        Text("Même application que l’iPhone").tag("mirror")
                        ForEach(CockpitPage.allCases) { page in
                            Text("Double Interface · " + page.title.rivetLocalized).tag(page.rawValue)
                        }
                    }
                    .pickerStyle(.menu).tint(RivetCockpit.orange)
                    .accessibilityIdentifier("home.appTFTContent")
                    Text(LocalizedStringKey(phoneAppKeepsTFT
                        ? "L’app s’ouvre sur l’iPhone. Le TFT conserve la vue Double Interface choisie, sans recopier l’écran du téléphone."
                        : "L’app choisie s’ouvre sur l’iPhone et son écran est recopié sur le TFT."))
                        .font(.caption).foregroundStyle(RivetCockpit.secondary)
                }
                shortcuts
            } else {
                RideCard {
                    Label("Deux vues, deux choix", systemImage: "rectangle.on.rectangle")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Picker("Sur l’iPhone", selection: $phonePageValue) {
                        ForEach(CockpitPage.allCases) { page in
                            Text(LocalizedStringKey(page.title)).tag(page.rawValue)
                        }
                    }
                    .pickerStyle(.menu).tint(RivetCockpit.lime)
                    .accessibilityIdentifier("home.phoneContent")
                    Divider()
                    Picker("Sur le TFT", selection: Binding(get: { tftPageValue }, set: { value in
                        bleController.sendCockpitPage(.saved(value))
                    })) {
                        ForEach(CockpitPage.allCases) { page in
                            Text(LocalizedStringKey(page.title)).tag(page.rawValue)
                        }
                    }
                    .pickerStyle(.menu).tint(RivetCockpit.orange)
                    .accessibilityIdentifier("home.tftContent")
                    Text("Le TFT reçoit les consignes et le tracé simplifié de Double Interface. Prépare ta destination ou ta trace sur l’iPhone.")
                        .font(.caption).foregroundStyle(RivetCockpit.secondary)
                    Button(LocalizedStringKey(bleController.isStreaming ? "Afficher ces deux vues" : "Relier le TFT pour afficher"), systemImage: "play.fill") {
                        phoneAppKeepsTFT = false
                        bleController.sendCockpitPage(.saved(tftPageValue))
                        if bleController.isStreaming { showPhoneDisplay = true }
                        else { sheet = .connection }
                    }
                    .buttonStyle(RideButtonStyle())
                    .accessibilityIdentifier("home.startRivetViews")
                    Button("Revenir au miroir de l’iPhone", systemImage: "rectangle.on.rectangle") {
                        bleController.returnToPhoneMirror()
                    }
                    .buttonStyle(RideButtonStyle(primary: false))
                }
            }
        }
    }

    private func openPhoneDisplay() {
        if showingApplications {
            sheet = .choosePhoneApp
        } else {
            showPhoneDisplay = true
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
        }
    }

    private var statusStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { statusButtons }
            VStack(alignment: .leading, spacing: 10) { statusButtons }
        }
    }
    @ViewBuilder private var statusButtons: some View {
        statusButton(bleController.isStreaming ? "TFT relié"
                     : (bleController.hasTFTConnection ? "Vidéo en attente" : "Relier le TFT"),
                     active: bleController.hasTFTConnection,
                     symbol: "wifi") { sheet = .connection }
        if showingApplications && !phoneAppKeepsTFT {
            statusButton(bleController.isBroadcasting ? "Diffusion connectée" : "Lancer la diffusion", active: bleController.isBroadcasting,
                         symbol: "record.circle") { sheet = .preparation }
        } else {
            statusButton("Régler les vues", active: bleController.projectionMode == .navigation,
                         symbol: "rectangle.on.rectangle") { sheet = .cockpit }
        }
    }
    private func statusButton(_ title: String, active: Bool, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle().fill(active ? RivetCockpit.lime : RivetCockpit.orange).frame(width: 6, height: 6)
                Text(LocalizedStringKey(title)).font(.system(size: 11, weight: .semibold))
                Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(RivetCockpit.paper).padding(.horizontal, 12).frame(minHeight: 44)
            .background(RivetCockpit.panel).clipShape(Capsule())
        }.buttonStyle(RivetPressStyle())
    }

    @ViewBuilder private func widgetContent(_ widget: DashboardWidget) -> some View {
        switch widget {
        case .applications: shortcuts
        case .weather: CockpitWeatherWidget()
        case .maintenance: maintenanceWidget
        case .gps: gpsWidget
        case .connection: connectionCard
        case .screens:
            actionCard(title: "Mes deux écrans", subtitle: "Règle les vues du téléphone et du compteur.",
                       symbol: "rectangle.on.rectangle", accent: RivetCockpit.lime) { presentAfterDismissing(.cockpit) }
        case .map: builtInMapButton
        }
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                RivetSectionHeading(eyebrow: "UN TOUCHER, C’EST PARTI", title: "Mes applications")
                Spacer(minLength: 6)
                Button("Modifier") { presentAfterDismissing(.apps) }
                    .font(.caption.weight(.bold)).foregroundStyle(RivetCockpit.lime)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RivetCockpit.panel).clipShape(Capsule())
            }
            NavigationAppGrid(apps: apps, selectedValue: selectedValue,
                keepsIndependentTFT: phoneAppKeepsTFT,
                onOpen: requestShortcut, onConfigure: requestConfiguration,
                onAdd: { presentAfterDismissing(.apps) })
                .disabled(openingApp)
            Text(LocalizedStringKey(phoneAppKeepsTFT
                ? "Le TFT conserve sa vue Double Interface. Maintiens une app pour l’ouvrir et la régler."
                : "Le compteur suit l’écran visible de l’iPhone. Maintiens une app pour l’ouvrir et la régler."))
                .font(.caption2).foregroundStyle(RivetCockpit.secondary)
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
            Button(LocalizedStringKey(bleController.hasTFTConnection ? "Voir la connexion" : "Voir la reconnexion"), systemImage: "arrow.right") { presentAfterDismissing(.connection) }
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

    private var builtInMapButton: some View {
        actionCard(title: "Carte & traces GPX", subtitle: "La navigation intégrée à l’application.",
                   symbol: "map.fill", accent: RivetCockpit.orange) {
            bleController.returnToInternalProjection()
            if sheet == nil { showMap = true }
            else { openMapAfterDismiss = true; sheet = nil }
        }
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

    private var bottomDock: some View {
        HStack(spacing: 0) {
            RivetDockButton(title: "Écrans", symbol: "rectangle.on.rectangle", selected: true) { scrollToTopToken += 1 }
            RivetDockButton(title: "Applications", symbol: "square.grid.2x2") { sheet = .chooseApp }
            RivetDockButton(title: "Connexion", symbol: "link") { sheet = .connection }
            RivetDockButton(title: "Outils", symbol: "slider.horizontal.3") { sheet = .tools }
        }
        .padding(.horizontal, 14).padding(.top, 8)
        .background(RivetCockpit.asphalt.opacity(0.97))
        .overlay(alignment: .top) { Rectangle().fill(RivetCockpit.line).frame(height: 0.5) }
    }

    private func requestShortcut(_ app: ProjectionShortcutTarget) {
        guard !openingApp else { return }
        selectedValue = app.id
        configurationOnly = false
        pendingAppKeepsTFT = phoneAppKeepsTFT
        pendingApp = app
        launchError = nil
        if availability.canOpenApp {
            if sheet == nil {
                openPendingShortcut()
            } else {
                openAfterDismiss = true
                sheet = nil
            }
        } else {
            // Resume the existing session without asking the rider to confirm
            // Wi-Fi/BLE again. Preparation only waits for video or first broadcast.
            bleController.resumeConnection()
            presentAfterDismissing(.preparation)
        }
    }

    private func presentAfterDismissing(_ destination: RideHomeSheet) {
        openAfterDismiss = false
        if destination != .preparation {
            pendingApp = nil
            configurationOnly = false
            pendingAppKeepsTFT = false
        }
        if sheet == nil {
            sheet = destination
        } else {
            sheetAfterDismiss = destination
            sheet = nil
        }
    }

    private func tryPendingShortcut() {
        guard !configurationOnly, pendingApp != nil, availability.canOpenApp,
              sheetAfterDismiss == nil, sheet == .preparation else { return }
        openAfterDismiss = true
        sheet = nil
    }

    private func requestConfiguration(_ app: ProjectionShortcutTarget) {
        requestPhoneApplication(app)
    }

    private func requestPhoneApplication(_ app: ProjectionShortcutTarget) {
        guard !openingApp else { return }
        selectedPhoneValue = app.id
        // An external mirror follows whichever application is on the phone.
        if bleController.externalAppMirroringRequested && !phoneAppKeepsTFT {
            selectedValue = app.id
        }
        pendingApp = app
        configurationOnly = true
        pendingAppKeepsTFT = false
        launchError = nil
        if sheet == nil {
            openPendingShortcut()
        } else {
            openAfterDismiss = true
            sheet = nil
        }
    }

    private func sheetDismissed() {
        if let destination = sheetAfterDismiss {
            sheetAfterDismiss = nil
            sheet = destination
        } else if openAfterDismiss {
            openAfterDismiss = false
            openPendingShortcut()
        } else if openMapAfterDismiss {
            openMapAfterDismiss = false
            showMap = true
        } else {
            // Cancelling preparation must never open an app later on a reconnect.
            pendingApp = nil
            configurationOnly = false
            pendingAppKeepsTFT = false
        }
    }

    private func openPendingShortcut() {
        guard let app = pendingApp, !openingApp else { return }
        guard configurationOnly || availability.canOpenApp else {
            presentAfterDismissing(.preparation)
            return
        }
        let wasExternal = bleController.externalAppMirroringRequested
        let keepIndependentTFT = !configurationOnly && pendingAppKeepsTFT
        let forSetup = configurationOnly
        let prepareBroadcast = !configurationOnly && !keepIndependentTFT
        if prepareBroadcast, !bleController.beginExternalAppMirroring() {
            bleController.resumeConnection()
            presentAfterDismissing(.preparation)
            return
        }
        pendingApp = nil
        configurationOnly = false
        pendingAppKeepsTFT = false
        if keepIndependentTFT { bleController.sendCockpitPage(.saved(tftPageValue)) }
        selectedPhoneValue = app.id
        openingApp = true
        if app.usesAppleMaps {
            completeLaunch(MKMapItem.openMaps(with: [], launchOptions: nil), app: app,
                           restoreInternalOnFailure: prepareBroadcast && !wasExternal)
        } else if let url = app.launchURL(errorCallback: shortcutErrorURL) {
            let options: [UIApplication.OpenExternalURLOptionsKey: Any] =
                app.universalLinkOnly ? [.universalLinksOnly: true] : [:]
            UIApplication.shared.open(url, options: options) { opened in
                completeLaunch(opened, app: app, restoreInternalOnFailure: prepareBroadcast && !wasExternal)
            }
        } else {
            openingApp = false
            manualAppTitle = app.title
            manualAppForSetup = forSetup
            manualAppKeepsTFT = keepIndependentTFT
            sheet = .manualApp
        }
    }

    private var shortcutErrorURL: URL? {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        guard let scheme = (types?.first?["CFBundleURLSchemes"] as? [String])?.first else { return nil }
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = "shortcut-error"
        return parts.url
    }

    private func completeLaunch(_ opened: Bool, app: ProjectionShortcutTarget, restoreInternalOnFailure: Bool) {
        openingApp = false
        if opened {
            returnHomeAfterExternalApp = true
            return
        }
        if restoreInternalOnFailure { bleController.returnToInternalProjection() }
        launchError = app.title + " n’a pas pu être ouvert. Vérifie que l’app est installée et ouvre-la une fois depuis l’accueil de l’iPhone. Tu peux aussi l’ouvrir manuellement pendant la diffusion."
    }
}
