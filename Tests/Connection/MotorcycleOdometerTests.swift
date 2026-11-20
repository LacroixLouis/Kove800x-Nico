import Foundation
import XCTest
@testable import NicoMirrorConnection

final class MotorcycleOdometerTests: XCTestCase {
    private let motorcycleID = UUID()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testTFTDistancesUseTenthsOfKilometersAndKeepTripSeparate() throws {
        let packet = try XCTUnwrap(MotorcycleDistancePacket.decode([
            "msg_id": 10, "item": 2, "total": 123_456, "subtotal": 87
        ]))
        XCTAssertEqual(packet.odometerKilometers, 12_345.6)
        XCTAssertEqual(packet.tripKilometers, 8.7)
        let tripOnly = try XCTUnwrap(MotorcycleDistancePacket.decode(["msg_id": 10, "item": 2, "subtotal": 0]))
        XCTAssertNil(tripOnly.odometerKilometers)
        XCTAssertEqual(tripOnly.tripKilometers, 0)
    }

    func testStandaloneLegacyDistancesRemainSupported() throws {
        let packet = try XCTUnwrap(MotorcycleDistancePacket.decode(["total": 100, "subtotal": 1]))
        XCTAssertEqual(packet.odometerKilometers, 10)
        XCTAssertEqual(packet.tripKilometers, 0.1)
        XCTAssertEqual(MotorcycleDistancePacket.decode(["msg_id": 10, "item": 2, "total": 0])?.odometerKilometers, 0)
    }

    func testOtherMessagesAndMalformedDistancesCannotSupplyAnOdometer() {
        XCTAssertNil(MotorcycleDistancePacket.decode(["msg_id": 27, "total": 100]))
        XCTAssertNil(MotorcycleDistancePacket.decode(["msg_id": 10, "item": 1, "total": 100]))
        let invalidValues: [Any] = [true, -1, 20_000_001, 10.5, "100", NSNull(), Double.nan, Double.infinity]
        for invalid in invalidValues {
            XCTAssertNil(MotorcycleDistancePacket.decode(["msg_id": 10, "item": 2, "total": invalid]))
        }
    }

    func testAutomaticReadingReplacesLegacyMileageAndRecalculatesDueDistances() throws {
        var garage = MotorcycleMaintenance()
        garage.mileage = 5_000
        var task = garage.tasks[0]
        task.nextKilometers = 13_000
        try garage.saveTask(task)
        let originalTasks = garage.tasks
        XCTAssertTrue(garage.synchronizeOdometer(reading(12_345.6)))
        XCTAssertEqual(garage.mileage, 12_345)
        XCTAssertEqual(garage.tasks, originalTasks)
        XCTAssertEqual(MaintenanceDue(task: task, mileage: garage.mileage, now: now).kilometersRemaining, 655)
        XCTAssertEqual(try MotorcycleMaintenance.decodeBackup(garage.encodedData()), garage)
    }

    func testFirstMotorcycleReadingCanCorrectAnExcessiveManualValue() {
        var garage = MotorcycleMaintenance()
        garage.mileage = 100_000
        XCTAssertTrue(garage.synchronizeOdometer(reading(2_500)))
        XCTAssertEqual(garage.mileage, 2_500)
    }

    func testRepeatedReadingRefreshesTheTimestampAndReconnectContinuesTheSameMotorcycle() throws {
        var garage = MotorcycleMaintenance()
        XCTAssertTrue(garage.synchronizeOdometer(reading(100)))
        XCTAssertTrue(garage.synchronizeOdometer(reading(100, after: 120)))
        var restored = try MotorcycleMaintenance.decodeBackup(garage.encodedData())
        XCTAssertTrue(restored.synchronizeOdometer(reading(101.2, after: 240)))
        XCTAssertEqual(restored.mileage, 101)
        XCTAssertEqual(restored.odometer?.receivedAt, now.addingTimeInterval(240))
    }

    func testRegressionAnotherMotorcycleAndOlderMessagesLeaveTheGarageIntact() {
        var garage = MotorcycleMaintenance()
        XCTAssertTrue(garage.synchronizeOdometer(reading(1_000)))
        let before = garage
        XCTAssertFalse(garage.synchronizeOdometer(reading(999, after: 120)))
        XCTAssertFalse(garage.synchronizeOdometer(reading(1_001, after: -120)))
        XCTAssertFalse(garage.synchronizeOdometer(MotorcycleOdometer(
            kilometers: 9_000, peripheralID: UUID(), receivedAt: now.addingTimeInterval(120))))
        XCTAssertFalse(garage.synchronizeOdometer(reading(.nan)))
        XCTAssertEqual(garage, before)
    }

    func testHistoricalServiceEntryCannotOverwriteMotorcycleMileage() throws {
        var garage = MotorcycleMaintenance()
        XCTAssertTrue(garage.synchronizeOdometer(reading(12_345.6)))
        let before = garage.odometer
        try garage.complete(taskID: garage.tasks[0].id, date: now.addingTimeInterval(-86_400),
                            kilometers: 12_500, costCents: nil, notes: "Facture", now: now)
        XCTAssertEqual(garage.mileage, 12_345)
        XCTAssertEqual(garage.odometer, before)
        XCTAssertEqual(garage.records[0].kilometers, 12_500)
        XCTAssertTrue(garage.isValid)
    }

    func testV6BackupWithoutOdometerMetadataStillRestoresItsHistory() throws {
        var legacy = MotorcycleMaintenance()
        try legacy.complete(taskID: legacy.tasks[0].id, date: now, kilometers: 1_000,
                            costCents: 5_000, notes: "Entretien existant", now: now)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: legacy.encodedData()) as? [String: Any])
        json.removeValue(forKey: "odometer")
        var restored = try MotorcycleMaintenance.decodeBackup(JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.odometer)
        XCTAssertEqual(restored, legacy)
        XCTAssertTrue(restored.synchronizeOdometer(reading(1_500)))
        XCTAssertEqual(restored.records, legacy.records)
        XCTAssertEqual(restored.tasks, legacy.tasks)
    }

    func testCorruptBackupWithAnInconsistentOdometerIsRejected() {
        var garage = MotorcycleMaintenance()
        XCTAssertTrue(garage.synchronizeOdometer(reading(10)))
        garage.mileage = 20
        XCTAssertThrowsError(try garage.encodedData())
    }

    private func reading(_ kilometers: Double, after seconds: TimeInterval = 0) -> MotorcycleOdometer {
        MotorcycleOdometer(kilometers: kilometers, peripheralID: motorcycleID, receivedAt: now.addingTimeInterval(seconds))
    }
}
