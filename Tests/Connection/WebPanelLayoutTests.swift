import Foundation
import XCTest
@testable import NicoMirrorConnection

final class WebPanelLayoutTests: XCTestCase {
    func testMiniatureIsAlwaysTheOtherPanel() {
        var layout = WebPanelLayout()
        XCTAssertEqual(layout.phone, .first)
        XCTAssertEqual(layout.tft, .second)
        for _ in 0..<20 {
            let oldPhone = layout.phone
            let oldTFT = layout.tft
            layout.exchange()
            XCTAssertEqual(layout.phone, oldTFT)
            XCTAssertEqual(layout.tft, oldPhone)
            XCTAssertNotEqual(layout.phone, layout.tft)
        }
    }

    func testDraggingNeverChangesTheTFTSource() {
        var layout = WebPanelLayout()
        layout.moveMini(x: -2, y: 5)
        XCTAssertEqual(layout.miniX, 0)
        XCTAssertEqual(layout.miniY, 1)
        XCTAssertEqual(layout.tft, .second)
        layout.moveMini(x: .nan, y: .infinity)
        XCTAssertEqual(layout.miniX, 0)
        XCTAssertEqual(layout.miniY, 1)
    }

    func testExchangingPreservesMiniaturePosition() throws {
        var layout = WebPanelLayout()
        layout.moveMini(x: 0.2, y: 0.6)
        layout.exchange()
        let saved = try JSONDecoder().decode(WebPanelLayout.self, from: JSONEncoder().encode(layout))
        XCTAssertEqual(saved, layout)
        XCTAssertEqual(saved.tft, .first)
        XCTAssertEqual(saved.miniX, 0.2)
        XCTAssertEqual(saved.miniY, 0.6)
    }

    func testOfficialWazeEmbedUsesFreshCenterWhenSupplied() throws {
        let url = try XCTUnwrap(WebPanelPage(provider: .waze).resolvedURL(latitude: 45.7, longitude: 5.7))
        XCTAssertEqual(url.host, "embed.waze.com")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first(where: { $0.name == "lat" })?.value, "45.7")
        XCTAssertEqual(items.first(where: { $0.name == "lon" })?.value, "5.7")
        XCTAssertEqual(items.first(where: { $0.name == "zoom" })?.value, "12")
    }

    func testPasteOfficialWikilocEmbedExtractsOnlyTheSource() throws {
        let page = WebPanelPage(provider: .wikiloc,
            address: #"<iframe src="https://www.wikiloc.com/wikiloc/spatialArtifacts.do?event=view&amp;id=123" width="300"></iframe>"#)
        let url = try XCTUnwrap(page.resolvedURL())
        XCTAssertEqual(url.host, "www.wikiloc.com")
        XCTAssertTrue(url.absoluteString.contains("event=view&id=123"))
    }

    func testWikilocDefaultOpensAroundTheRealFixWhenItArrives() throws {
        let page = WebPanelPage(provider: .wikiloc)
        XCTAssertEqual(page.resolvedURL()?.path, "/")
        let url = try XCTUnwrap(page.resolvedURL(latitude: 45.76, longitude: 5.69))
        XCTAssertEqual(url.host, "fr.wikiloc.com")
        XCTAssertEqual(url.path, "/wikiloc/map.do")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first(where: { $0.name == "lt" })?.value, "45.76")
        XCTAssertEqual(items.first(where: { $0.name == "ln" })?.value, "5.69")
    }

    func testReceivingAFixPreservesAnExplicitTrailOrRouteLink() throws {
        for (provider, address) in [
            (WebMapProvider.wikiloc, "https://fr.wikiloc.com/wikiloc/view.do?id=123"),
            (WebMapProvider.waze, "https://www.waze.com/fr/live-map?to=ll.45.76%2C5.69")
        ] {
            let page = WebPanelPage(provider: provider, address: address)
            XCTAssertEqual(page.resolvedURL(latitude: 45.7, longitude: 5.7), URL(string: address))
        }
    }

    func testInvalidGPSCoordinatesAreNotSentToTheWebMaps() throws {
        for provider in WebMapProvider.allCases {
            for (latitude, longitude) in [(Double.nan, 5.7), (45.7, Double.infinity),
                                          (91.0, 5.7), (45.7, -181.0)] {
                let page = WebPanelPage(provider: provider)
                XCTAssertEqual(page.resolvedURL(latitude: latitude, longitude: longitude), page.resolvedURL())
            }
        }
    }

    func testNativeLinksAndLookalikeDomainsAreRejected() {
        for address in ["waze://?ll=45,5", "javascript:alert(1)", "http://www.waze.com/",
                        "https://notwaze.com/", "https://waze.com.example.org/",
                        "https://user:secret@waze.com/", "https://waze.com:8443/",
                        "<iframe src='javascript:alert(1)'></iframe>"] {
            XCTAssertNil(WebPanelPage(provider: .waze, address: address).resolvedURL(), address)
        }
        XCTAssertNil(WebPanelPage(provider: .wikiloc, address: "https://www.waze.com/").resolvedURL())
        XCTAssertNil(WebPanelPage(provider: .wikiloc, address: "https://fakewikiloc.com/").resolvedURL())
    }
    func testEmptyPanelsCanBecomeNavigationAndWebsiteWithoutConnection() {
        var contents = DualPanelContents()
        var layout = WebPanelLayout()
        XCTAssertEqual(contents.content(layout.phone), .empty)
        XCTAssertEqual(contents.content(layout.tft), .empty)
        XCTAssertTrue(contents.select(.navigation, for: layout.phone))
        layout.exchange()
        XCTAssertEqual(contents.content(layout.tft), .navigation)
        XCTAssertEqual(contents.content(layout.phone), .empty)
        XCTAssertTrue(contents.select(.website, for: layout.phone))
        for _ in 0..<20 {
            layout.exchange()
            XCTAssertNotEqual(contents.content(layout.phone), contents.content(layout.tft))
            XCTAssertEqual(Set([contents.first, contents.second]), [.navigation, .website])
        }
    }

    func testRendererCannotBeDuplicatedAndClearingOnePreservesTheOther() {
        var contents = DualPanelContents()
        XCTAssertTrue(contents.select(.navigation, for: .first))
        XCTAssertFalse(contents.select(.navigation, for: .second))
        XCTAssertTrue(contents.select(.website, for: .second))
        XCTAssertFalse(contents.select(.website, for: .first))
        XCTAssertTrue(contents.select(.empty, for: .first))
        XCTAssertEqual(contents.second, .website)
        XCTAssertTrue(contents.select(.navigation, for: .first))
    }

    func testContentsSurviveReloadAndCorruptedDuplicatesRecover() throws {
        var contents = DualPanelContents()
        contents.select(.website, for: .first)
        contents.select(.navigation, for: .second)
        XCTAssertEqual(try JSONDecoder().decode(DualPanelContents.self, from: JSONEncoder().encode(contents)), contents)
        let data = Data(#"{"first":"navigation","second":"navigation"}"#.utf8)
        let recovered = try JSONDecoder().decode(DualPanelContents.self, from: data)
        XCTAssertEqual(recovered.first, .navigation)
        XCTAssertEqual(recovered.second, .empty)
    }

    func testDualOutputIsPausedOutsideCockpitAndWhenBackgrounded() {
        for connected in [false, true] {
            for foreground in [false, true] {
                for visible in [false, true] {
                    let mode = ProjectionPolicy.dualPanelMode(connected: connected, foreground: foreground, cockpitVisible: visible)
                    XCTAssertEqual(mode, !connected ? .disconnected : (foreground && visible ? .screen : .paused))
                }
            }
        }
    }

}
