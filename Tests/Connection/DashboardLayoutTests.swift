import XCTest
@testable import NicoMirrorConnection

final class DashboardLayoutTests: XCTestCase {
    func testTwoCockpitsHaveIndependentDefaultsAndSurviveReload() {
        var first = DashboardLayout.initial()
        let second = DashboardLayout.initial(second: true)
        first.move(.weather, before: .screens)
        first.setVisible(false, widget: .connection)
        XCTAssertEqual(DashboardLayout.load(first.encoded()), first)
        XCTAssertEqual(second, DashboardLayout.initial(second: true))
        XCTAssertFalse(first.visible.contains(.connection))
        XCTAssertTrue(second.visible.contains(.connection))
    }
    func testDropCanMoveBothDownToLastAndUpToFirst() {
        var layout = DashboardLayout.initial()
        layout.move(.screens, over: .map)
        XCTAssertEqual(layout.order.last, .screens)
        layout.move(.screens, over: .weather)
        XCTAssertEqual(layout.order.first, .screens)
        XCTAssertEqual(Set(layout.order).count, DashboardWidget.allCases.count)
    }
    func testDamagedAndDuplicateLayoutsRecoverWithoutDuplicateWidgets() {
        let layout = DashboardLayout.load("{\"order\":[\"weather\",\"weather\"],\"hidden\":[]}")
        XCTAssertEqual(layout.order.first, .weather)
        XCTAssertEqual(layout.order.count, DashboardWidget.allCases.count)
        XCTAssertEqual(DashboardLayout.load("not json"), .initial())
    }
    func testOldLauncherWidgetMigratesWithoutDuplicatingScreens() {
        let layout = DashboardLayout.load(#"{"order":["applications","screens","weather"],"hidden":["applications"]}"#)
        XCTAssertEqual(layout.order.filter { $0 == .screens }.count, 1)
        XCTAssertFalse(layout.order.contains(.applications))
        XCTAssertFalse(layout.visible.contains(.screens))
        XCTAssertEqual(Set(layout.order), Set(DashboardWidget.allCases))
    }

}
