//
//  KoveMirrorApp.swift
//  KoveMirror
//
//  Created by Matti Mustonen on 21.7.2026.
//

import SwiftUI

@main
struct KoveMirrorApp: App {
    @AppStorage("enableProximitySensor") private var enableProximitySensor = false
    @AppStorage(RivetLanguage.preferenceKey) private var interfaceLanguage = RivetLanguage.system.rawValue
    
    init() {
        // Disable system UIDevice proximity monitoring so iOS never forces screen off
        UIDevice.current.isProximityMonitoringEnabled = false
    }
    
    var body: some Scene {
        WindowGroup {
            ConnectionStatusView()
                .preferredColorScheme(.dark)
                .tint(RivetCockpit.lime)
                .environment(\.locale, Locale(identifier: RivetLanguage.saved(interfaceLanguage).localeIdentifier))
                .onAppear {
                    UIDevice.current.isProximityMonitoringEnabled = false
                    CameraProximityManager.shared.setup()
                }
                .onOpenURL { url in
                    // Do not log incoming URLs; they may contain connection parameters.
                    let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
                    let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
                    if schemes.contains(url.scheme ?? "") {
                        if url.host == "start" || url.host == "mirror" {
                            BleController.shared?.startMirroring()
                        } else if url.host == "shortcut-error" {
                            let message = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                                .first(where: { $0.name == "errorMessage" })?.value
                            let detail = message.map { String($0.prefix(350)) }
                                ?? "Vérifie le nom du raccourci iOS et son action « Ouvrir l’app »."
                            NotificationCenter.default.post(name: .rivetShortcutFailed, object: "L’ouverture par Raccourcis a échoué. " + detail)
                        }
                    }
                }
        }
    }
}
