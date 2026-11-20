import Foundation
import Combine
import UIKit
import WebKit
import CoreLocation

extension Notification.Name {
    static let webPanelSourceChanged = Notification.Name("DoubleInterfaceWebPanelSourceChanged")
}

/// Two independent WKWebViews; moving/exchanging panels never reloads them.
/// This is an experiment with public web maps, not an embedded native app.
final class WebCockpitSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = WebCockpitSession()
    private static let storageKey = "doubleInterface.webCockpitExperiment.v1"
    private struct Saved: Codable {
        var layout: WebPanelLayout
        var first: WebPanelPage
        var second: WebPanelPage
    }

    @Published private(set) var layout = WebPanelLayout()
    @Published private(set) var pages: [WebPanelID: WebPanelPage] = [
        .first: WebPanelPage(provider: .wikiloc), .second: WebPanelPage(provider: .waze)
    ]
    @Published private(set) var messages: [WebPanelID: String] = [:]
    @Published private(set) var lastSnapshot: Date?
    @Published private(set) var snapshotError: String?
    @Published private(set) var waitingForLocation: Set<WebPanelID> = []
    @Published private(set) var locationStatus = "Recherche de ta position…"
    @Published private var currentLocation: CLLocation?
    @Published private var locationAuthorization: CLAuthorizationStatus = .notDetermined
    private var views: [WebPanelID: WKWebView] = [:]
    private var locationSubscription: AnyCancellable?
    private var nearbyRequests: Set<WebPanelID> = []

    private override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            layout = saved.layout
            layout.moveMini(x: saved.layout.miniX, y: saved.layout.miniY)
            pages = [.first: saved.first, .second: saved.second]
        }
        let manager = LocationAndNavigationManager.shared
        locationSubscription = manager.$userLocation.combineLatest(manager.$authorizationStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location, authorization in
                guard let self else { return }
                self.currentLocation = location
                self.locationAuthorization = authorization
                self.updateLocationStatus()
                if self.hasFreshLocation || self.locationNeedsSettings {
                    for id in Array(self.waitingForLocation) {
                        if self.nearbyRequests.contains(id) { self.openNearbyMap(id) }
                        else { self.load(id) }
                    }
                }
            }
    }

    var locationNeedsSettings: Bool {
        locationAuthorization == .denied || locationAuthorization == .restricted
    }

    private var freshLocation: CLLocation? {
        guard !locationNeedsSettings, let location = currentLocation,
              CLLocationCoordinate2DIsValid(location.coordinate),
              ProjectionPolicy.isFresh(timestamp: location.timestamp,
                                       accuracy: location.horizontalAccuracy, now: Date()) else { return nil }
        return location
    }

    var hasFreshLocation: Bool { freshLocation != nil }

    func beginLocation() {
        LocationAndNavigationManager.shared.requestWebMapLocation()
        updateLocationStatus()
    }

    /// Explicitly opens the provider's map around the current fix.
    /// Normal fixes never reload an already open route or a manually moved map.
    func showNearbyMap() {
        let id = layout.phone
        nearbyRequests.insert(id)
        LocationAndNavigationManager.shared.requestWebMapLocation()
        openNearbyMap(id)
    }

    func continueWithoutLocation(_ id: WebPanelID) {
        nearbyRequests.remove(id)
        waitingForLocation.remove(id)
        guard let view = views[id], view.url == nil,
              let url = page(id).resolvedURL() else { return }
        messages[id] = "Vue générale · ta position n’est pas encore disponible"
        view.load(URLRequest(url: url))
    }

    private func openNearbyMap(_ id: WebPanelID) {
        guard !locationNeedsSettings else {
            nearbyRequests.remove(id)
            waitingForLocation.remove(id)
            updateLocationStatus()
            return
        }
        guard let location = freshLocation else {
            waitingForLocation.insert(id)
            updateLocationStatus()
            return
        }
        guard let url = WebPanelPage(provider: page(id).provider).resolvedURL(
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude) else { return }
        nearbyRequests.remove(id)
        waitingForLocation.remove(id)
        messages[id] = "Chargement de la carte autour de toi…"
        webView(id).load(URLRequest(url: url))
    }

    private func updateLocationStatus() {
        if locationNeedsSettings {
            locationStatus = "Localisation refusée. Autorise Double Interface dans les réglages de l’iPhone."
        } else if let location = freshLocation {
            locationStatus = "Position reçue · précision ±\(Int(min(1_000_000, location.horizontalAccuracy.rounded()))) m"
        } else {
            locationStatus = "Recherche de ta position…"
        }
    }

    var canvasSize: CGSize {
        let preset = KoveScreenPreset.current
        let height = max(160, preset.height - KoveScreenPreset.topPadding - KoveScreenPreset.bottomPadding)
        return CGSize(width: 360, height: 360 * CGFloat(height) / CGFloat(max(1, preset.width)))
    }

    func page(_ id: WebPanelID) -> WebPanelPage {
        pages[id] ?? WebPanelPage(provider: id == .first ? .wikiloc : .waze)
    }

    func webView(_ id: WebPanelID) -> WKWebView {
        dispatchPrecondition(condition: .onQueue(.main))
        if let view = views[id] { return view }
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        let view = WKWebView(frame: CGRect(origin: .zero, size: canvasSize), configuration: configuration)
        view.navigationDelegate = self
        view.uiDelegate = self
        view.isOpaque = false
        view.backgroundColor = UIColor(red: 16 / 255, green: 26 / 255, blue: 24 / 255, alpha: 1)
        view.scrollView.backgroundColor = view.backgroundColor
        view.allowsBackForwardNavigationGestures = true
        views[id] = view
        // Start after mounting: don't publish state changes inside a SwiftUI update.
        DispatchQueue.main.async { [weak self] in self?.load(id) }
        return view
    }

    func exchange() {
        dispatchPrecondition(condition: .onQueue(.main))
        layout.exchange()
        lastSnapshot = nil
        snapshotError = nil
        save()
        NotificationCenter.default.post(name: .webPanelSourceChanged, object: nil)
    }

    func moveMini(x: Double, y: Double) {
        layout.moveMini(x: x, y: y)
        save()
    }

    @discardableResult
    func setPage(_ page: WebPanelPage, for id: WebPanelID) -> Bool {
        guard page.resolvedURL() != nil else { return false }
        pages[id] = page
        nearbyRequests.remove(id)
        waitingForLocation.remove(id)
        save()
        load(id)
        if id == layout.tft {
            lastSnapshot = nil
            NotificationCenter.default.post(name: .webPanelSourceChanged, object: nil)
        }
        return true
    }

    func reload(_ id: WebPanelID) {
        if waitingForLocation.contains(id) || views[id]?.url == nil {
            beginLocation()
            load(id)
        } else { views[id]?.reload() }
    }

    func goBack(_ id: WebPanelID) {
        guard let view = views[id], view.canGoBack else { return }
        view.goBack()
    }

    func recordSnapshot(error: String? = nil) {
        snapshotError = error
        if error == nil { lastSnapshot = Date() }
    }

    private func save() {
        let saved = Saved(layout: layout, first: page(.first), second: page(.second))
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func load(_ id: WebPanelID) {
        guard let view = views[id] else { return }
        let location = freshLocation
        let defaultMap = page(id).address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // Initial default maps wait for a real fix instead of opening elsewhere
        // and never being recentered. Pasted trails remain available without GPS.
        if defaultMap && location == nil && !locationNeedsSettings {
            waitingForLocation.insert(id)
            messages[id] = "En attente de ta position pour ouvrir la carte…"
            return
        }
        waitingForLocation.remove(id)
        guard let url = page(id).resolvedURL(latitude: location?.coordinate.latitude,
                                            longitude: location?.coordinate.longitude) else {
            messages[id] = "Adresse de carte invalide."
            return
        }
        messages[id] = "Chargement de la carte web…"
        view.load(URLRequest(url: url))
    }

    // Public on iOS 27. The explicit selector also lets older SDKs compile this
    // delegate without referencing a new symbol; older systems keep WebKit's prompt.
    @available(iOS 27.0, *)
    @MainActor
    @objc(webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void) {
        guard let id = id(for: webView) else { decisionHandler(.deny); return }
        var components = URLComponents()
        components.scheme = origin.protocol
        components.host = origin.host
        if origin.port != 0 { components.port = origin.port }
        guard let url = components.url, WebPanelPage.allows(url, provider: page(id).provider),
              !locationNeedsSettings else { decisionHandler(.deny); return }
        // Keep the site's location consent. Never grant it silently or substitute
        // a fake navigator.geolocation implementation.
        decisionHandler(.prompt)
    }

    private func id(for view: WKWebView) -> WebPanelID? {
        views.first(where: { $0.value === view })?.key
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if url.absoluteString == "about:blank" { decisionHandler(.allow); return }
        // No custom-scheme launch, UIApplication.open, or private WebKit API.
        // Subresources are managed by WebKit; top-level pages stay with their provider.
        guard let id = id(for: webView) else { decisionHandler(.cancel); return }
        if action.targetFrame?.isMainFrame == false, url.scheme == "https" {
            decisionHandler(.allow)
            return
        }
        guard WebPanelPage.allows(url, provider: page(id).provider) else {
            messages[id] = "Ce lien quitte la carte web. L’ouverture de l’app iPhone est séparée de cet essai."
            decisionHandler(.cancel)
            return
        }
        if action.targetFrame == nil {
            webView.load(action.request)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let id = id(for: webView) else { return }
        messages[id] = "Carte web chargée"
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        report(error, from: webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        report(error, from: webView)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard let id = id(for: webView) else { return }
        messages[id] = "La carte web s’est arrêtée. Utilise Actualiser."
    }

    private func report(_ error: Error, from view: WKWebView) {
        guard (error as NSError).code != NSURLErrorCancelled, let id = id(for: view) else { return }
        messages[id] = "Carte web indisponible : " + error.localizedDescription
    }
}
