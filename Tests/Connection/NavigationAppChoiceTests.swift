import Foundation
import XCTest
@testable import NicoMirrorConnection

final class NavigationAppChoiceTests: XCTestCase {
    func testMenuChoicesRemainStableAcrossStorageRoundTrip() {
        var value = NavigationAppChoice.defaultShortcuts
        value = NavigationAppChoice.setting(.waze, enabled: false, in: value)
        value = NavigationAppChoice.setting(.plans, enabled: false, in: value)
        XCTAssertEqual(NavigationAppChoice.shortcuts(in: value), [.osmand, .wikiloc, .dmdhub])
        value = NavigationAppChoice.setting(.waze, enabled: true, in: value)
        XCTAssertEqual(NavigationAppChoice.shortcuts(in: value), [.osmand, .waze, .wikiloc, .dmdhub])
        XCTAssertEqual(NavigationAppChoice.shortcuts(in: "plans,plans,unknown,waze"), [.waze, .plans])
        XCTAssertEqual(NavigationAppChoice.shortcuts(in: ""), [])
        XCTAssertEqual(NavigationAppChoice.saved("removed-app"), .osmand)
    }

    func testExternalAppsRequireBothVideoAndBroadcastBeforeOpening() {
        for video in [false, true] {
            for broadcast in [false, true] {
                for opening in [false, true] {
                    let result = ExternalProjectionAvailability.evaluate(videoConnected: video,
                        broadcastConnected: broadcast, openingApp: opening)
                    XCTAssertEqual(result.canOpenApp, video && broadcast && !opening)
                }
            }
        }
    }

    func testPhoneAppWithRivetTFTRequiresVideoButDoesNotRequireScreenBroadcast() {
        for video in [false, true] {
            for broadcast in [false, true] {
                for opening in [false, true] {
                    let result = ExternalProjectionAvailability.evaluate(videoConnected: video,
                        broadcastConnected: broadcast, openingApp: opening, requiresBroadcast: false)
                    XCTAssertEqual(result.canOpenApp, video && !opening)
                }
            }
        }
    }

    func testWikilocUsesAnAppOnlyUniversalLinkInsteadOfOpeningTheWebsite() {
        XCTAssertTrue(NavigationAppChoice.wikiloc.universalLinkOnly)
        XCTAssertEqual(NavigationAppChoice.wikiloc.launchURL?.host, "www.wikiloc.com")
        XCTAssertEqual(NavigationAppChoice.wikiloc.launchURL?.path, "/openApp")
        XCTAssertEqual(NavigationAppChoice.osmand.launchURL?.scheme, "osmandmaps")
        XCTAssertEqual(NavigationAppChoice.waze.launchURL?.scheme, "waze")
        XCTAssertFalse(NavigationAppChoice.osmand.universalLinkOnly)
    }

    func testCustomShortcutRoundTripAndDisabledVisibility() throws {
        let item = try XCTUnwrap(UserNavigationShortcut(title: "Mon GPS", shortcutName: "Ouvrir mon GPS"))
        var disabled = item
        disabled.enabled = false
        XCTAssertEqual(UserNavigationShortcut.load(UserNavigationShortcut.encode([disabled])), [disabled])
        XCTAssertEqual(UserNavigationShortcut.load(UserNavigationShortcut.encode([item, item])).count, 1)
        XCTAssertEqual(UserNavigationShortcut.load("invalid-json"), [])
        XCTAssertNil(UserNavigationShortcut(title: "  ", shortcutName: "GPS"))
        XCTAssertNil(UserNavigationShortcut(title: "GPS", shortcutName: "x\ny"))
    }

    func testNamedAppNeedsNoIOSShortcutAndSurvivesReload() throws {
        let app = try XCTUnwrap(UserNavigationShortcut(title: "Mon GPS"))
        let saved = try XCTUnwrap(UserNavigationShortcut.load(UserNavigationShortcut.encode([app])).first)
        let target = ProjectionShortcutTarget.custom(saved)
        XCTAssertTrue(target.requiresManualOpen)
        XCTAssertNil(target.iOSShortcutName)
        XCTAssertNil(target.launchURL(errorCallback: nil))
        XCTAssertEqual(saved.title, "Mon GPS")
    }

    func testDMDDoesNotLaunchAnUnconfiguredShortcut() {
        let target = ProjectionShortcutTarget.builtIn(.dmdhub)
        XCTAssertTrue(target.requiresManualOpen)
        XCTAssertNil(target.iOSShortcutName)
        XCTAssertNil(target.launchURL(errorCallback: nil))
    }

    func testShortcutNamesAndErrorCallbacksAreEncodedAsDataNotExtraParameters() throws {
        let name = "Mon GPS & été?x=1#test"
        let callback = try XCTUnwrap(URL(string: "nicomirror://shortcut-error"))
        let url = UserNavigationShortcut.url(for: name, errorCallback: callback)
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.scheme, "shortcuts")
        XCTAssertEqual(parts.host, "x-callback-url")
        XCTAssertEqual(parts.path, "/run-shortcut")
        XCTAssertEqual(parts.queryItems?.first(where: { $0.name == "name" })?.value, name)
        XCTAssertEqual(parts.queryItems?.first(where: { $0.name == "x-error" })?.value, callback.absoluteString)
        XCTAssertNil(parts.queryItems?.first(where: { $0.name == "x-success" }))
        XCTAssertNil(parts.queryItems?.first(where: { $0.name == "x" }))
    }
}
