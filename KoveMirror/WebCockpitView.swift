import SwiftUI
import WebKit
import MapKit
import UniformTypeIdentifiers

private enum DualCockpitSheet: Identifiable {
    case content(WebPanelID), destination, connection, phone, info
    var id: String {
        switch self {
        case .content(let panel): return "content-\(panel.rawValue)"
        case .destination: return "destination"
        case .connection: return "connection"
        case .phone: return "phone"
        case .info: return "info"
        }
    }
}

/// Two in-app panels share the phone. Native applications use an explicit
/// whole-phone sharing mode; they are never represented as embedded views.
struct WebCockpitView: View {
    @ObservedObject var bleController: BleController
    let onOpenTools: () -> Void
    @StateObject private var session = WebCockpitSession.shared
    @ObservedObject private var nav = LocationAndNavigationManager.shared
    @AppStorage("pairedMotorcycleSSID") private var pairedSSID = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragOffset = CGSize.zero
    @State private var sheet: DualCockpitSheet?
    @State private var importingTrack = false
    @State private var error: String?
    @State private var routeRequest: UUID?
    @State private var visible = false
    @State private var previousIdleTimer = false

    private var mainContent: DualPanelContent { session.contents.content(session.layout.phone) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                canvas(insets: geometry.safeAreaInsets).ignoresSafeArea(.container)
                HStack(spacing: 8) {
                    Button {
                        sheet = .content(session.layout.phone)
                    } label: {
                        Label(session.title(session.layout.phone), systemImage: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .padding(.horizontal, 14).frame(minHeight: 44)
                            .background(RivetCockpit.asphalt.opacity(0.96), in: Capsule())
                    }
                    .disabled(routeRequest != nil)
                    .accessibilityIdentifier("dualCockpit.chooseMain")
                    Spacer(minLength: 0)
                    if mainContent != .empty {
                        Button {
                            if session.locationNeedsSettings, let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            } else { session.showNearbyMap() }
                        } label: {
                            Image(systemName: session.locationNeedsSettings ? "location.slash" : "location.fill")
                                .foregroundStyle(session.hasFreshLocation ? RivetCockpit.lime : RivetCockpit.orange)
                                .frame(width: 44, height: 44)
                                .background(RivetCockpit.asphalt.opacity(0.96), in: Circle())
                        }
                        .accessibilityLabel("Recentrer sur ma position")
                    }
                    toolbar
                }
                .buttonStyle(.plain).font(.title3.weight(.semibold))
                .padding(12).shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                .zIndex(2)
                if bleController.isPhoneScreenSelected {
                    Button { sheet = .phone } label: {
                        Label("TFT · écran de l’iPhone", systemImage: "iphone")
                            .font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RivetCockpit.asphalt, in: Capsule())
                    }
                    .buttonStyle(.plain).padding(.top, 68).zIndex(2)
                }
                if routeRequest != nil {
                    ProgressView("Calcul de l’itinéraire…")
                        .padding(16).background(RivetCockpit.asphalt, in: Capsule())
                        .frame(maxHeight: .infinity, alignment: .center).zIndex(3)
                }
            }
        }
        .background(RivetCockpit.asphalt).foregroundStyle(RivetCockpit.paper)
        .preferredColorScheme(.dark).tint(RivetCockpit.lime)
        .statusBarHidden(true).persistentSystemOverlays(.hidden)
        .onAppear {
            visible = true
            previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
            if session.contents.first != .empty || session.contents.second != .empty { session.beginLocation() }
            bleController.beginWebPanelProjection()
        }
        .onDisappear {
            visible = false
            routeRequest = nil
            bleController.endWebPanelProjection()
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimer
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .content(let id): DualContentPicker(session: session, bleController: bleController, panel: id)
            case .destination:
                DestinationSearchSheet(userRegion: searchRegion) { destination in
                    sheet = nil
                    calculateRoute(to: destination)
                }
            case .connection:
                ProjectionPreparationView(bleController: bleController, pairedSSID: $pairedSSID)
            case .phone:
                PhoneProjectionView(bleController: bleController)
            case .info: infoSheet
            }
        }
        .fileImporter(isPresented: $importingTrack, allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                try nav.importGPX(data: Data(contentsOf: url, options: .mappedIfSafe),
                                  name: url.deletingPathExtension().lastPathComponent)
                nav.startFollowingGPX()
                session.navigation.refresh()
                session.navigation.showRoute()
            } catch { self.error = error.localizedDescription }
        }
        .alert("Navigation", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private var toolbar: some View {
        Menu {
            Button("Choisir le grand écran", systemImage: "rectangle") { sheet = .content(session.layout.phone) }
            Button("Choisir la petite fenêtre", systemImage: "rectangle.inset.bottomtrailing") { sheet = .content(session.layout.tft) }
            Button("Échanger les deux écrans", systemImage: "arrow.left.arrow.right") { session.exchange() }
            Button("Applications et écran de l’iPhone", systemImage: "iphone") { sheet = .phone }
            if bleController.isPhoneScreenSelected {
                Button("Envoyer la petite fenêtre au TFT", systemImage: "rectangle.inset.bottomtrailing") {
                    bleController.selectMiniature()
                }
            }
            if mainContent == .navigation {
                Divider()
                Button("Destination", systemImage: "magnifyingglass") { sheet = .destination }
                    .disabled(routeRequest != nil)
                Button("Importer une trace GPX", systemImage: "square.and.arrow.down") { importingTrack = true }
                    .disabled(routeRequest != nil)
                Button("Voir tout le tracé", systemImage: "arrow.up.left.and.arrow.down.right") { session.navigation.showRoute() }
                if nav.isNavigating {
                    Button("Arrêter le guidage", systemImage: "stop.circle") { nav.stopNavigation() }
                }
            } else if mainContent == .website {
                Divider()
                Button("Page précédente", systemImage: "chevron.backward") { session.goBack(session.layout.phone) }
                Button("Actualiser le site", systemImage: "arrow.clockwise") { session.reload(session.layout.phone) }
            }
            Divider()
            Button("Connexion", systemImage: "link") { sheet = .connection }
            Button("Outils", systemImage: "slider.horizontal.3", action: onOpenTools)
            Button("État et aide", systemImage: "info.circle") { sheet = .info }
        } label: {
            Image(systemName: "ellipsis").frame(width: 44, height: 44)
                .background(RivetCockpit.asphalt.opacity(0.96), in: Circle())
        }
        .accessibilityLabel("Menu des deux écrans")
        .accessibilityIdentifier("dualCockpit.menu")
    }

    private func canvas(insets: EdgeInsets) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let availableWidth = max(1, size.width - insets.leading - insets.trailing - 16)
            let availableHeight = max(1, size.height - insets.top - insets.bottom - 16)
            let source = session.canvasSize
            let targetWidth = min(availableWidth, min(104, max(72, availableWidth * 0.24)))
            let scale = min(targetWidth / source.width, availableHeight * 0.48 / source.height)
            let miniSize = CGSize(width: source.width * scale, height: source.height * scale)
            ZStack(alignment: .topLeading) {
                ForEach(WebPanelID.allCases) { id in
                    let miniature = id == session.layout.tft
                    let frame = miniature ? miniSize : size
                    panel(id, miniature: miniature, viewport: miniature ? source : size)
                        .frame(width: frame.width, height: frame.height)
                        .clipShape(RoundedRectangle(cornerRadius: miniature ? 16 : 0))
                        .overlay(RoundedRectangle(cornerRadius: miniature ? 16 : 0)
                            .strokeBorder(miniature ? RivetCockpit.lime : .clear, lineWidth: miniature ? 2 : 0))
                        .shadow(color: .black.opacity(miniature ? 0.5 : 0), radius: 12, y: 5)
                        .overlay { if miniature { miniControls(area: size, mini: miniSize, insets: insets) } }
                        .position(miniature ? miniCenter(area: size, mini: miniSize, insets: insets, offset: dragOffset)
                                  : CGPoint(x: size.width / 2, y: size.height / 2))
                        .zIndex(miniature ? 1 : 0)
                }
            }
            .coordinateSpace(name: "dualCockpitCanvas").clipped()
        }
    }

    private func panel(_ id: WebPanelID, miniature: Bool, viewport: CGSize) -> some View {
        ZStack {
            switch session.contents.content(id) {
            case .empty:
                Button { sheet = .content(id) } label: {
                    VStack(spacing: 14) {
                        Image(systemName: "plus.circle").font(.system(size: miniature ? 30 : 60, weight: .light))
                        Text(miniature ? "Choisir" : "Choisir un contenu")
                            .font(.system(size: miniature ? 12 : 22, weight: .bold, design: .rounded))
                        if !miniature {
                            Text("Applications · site web · écran de l’iPhone")
                                .font(.subheadline).foregroundStyle(RivetCockpit.secondary)
                        }
                    }
                    .foregroundStyle(RivetCockpit.lime).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RivetCockpit.asphalt)
                }.buttonStyle(.plain)
            case .navigation:
                PanelUIKitHost(view: session.navigation.view, canvasSize: viewport,
                               navigation: session.navigation, topInset: miniature ? 32 : (viewport.height > viewport.width ? 128 : 68))
            case .website:
                PanelUIKitHost(view: session.webView(id), canvasSize: viewport)
                if session.waitingForLocation.contains(id) {
                    VStack(spacing: 10) {
                        ProgressView().tint(RivetCockpit.lime)
                        Text("Recherche de ta position…").font(.callout)
                        if !miniature {
                            Button("Afficher sans position") { session.continueWithoutLocation(id) }
                        }
                    }
                    .padding().background(RivetCockpit.asphalt, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .allowsHitTesting(!miniature)
        .accessibilityIdentifier(miniature ? "dualCockpit.miniature" : "dualCockpit.main")
    }

    private func tapMiniature() {
        if session.contents.first == .empty && session.contents.second == .empty {
            sheet = .content(session.layout.tft)
        } else {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { session.exchange() }
        }
    }

    private func miniControls(area: CGSize, mini: CGSize, insets: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            Button { sheet = .content(session.layout.tft) } label: {
                Text((bleController.isPhoneScreenSelected ? "Mini · " : "TFT · ") + session.title(session.layout.tft))
                    .font(.system(size: 9, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(RivetCockpit.asphalt).padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 32).background(RivetCockpit.lime)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choisir le contenu de la petite fenêtre")
            .accessibilityIdentifier("dualCockpit.chooseMiniature")
            Color.clear.contentShape(Rectangle())
                .onTapGesture(perform: tapMiniature)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Échanger les deux écrans")
                .accessibilityAddTraits(.isButton).accessibilityAction { tapMiniature() }
        }
            .highPriorityGesture(DragGesture(minimumDistance: 10, coordinateSpace: .named("dualCockpitCanvas"))
                .updating($dragOffset) { value, state, _ in state = value.translation }
                .onEnded { value in
                    let center = miniCenter(area: area, mini: mini, insets: insets, offset: value.translation)
                    let travel = miniTravel(area: area, mini: mini, insets: insets)
                    session.moveMini(x: Double((center.x - travel.minX) / max(1, travel.width)),
                                     y: Double((center.y - travel.minY) / max(1, travel.height)))
                })
            .accessibilityElement(children: .contain)
            .accessibilityHint("Titre pour choisir. Image pour échanger. Glisser pour déplacer.")
    }

    private func miniTravel(area: CGSize, mini: CGSize, insets: EdgeInsets) -> CGRect {
        let left = insets.leading + mini.width / 2 + 8
        let top = insets.top + mini.height / 2 + 8
        let right = max(left, area.width - insets.trailing - mini.width / 2 - 8)
        let bottom = max(top, area.height - insets.bottom - mini.height / 2 - 8)
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    private func miniCenter(area: CGSize, mini: CGSize, insets: EdgeInsets, offset: CGSize) -> CGPoint {
        let travel = miniTravel(area: area, mini: mini, insets: insets)
        return CGPoint(x: min(travel.maxX, max(travel.minX, travel.minX + travel.width * CGFloat(session.layout.miniX) + offset.width)),
                       y: min(travel.maxY, max(travel.minY, travel.minY + travel.height * CGFloat(session.layout.miniY) + offset.height)))
    }

    private var searchRegion: MKCoordinateRegion? {
        nav.userLocation.map { MKCoordinateRegion(center: $0.coordinate, latitudinalMeters: 20000, longitudinalMeters: 20000) }
    }

    private func calculateRoute(to destination: MKMapItem) {
        guard routeRequest == nil else { return }
        guard session.hasFreshLocation else {
            session.beginLocation()
            error = "Attends une position GPS récente avant de calculer l’itinéraire. Si nécessaire, autorise la localisation dans les réglages."
            return
        }
        let token = UUID()
        routeRequest = token
        nav.calculateRoute(to: destination) { result in
            DispatchQueue.main.async {
                guard visible, routeRequest == token else { return }
                routeRequest = nil
                switch result {
                case .success(let route):
                    nav.startNavigation(route: route, destination: destination)
                    session.navigation.refresh()
                    session.navigation.recenter()
                case .failure(let failure): error = failure.localizedDescription
                }
            }
        }
    }

    private var infoSheet: some View {
        RideSheet("Mes deux écrans") {
            Label(bleController.isStreaming ? "Canal vidéo connecté" : "Connexion à préparer dans Connexion",
                  systemImage: bleController.isStreaming ? "link" : "wifi")
            Text("Grand écran : " + session.title(session.layout.phone))
            Text(bleController.isPhoneScreenSelected ? "TFT : écran complet de l’iPhone"
                 : "Petite fenêtre / TFT : " + session.title(session.layout.tft)).font(.headline)
            Text("Touche un titre pour choisir le contenu. Touche l’image de la petite fenêtre pour échanger. Glisse-la pour la déplacer.")
            Text(session.locationStatus).font(.subheadline)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let failure = session.snapshotError { Text(failure).foregroundStyle(RivetCockpit.orange) }
                else if let date = session.lastSnapshot {
                    Text(context.date.timeIntervalSince(date) < 4 ? "Image de la miniature préparée pour le TFT."
                         : "En attente d’une nouvelle image de la miniature.")
                }
            }
            Text("Applications : ouverture sur l’iPhone avec diffusion de son écran complet. Sites web et carte Double Interface : affichage dans les deux fenêtres. Une app tierce n’est pas intégrée dans une fenêtre de Double Interface.")
                .font(.caption).foregroundStyle(RivetCockpit.secondary)
            Text("Garde Double Interface au premier plan et l’iPhone déverrouillé pour l’envoi de la miniature.")
                .font(.caption).foregroundStyle(RivetCockpit.secondary)
        }
    }
}

private struct PanelUIKitHost: UIViewRepresentable {
    let view: UIView
    let canvasSize: CGSize
    var navigation: IntegratedNavigationPanel? = nil
    var topInset: CGFloat = 68
    func makeUIView(context: Context) -> ScaledPanelView {
        let host = ScaledPanelView()
        host.install(view, canvasSize: canvasSize)
        navigation?.setHUDTopInset(topInset)
        return host
    }
    func updateUIView(_ host: ScaledPanelView, context: Context) {
        host.install(view, canvasSize: canvasSize)
        navigation?.setHUDTopInset(topInset)
    }
}

private final class ScaledPanelView: UIView {
    private weak var content: UIView?
    private var canvasSize = CGSize(width: 360, height: 614)
    func install(_ view: UIView, canvasSize: CGSize) {
        if content !== view {
            content?.removeFromSuperview()
            view.removeFromSuperview()
            addSubview(view)
            content = view
        }
        self.canvasSize = canvasSize
        backgroundColor = .black
        clipsToBounds = true
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let content, bounds.width > 0, bounds.height > 0 else { return }
        content.transform = .identity
        content.bounds = CGRect(origin: .zero, size: canvasSize)
        content.center = CGPoint(x: bounds.midX, y: bounds.midY)
        content.transform = CGAffineTransform(scaleX: bounds.width / canvasSize.width,
                                             y: bounds.height / canvasSize.height)
        content.setNeedsLayout()
        content.layoutIfNeeded()
    }
}

private struct DualContentPicker: View {
    @ObservedObject var session: WebCockpitSession
    @ObservedObject var bleController: BleController
    let panel: WebPanelID
    @Environment(\.dismiss) private var dismiss
    @State private var provider = WebMapProvider.wikiloc
    @State private var address = ""
    @State private var error: String?
    @State private var showPhoneScreen = false
    @AppStorage(NativePhoneApp.selectionKey) private var selectedAppID = ""

    var body: some View {
        RideSheet(panel == session.layout.tft ? "Petite fenêtre / TFT" : "Grand écran") {
            Text("Choisir le contenu").font(.system(.title, design: .rounded).weight(.bold))
            RideCard {
                Label("Applications iPhone", systemImage: "square.grid.2x2.fill").font(.headline)
                ForEach(NativePhoneApp.allCases) { app in
                    Button {
                        selectedAppID = app.rawValue
                        showPhoneScreen = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(app.icon).resizable().scaledToFit().frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            Text(app.title).font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.bold())
                        }
                        .foregroundStyle(RivetCockpit.paper).padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dualCockpit.app." + app.rawValue)
                }
                Text("Les applications s’ouvrent en plein écran sur l’iPhone. Le TFT utilise alors la diffusion de l’écran complet.")
                    .font(.caption).foregroundStyle(RivetCockpit.secondary)
            }
            Button("Écran complet de l’iPhone", systemImage: "iphone") {
                selectedAppID = ""
                showPhoneScreen = true
            }.buttonStyle(RideButtonStyle(primary: false))
            RideCard {
                Label("Site web", systemImage: "globe").font(.headline)
                Picker("Site", selection: $provider) {
                    ForEach(WebMapProvider.allCases) { item in Text(item.title).tag(item) }
                }.pickerStyle(.segmented)
                    .onChange(of: provider) { _, value in
                        address = session.page(panel).provider == value ? session.page(panel).address : ""
                    }
                TextField("Lien de trace ou code d’intégration (facultatif)", text: $address, axis: .vertical)
                    .lineLimit(2...4).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Button("Afficher le site dans cette fenêtre") {
                    if session.setPage(WebPanelPage(provider: provider, address: address), for: panel) {
                        bleController.selectMiniature()
                        dismiss()
                    }
                    else { error = "Utilise un lien HTTPS officiel de " + provider.title + "." }
                }
                .buttonStyle(RideButtonStyle())
                .disabled(session.contents.content(panel.other) == .website)
                Text(session.contents.content(panel.other) == .website
                     ? "Le site est déjà dans l’autre fenêtre. Touche la miniature pour l’échanger."
                     : "Wikiloc : consultation des traces. Waze : carte du trafic. Ce sont leurs sites web.")
                    .font(.caption).foregroundStyle(RivetCockpit.secondary)
                if let error { Text(error).foregroundStyle(RivetCockpit.orange) }
            }
            DisclosureGroup("Carte Double Interface et GPX") {
                Button {
                    if session.setContent(.navigation, for: panel) {
                        bleController.selectMiniature()
                        dismiss()
                    }
                } label: {
                    Label("Navigation Double Interface", systemImage: "location.north.circle.fill")
                }
                .buttonStyle(RideButtonStyle(primary: false))
                .disabled(session.contents.content(panel.other) == .navigation)
                Text("Carte intégrée, destination, guidage et traces GPX.")
                    .font(.caption).foregroundStyle(RivetCockpit.secondary)
            }
            if session.contents.content(panel) != .empty {
                Button("Vider cette fenêtre", systemImage: "minus.circle") {
                    _ = session.setContent(.empty, for: panel)
                    dismiss()
                }.buttonStyle(RideButtonStyle(primary: false))
            }
            Text("Le choix fonctionne sans TFT connecté. La connexion se prépare séparément dans Connexion.")
                .font(.caption).foregroundStyle(RivetCockpit.secondary)
        }
        .onAppear { provider = session.page(panel).provider; address = session.page(panel).address }
        .sheet(isPresented: $showPhoneScreen) {
            PhoneProjectionView(bleController: bleController)
        }
    }
}
