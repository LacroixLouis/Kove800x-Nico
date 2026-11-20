import Foundation
import Combine
import UIKit

/// Reports local observations. No acknowledgement of decoding exists in the
/// TFT protocol here; encoding/sending is never presented as proof of display.
final class ProjectionDiagnostics: ObservableObject {
    static let shared = ProjectionDiagnostics()
    @Published private(set) var mode: ProjectionMode = .disconnected
    @Published private(set) var encodedFrames = 0
    @Published private(set) var sentVideoBytes = 0
    @Published private(set) var lastFix: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var events: [String] = []
    @Published private(set) var backgroundLocationEnabled = false
    @Published private(set) var bluetoothConnected = false
    @Published private(set) var controlConnected = false
    @Published private(set) var videoConnected = false
    @Published private(set) var lastControlPacketAt: Date?
    @Published private(set) var lastVideoSendCompletedAt: Date?

    func recordControlPacket() {
        DispatchQueue.main.async { self.lastControlPacketAt = Date() }
    }

    func setBackgroundLocation(_ enabled: Bool) {
        DispatchQueue.main.async { self.backgroundLocationEnabled = enabled }
    }

    func setTransports(bluetooth: Bool, control: Bool, video: Bool) {
        DispatchQueue.main.async { [self] in
            guard bluetoothConnected != bluetooth || controlConnected != control || videoConnected != video else { return }
            bluetoothConnected = bluetooth
            controlConnected = control
            videoConnected = video
            addEvent("BLE=\(bluetooth) contrôle=\(control) vidéo=\(video)")
        }
    }

    func setMode(_ value: ProjectionMode) {
        DispatchQueue.main.async { [self] in
            guard mode != value else { return }
            mode = value
            addEvent(value.rawValue)
        }
    }

    func recordFix(_ date: Date) { DispatchQueue.main.async { self.lastFix = date } }
    func recordEncodedFrame() { DispatchQueue.main.async { self.encodedFrames += 1 } }
    func recordSentBytes(_ count: Int) {
        DispatchQueue.main.async {
            self.sentVideoBytes += count
            self.lastVideoSendCompletedAt = Date()
        }
    }
    func recordError(_ message: String) {
        DispatchQueue.main.async { [self] in
            guard lastError != message else { return }
            lastError = message
            addEvent(message)
        }
    }

    private func addEvent(_ text: String) {
        events.append(ISO8601DateFormatter().string(from: Date()) + " " + text)
        if events.count > 60 { events.removeFirst(events.count - 60) }
    }

    /// Called from the UI. Deliberately excludes coordinates, destinations,
    /// Wi-Fi identifiers, passwords and Apple signing credentials.
    func exportReport() throws -> URL {
        dispatchPrecondition(condition: .onQueue(.main))
        let formatter = ISO8601DateFormatter()
        let report: [String: Any] = [
            "variant": "Double Interface · connexion v5",
            "created_at": formatter.string(from: Date()),
            "ios": UIDevice.current.systemVersion,
            "mode": mode.rawValue,
            "bluetooth_connected": bluetoothConnected,
            "tft_control_connected": controlConnected,
            "tft_video_connected": videoConnected,
            "background_location_enabled": backgroundLocationEnabled,
            "last_control_packet_at": lastControlPacketAt.map { formatter.string(from: $0) } ?? "none",
            "last_video_send_completed_at": lastVideoSendCompletedAt.map { formatter.string(from: $0) } ?? "none",
            "independent_builtin_output": CockpitSettings.isEnabled,
            "tft_builtin_page": CockpitSettings.tftPage.rawValue,
            "navigation_frames_encoded": encodedFrames,
            "video_bytes_send_completed": sentVideoBytes,
            "last_gps_at": lastFix.map { formatter.string(from: $0) } ?? "none",
            "last_error": lastError ?? "none",
            "events": events,
            "tft_display_confirmed": false
        ]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Double-Interface-diagnostic.json")
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: url, options: .atomic)
        return url
    }
}
