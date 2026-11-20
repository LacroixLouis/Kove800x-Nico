import Foundation
import XCTest
@testable import NicoMirrorConnection

final class CockpitWeatherTests: XCTestCase {
    func testRequestRoundsCoordinatesAndFixesUnits() throws {
        let url = try XCTUnwrap(CockpitWeatherAPI.url(latitude: 45.753654, longitude: 5.690212))
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let values = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(values["latitude"], "45.75")
        XCTAssertEqual(values["longitude"], "5.69")
        XCTAssertEqual(values["wind_speed_unit"], "kmh")
        XCTAssertEqual(values["temperature_unit"], "celsius")
        XCTAssertNil(CockpitWeatherAPI.url(latitude: 91, longitude: 5))
        XCTAssertNil(CockpitWeatherAPI.url(latitude: .nan, longitude: 5))
    }
    func testRealResponseShapeDecodesNullHourlyValuesAndExpires() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let json = """
        {"current":{"time":1800000000,"temperature_2m":14.6,"wind_speed_10m":22.1,"weather_code":3,"is_day":0},
         "hourly":{"time":[1800000000,1800003600],"temperature_2m":[null,14.2],
                   "precipitation_probability":[null,25],"weather_code":[null,61]}}
        """
        let snapshot = try CockpitWeatherAPI.decode(Data(json.utf8), fetchedAt: date)
        XCTAssertEqual(snapshot.temperature, 14.6)
        XCTAssertFalse(snapshot.isDay)
        XCTAssertEqual(snapshot.hours.count, 1)
        XCTAssertEqual(snapshot.hours.first?.rainProbability, 25)
        XCTAssertFalse(snapshot.isStale(now: date))
        XCTAssertTrue(snapshot.isStale(now: date.addingTimeInterval(7_201)))
        XCTAssertFalse(CockpitWeatherSnapshot.symbol(for: 999).contains("sun"))
    }
    func testErrorOrOutOfRangeWeatherCannotTurnIntoSunnyFallbackData() {
        XCTAssertThrowsError(try CockpitWeatherAPI.decode(Data("{\"error\":true}".utf8)))
        let json = "{\"current\":{\"time\":1800000000,\"temperature_2m\":900,\"wind_speed_10m\":2,\"weather_code\":0,\"is_day\":1}}"
        XCTAssertThrowsError(try CockpitWeatherAPI.decode(Data(json.utf8), fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)))
    }
}
