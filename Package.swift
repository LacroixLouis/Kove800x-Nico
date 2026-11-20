// swift-tools-version: 5.9
import PackageDescription

// Portable connection tests. The iPhone app itself is built with the Xcode project.
let package = Package(
    name: "NicoMirrorConnection",
    products: [.library(name: "NicoMirrorConnection", targets: ["NicoMirrorConnection"])],
    targets: [
        .target(
            name: "NicoMirrorConnection",
            path: "KoveMirror/SetupViews",
            exclude: ["QRScannerSheet.swift", "QRCodeScannerView.swift", "ProximityTransparentOverlay.swift", "SettingsView.swift"],
            sources: ["KoveScreenPreset.swift", "MotorcycleWiFiCredentials.swift", "NewlinePacketBuffer.swift", "ProjectionPolicy.swift", "AnnexBResynchronizer.swift", "GPXTrack.swift", "NavigationAppChoice.swift", "TFTConnectionPolicy.swift", "CockpitPage.swift", "DashboardLayout.swift", "MotorcycleMaintenance.swift", "CockpitWeather.swift", "RivetLanguage.swift", "WebPanelLayout.swift"]
        ),
        .testTarget(name: "NicoMirrorConnectionTests", dependencies: ["NicoMirrorConnection"], path: "Tests/Connection")
    ]
)
