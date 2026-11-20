import Foundation
import XCTest
@testable import NicoMirrorConnection

final class GPXTrackTests: XCTestCase {
    private func parse(_ xml: String) throws -> GPXTrack {
        try GPXTrack.parse(Data(xml.utf8), fallbackName: "Wikiloc")
    }
    func testTrackSegmentsAreNotJoinedAcrossGaps() throws {
        let track = try parse("<gpx><trk><name>Pistes</name><trkseg><trkpt lat='0' lon='0'/><trkpt lat='0' lon='0.001'/></trkseg><trkseg><trkpt lat='0' lon='1'/><trkpt lat='0' lon='1.001'/></trkseg></trk></gpx>")
        XCTAssertEqual(track.name, "Pistes")
        XCTAssertEqual(track.segments.count, 2)
        XCTAssertGreaterThan(track.distanceFromTrace(to: GPXPoint(latitude: 0, longitude: 0.5)), 50_000)
    }
    func testDistanceUsesSegmentRatherThanClosestVertex() throws {
        let track = try parse("<gpx><rte><rtept lat='0' lon='0'/><rtept lat='0' lon='0.01'/></rte></gpx>")
        XCTAssertEqual(track.distanceFromTrace(to: GPXPoint(latitude: 0.001, longitude: 0.005)), 111.2, accuracy: 1)
    }
    func testWaypointsAloneAreNotAnOrderedTrace() {
        XCTAssertThrowsError(try parse("<gpx><wpt lat='1' lon='1'/><wpt lat='2' lon='2'/></gpx>"))
    }
    func testInvalidCoordinatesAndMalformedXMLFail() {
        for xml in ["<gpx>", "<gpx><trk><trkseg><trkpt lat='nan' lon='0'/></trkseg></trk></gpx>", "<gpx><rte><rtept lat='91' lon='0'/></rte></gpx>"] {
            XCTAssertThrowsError(try parse(xml))
        }
    }
    func testNamespacedTrackAndRouteFallback() throws {
        let track = try parse("<g:gpx xmlns:g='http://www.topografix.com/GPX/1/1'><g:rte><g:rtept lat='1' lon='1'/><g:rtept lat='2' lon='2'/></g:rte></g:gpx>")
        XCTAssertEqual(track.name, "Wikiloc")
        XCTAssertEqual(track.pointCount, 2)
    }
    func testTrackWinsOverRoute() throws {
        let track = try parse("<gpx><rte><rtept lat='1' lon='1'/><rtept lat='2' lon='2'/></rte><trk><trkseg><trkpt lat='3' lon='3'/><trkpt lat='4' lon='4'/></trkseg></trk></gpx>")
        XCTAssertEqual(track.segments[0][0].latitude, 3)
    }
    func testPointBudgetIsEnforced() {
        let points = String(repeating: "<trkpt lat='0' lon='0'/>", count: 30_001)
        XCTAssertThrowsError(try parse("<gpx><trk><trkseg>" + points + "</trkseg></trk></gpx>"))
    }
}
