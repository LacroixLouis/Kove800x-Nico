import SwiftUI
import WebKit

/// Prototype: two real web sessions, with the small session always sent to TFT.
struct WebCockpitView: View {
    @ObservedObject var bleController: BleController
    @StateObject private var session = WebCockpitSession.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragOffset = CGSize.zero
    @State private var showPages = false
    @State private var showInfo = false
    @State private var previousIdleTimer = false

    var body: some View {
        GeometryReader { safeGeometry in
            ZStack(alignment: .topTrailing) {
                canvas(insets: safeGeometry.safeAreaInsets)
                    .ignoresSafeArea(.container)
                HStack(spacing: 8) {
                    Button {
                        if session.locationNeedsSettings {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } else { session.showNearbyMap() }
                    } label: {
                        Image(systemName: session.locationNeedsSettings ? "location.slash" : "location.fill")
                            .foregroundStyle(session.hasFreshLocation ? RivetCockpit.lime : RivetCockpit.orange)
                            .frame(width: 44, height: 44)
                            .background(RivetCockpit.asphalt.opacity(0.94), in: Circle())
                    }
                    .accessibilityLabel(session.locationNeedsSettings ? "Autoriser la localisation" : "Carte autour de moi")
                    .accessibilityHint(session.locationStatus)
                    .accessibilityIdentifier("webCockpit.locate")
                    toolbar
                }
                .buttonStyle(.plain)
                .font(.title3.weight(.semibold))
                .padding(12)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                .zIndex(2)
            }
        }
        .background(RivetCockpit.asphalt).foregroundStyle(RivetCockpit.paper)
        .preferredColorScheme(.dark).tint(RivetCockpit.lime)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
            session.beginLocation()
            bleController.beginWebPanelProjection()
        }
        .onDisappear {
            bleController.endWebPanelProjection()
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimer
        }
        .sheet(isPresented: $showPages) { WebCockpitPagesView(session: session) }
        .sheet(isPresented: $showInfo) {
            RideSheet("Les deux écrans") {
                Label(bleController.isStreaming ? "TFT relié" : "En attente du TFT",
                      systemImage: bleController.isStreaming ? "link" : "wifi")
                Text(session.locationStatus).font(.headline)
                Text("Touche la miniature pour échanger les écrans. Glisse-la pour la déplacer.")
                snapshotStatus
                Text("Cartes web uniquement. Le guidage des apps iPhone n’est pas intégré à cet essai.")
                    .font(.caption).foregroundStyle(RivetCockpit.secondary)
            }
        }
    }

    private func canvas(insets: EdgeInsets) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let availableWidth = max(1, size.width - insets.leading - insets.trailing - 16)
            let availableHeight = max(1, size.height - insets.top - insets.bottom - 16)
            let source = session.canvasSize
            let targetWidth = min(availableWidth, min(142, max(96, availableWidth * 0.33)))
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
                        .overlay {
                            if miniature { miniControls(area: size, mini: miniSize, insets: insets) }
                        }
                        .position(miniature ? miniCenter(area: size, mini: miniSize, insets: insets, offset: dragOffset)
                                  : CGPoint(x: size.width / 2, y: size.height / 2))
                        .zIndex(miniature ? 1 : 0)
                }
            }
            .coordinateSpace(name: "webCockpitCanvas")
            .clipped()
            .accessibilityIdentifier("webCockpit.canvas")
        }
    }

    private var toolbar: some View {
        Menu {
            Text(session.page(session.layout.phone).provider.title + " · web")
            Button("Page précédente", systemImage: "chevron.backward") { session.goBack(session.layout.phone) }
            Button("Actualiser", systemImage: "arrow.clockwise") { session.reload(session.layout.phone) }
            Button("Choisir les cartes web", systemImage: "gearshape") { showPages = true }
            Button("État et aide", systemImage: "info.circle") { showInfo = true }
            Divider()
            Button("Fermer les deux écrans", systemImage: "xmark") { dismiss() }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 44, height: 44)
                .background(RivetCockpit.asphalt.opacity(0.94), in: Circle())
        }
        .accessibilityLabel("Menu des deux écrans")
        .accessibilityIdentifier("webCockpit.menu")
    }

    private func panel(_ id: WebPanelID, miniature: Bool, viewport: CGSize) -> some View {
        WebPanelHost(webView: session.webView(id), canvasSize: viewport)
            .allowsHitTesting(!miniature)
            .overlay {
                if session.waitingForLocation.contains(id) {
                    VStack(spacing: 10) {
                        ProgressView().tint(RivetCockpit.lime)
                        Text("Recherche de ta position…")
                            .font(miniature ? .caption2 : .callout)
                            .multilineTextAlignment(.center)
                        if !miniature {
                            Button("Afficher la carte sans position") { session.continueWithoutLocation(id) }
                                .font(.callout).tint(RivetCockpit.lime)
                        }
                    }
                    .padding()
                    .allowsHitTesting(!miniature)
                }
            }
            .overlay(alignment: .top) {
                if miniature {
                    Text("TFT · " + session.page(id).provider.title)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(RivetCockpit.asphalt)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .frame(maxWidth: .infinity).background(RivetCockpit.lime)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityIdentifier(miniature ? "webCockpit.miniature" : "webCockpit.main")
    }

    private func miniControls(area: CGSize, mini: CGSize, insets: EdgeInsets) -> some View {
        Color.clear.contentShape(Rectangle())
            .onTapGesture {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { session.exchange() }
            }
            .highPriorityGesture(DragGesture(minimumDistance: 10, coordinateSpace: .named("webCockpitCanvas"))
                .updating($dragOffset) { value, state, _ in state = value.translation }
                .onEnded { value in
                    let center = miniCenter(area: area, mini: mini, insets: insets, offset: value.translation)
                    let travel = miniTravel(area: area, mini: mini, insets: insets)
                    session.moveMini(x: Double((center.x - travel.minX) / max(1, travel.width)),
                                     y: Double((center.y - travel.minY) / max(1, travel.height)))
                })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Miniature TFT, " + session.page(session.layout.tft).provider.title)
            .accessibilityHint("Toucher pour échanger les deux écrans. Glisser pour déplacer la miniature.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { session.exchange() }
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

    private var snapshotStatus: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let fresh = session.lastSnapshot.map { context.date.timeIntervalSince($0) < 4 } ?? false
            VStack(alignment: .leading, spacing: 3) {
                Text(session.messages[session.layout.phone] ?? "Chargement…")
                    .font(.caption2).foregroundStyle(RivetCockpit.secondary)
                if let error = session.snapshotError {
                    Text("Image TFT : " + error).foregroundStyle(RivetCockpit.orange)
                } else if bleController.isStreaming {
                    Text(fresh ? "Miniature préparée pour le TFT · " + session.page(session.layout.tft).provider.title
                         : "En attente d’une nouvelle image de la miniature")
                        .foregroundStyle(fresh ? RivetCockpit.lime : RivetCockpit.orange)
                }
            }
            .font(.caption2).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WebPanelHost: UIViewRepresentable {
    let webView: WKWebView
    let canvasSize: CGSize

    func makeUIView(context: Context) -> ScaledWebPanelView {
        let host = ScaledWebPanelView()
        host.install(webView, canvasSize: canvasSize)
        return host
    }

    func updateUIView(_ host: ScaledWebPanelView, context: Context) {
        host.install(webView, canvasSize: canvasSize)
    }
}

private final class ScaledWebPanelView: UIView {
    private weak var webView: WKWebView?
    private var canvasSize = CGSize(width: 360, height: 614)

    func install(_ view: WKWebView, canvasSize: CGSize) {
        if webView !== view {
            webView?.removeFromSuperview()
            view.removeFromSuperview()
            addSubview(view)
            webView = view
        }
        self.canvasSize = canvasSize
        backgroundColor = .black
        clipsToBounds = true
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let webView, bounds.width > 0, bounds.height > 0 else { return }
        // The phone uses its full viewport, avoiding portrait letterboxing.
        // The miniature keeps the TFT's aspect ratio for its full snapshots.
        webView.transform = .identity
        webView.bounds = CGRect(origin: .zero, size: canvasSize)
        webView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        let scale = min(bounds.width / canvasSize.width, bounds.height / canvasSize.height)
        webView.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}

private struct WebCockpitPagesView: View {
    @ObservedObject var session: WebCockpitSession
    @State private var drafts: [WebPanelID: WebPanelPage] = [:]
    @State private var error: String?

    var body: some View {
        RideSheet("Les deux cartes web") {
            Text("La petite fenêtre est envoyée automatiquement au TFT.")
                .font(.headline)
            ForEach(WebPanelID.allCases) { id in
                RideCard {
                    Text(id == session.layout.tft ? "Dans la miniature · TFT" : "Dans le grand écran · iPhone")
                        .font(.headline)
                    Picker("Carte web", selection: Binding(get: { draft(id).provider }, set: { provider in
                        drafts[id] = WebPanelPage(provider: provider)
                    })) {
                        ForEach(WebMapProvider.allCases) { provider in Text(provider.title).tag(provider) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Lien de carte ou code d’intégration (facultatif)", text: Binding(
                        get: { draft(id).address }, set: { address in
                            var page = draft(id)
                            page.address = address
                            drafts[id] = page
                        }), axis: .vertical)
                        .lineLimit(2...4).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    Button("Charger cette carte") {
                        if !session.setPage(draft(id), for: id) {
                            error = "Utilise un lien HTTPS de " + draft(id).provider.title + " ou son code d’intégration officiel."
                        }
                    }
                    .buttonStyle(RideButtonStyle())
                    Button("Actualiser cette fenêtre") { session.reload(id) }
                        .buttonStyle(RideButtonStyle(primary: false))
                    Text(session.messages[id] ?? "")
                        .font(.caption).foregroundStyle(RivetCockpit.secondary)
                }
            }
            Text("Waze : carte du trafic en ligne. Wikiloc : site et cartes de traces. Une connexion Internet est nécessaire. Les fonctions des apps iPhone restent séparées.")
                .font(.caption).foregroundStyle(RivetCockpit.secondary)
            Text("Sur Wikiloc, ouvre une trace ou colle son code « Intégrer la carte » pour essayer sa carte seule.")
                .font(.caption).foregroundStyle(RivetCockpit.secondary)
        }
        .onAppear { drafts = session.pages }
        .alert("Carte web", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private func draft(_ id: WebPanelID) -> WebPanelPage { drafts[id] ?? session.page(id) }
}
