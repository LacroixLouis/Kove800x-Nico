import XCTest
@testable import NicoMirrorConnection

final class DashboardLayoutTests: XCTestCase {
    func testTwoCockpitsHaveIndependentDefaultsAndSurviveReload() {
        var first = DashboardLayout.initial()
        let second = DashboardLayout.initial(second: true)
        first.move(.weather, before: .applications)
        first.setVisible(false, widget: .connection)
        XCTAssertEqual(DashboardLayout.load(first.encoded()), first)
        XCTAssertEqual(second, DashboardLayout.initial(second: true))
        XCTAssertFalse(first.visible.contains(.connection))
        XCTAssertTrue(second.visible.contains(.connection))
    }
    func testDropCanMoveBothDownToLastAndUpToFirst() {
        var layout = DashboardLayout.initial()
        layout.move(.applications, over: .map)
        XCTAssertEqual(layout.order.last, .applications)
        layout.move(.applications, over: .weather)
        XCTAssertEqual(layout.order.first, .applications)
        XCTAssertEqual(Set(layout.order).count, DashboardWidget.allCases.count)
    }
    func testDamagedAndDuplicateLayoutsRecoverWithoutDuplicateWidgets() {
        let layout = DashboardLayout.load("{\"order\":[\"weather\",\"weather\"],\"hidden\":[]}")
        XCTAssertEqual(layout.order.first, .weather)
        XCTAssertEqual(layout.order.count, DashboardWidget.allCases.count)
        XCTAssertEqual(DashboardLayout.load("not json"), .initial())
    }
}
