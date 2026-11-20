import Foundation
import Combine
import NetworkExtension
import Security
import UIKit

/// Saves the motorcycle network in the system Wi-Fi configuration. The secret
/// used for an explicit retry is kept in this app's device-only Keychain.
final class MotorcycleWiFiManager: ObservableObject {
    static let shared = MotorcycleWiFiManager()
    @Published private(set) var isConnecting = false
    @Published private(set) var message = "Scanne une fois le QR Wi-Fi du compteur."
    var hasSavedNetwork: Bool {
        !(UserDefaults.standard.string(forKey: "pairedMotorcycleSSID") ?? "").isEmpty
    }
    private struct SavedNetwork: Codable {
        let ssid: String
        let password: String?
    }

    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "NicoMirror") + ".motorcycle-wifi",
         kSecAttrAccount as String: "tft-network"]
    }

    private func savedNetwork() -> SavedNetwork? {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(SavedNetwork.self, from: data)
    }

    private func save(_ credentials: MotorcycleWiFiCredentials) throws {
        let data = try JSONEncoder().encode(SavedNetwork(ssid: credentials.ssid, password: credentials.password))
        let query = keychainQuery
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Impossible d’enregistrer le Wi-Fi de la moto."])
        }
        UserDefaults.standard.set(credentials.ssid, forKey: "pairedMotorcycleSSID")
    }

    func configure(_ credentials: MotorcycleWiFiCredentials) {
        dispatchPrecondition(condition: .onQueue(.main))
        do {
            try save(credentials)
            apply(credentials)
        } catch { message = error.localizedDescription }
    }

    /// iOS autojoins persistent networks. Applying their configuration again
    /// can present consent again, so automatic resumption never calls apply.
    func resumeSavedNetwork() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isConnecting, hasSavedNetwork else { return }
        message = "Wi-Fi enregistré. La liaison au compteur sera détectée automatiquement."
    }

    /// Configuration changes are reserved for an explicit user action.
    func retrySavedNetwork() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isConnecting, let saved = savedNetwork() else { return }
        guard UIApplication.shared.applicationState == .active else {
            message = "Ouvre l’application pour modifier la connexion Wi-Fi."
            return
        }
        apply(MotorcycleWiFiCredentials(ssid: saved.ssid, password: saved.password))
    }

    private func apply(_ credentials: MotorcycleWiFiCredentials) {
        guard !isConnecting else { return }
        guard UIApplication.shared.applicationState == .active else {
            message = "Ouvre l’application pour autoriser la première connexion Wi-Fi."
            return
        }
        let configuration: NEHotspotConfiguration
        if let password = credentials.password {
            configuration = NEHotspotConfiguration(ssid: credentials.ssid, passphrase: password, isWEP: false)
        } else {
            configuration = NEHotspotConfiguration(ssid: credentials.ssid)
        }
        // A temporary joinOnce network is removed when the display sleeps.
        configuration.joinOnce = false
        isConnecting = true
        message = "Connexion au Wi-Fi du compteur…"
        NEHotspotConfigurationManager.shared.apply(configuration) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isConnecting = false
                let nsError = error as NSError?
                let alreadyAssociated = nsError?.domain == NEHotspotConfigurationErrorDomain
                    && nsError?.code == NEHotspotConfigurationError.alreadyAssociated.rawValue
                if error == nil || alreadyAssociated {
                    self.message = "Wi-Fi enregistré. Vérifie la liaison TFT ci-dessous."
                } else if nsError?.domain == NEHotspotConfigurationErrorDomain
                            && nsError?.code == NEHotspotConfigurationError.userDenied.rawValue {
                    self.message = "Connexion refusée. Touche Réessayer lorsque tu veux l’autoriser."
                } else {
                    self.message = "Connexion automatique indisponible pour cette installation. Rejoins le Wi-Fi du compteur dans Réglages → Wi-Fi."
                    ProjectionDiagnostics.shared.recordError("Configuration Wi-Fi indisponible (code " + String(nsError?.code ?? -1) + ").")
                }
            }
        }
    }
}
