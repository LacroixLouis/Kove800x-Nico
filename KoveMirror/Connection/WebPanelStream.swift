import UIKit
import CoreMedia
import CoreVideo

/// Snapshots ONLY the miniature's native map or website. The main map, keyboard, sheets,
/// miniature position and application chrome are never sent by this producer.
final class WebPanelStream: H264EncoderDelegate {
    private let server: TcpServerManager
    private let encoder = H264Encoder()
    private var timer: Timer?
    private var generation = 0
    private var active = false
    private var snapshotPending = false
    private var pendingSince = 0.0
    private var outputSize = CGSize(width: 600, height: 1024)

    init(server: TcpServerManager) {
        self.server = server
        encoder.delegate = self
        encoder.onError = { status in
            ProjectionDiagnostics.shared.recordError("Double Interface : encodeur TFT \(status)")
            DispatchQueue.main.async {
                WebCockpitSession.shared.recordSnapshot(error: "Erreur de préparation de l’image TFT (\(status)).")
            }
        }
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !active else { return }
        let preset = KoveScreenPreset.current
        outputSize = CGSize(width: preset.width, height: preset.height)
        guard encoder.start(width: Int32(preset.width), height: Int32(preset.height), fps: 2) else {
            WebCockpitSession.shared.recordSnapshot(error: "L’encodeur du TFT n’a pas démarré.")
            return
        }
        active = true
        generation += 1
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.capture() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        capture()
    }

    func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        active = false
        generation += 1
        snapshotPending = false
        WebCockpitSession.shared.cancelSnapshot()
        timer?.invalidate()
        timer = nil
        encoder.stop()
    }

    private func capture() {
        guard active, UIApplication.shared.applicationState == .active else { return }
        let now = ProcessInfo.processInfo.systemUptime
        // A stalled map or website callback must not lock the capture loop.
        if snapshotPending {
            if now - pendingSince > 8 {
                WebCockpitSession.shared.recordSnapshot(error: "La miniature ne fournit plus d’image. Actualise-la.")
                generation += 1
                snapshotPending = false
            }
            if snapshotPending { return }
        }
        let session = WebCockpitSession.shared
        let id = session.layout.tft
        let revision = session.sourceRevision
        snapshotPending = true
        pendingSince = now
        let token = generation
        session.snapshotTFT(width: outputSize.width) { [weak self] image, error in
            DispatchQueue.main.async {
                guard let self, self.active, self.generation == token else { return }
                self.snapshotPending = false
                guard session.layout.tft == id, session.sourceRevision == revision else { return }
                guard let image, let buffer = self.pixelBuffer(image) else {
                    session.recordSnapshot(error: error?.localizedDescription ?? "La miniature ne fournit pas d’image.")
                    return
                }
                let pts = CMTime(value: Int64(ProcessInfo.processInfo.systemUptime * 1000), timescale: 1000)
                if self.encoder.encode(pixelBuffer: buffer, pts: pts) { session.recordSnapshot() }
            }
        }
    }

    private func pixelBuffer(_ image: UIImage) -> CVPixelBuffer? {
        let width = Int(outputSize.width), height = Int(outputSize.height)
        var buffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                                  attrs, &buffer) == kCVReturnSuccess, let buffer else { return nil }
        guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: outputSize))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        let top = CGFloat(KoveScreenPreset.topPadding)
        let available = max(10, CGFloat(height) - top - CGFloat(KoveScreenPreset.bottomPadding))
        let scale = min(CGFloat(width) / image.size.width, available / image.size.height)
        let rect = CGRect(x: (CGFloat(width) - image.size.width * scale) / 2,
                          y: top + (available - image.size.height * scale) / 2,
                          width: image.size.width * scale, height: image.size.height * scale)
        UIGraphicsPushContext(context)
        image.draw(in: rect)
        UIGraphicsPopContext()
        return buffer
    }

    func encoderDidOutputNALUnit(data: Data) {
        ProjectionDiagnostics.shared.recordEncodedFrame()
        server.streamVideoFrame(data: data, source: .screen)
    }
}
