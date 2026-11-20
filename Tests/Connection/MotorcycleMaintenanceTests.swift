import Foundation
import XCTest
@testable import NicoMirrorConnection

final class MotorcycleMaintenanceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFreshGarageDoesNotInventManufacturerIntervalsOrHistory() {
        let garage = MotorcycleMaintenance()
        XCTAssertNil(garage.mileage)
        XCTAssertTrue(garage.records.isEmpty)
        XCTAssertTrue(garage.tasks.allSatisfy { !$0.isConfigured && $0.intervalKilometers == nil && $0.intervalMonths == nil })
        XCTAssertEqual(garage.attentionCount(now: now), 0)
    }
    func testEarliestDateOrMileageControlsUrgency() {
        var task = MaintenanceTask(title: "Révision", category: .general)
        task.nextKilometers = 15_000
        task.nextDate = now.addingTimeInterval(-172_800)
        XCTAssertEqual(MaintenanceDue(task: task, mileage: 10_000, now: now).urgency, .overdue)
        task.nextDate = now.addingTimeInterval(86_400 * 60)
        XCTAssertEqual(MaintenanceDue(task: task, mileage: 15_000, now: now).urgency, .due)
        XCTAssertEqual(MaintenanceDue(task: task, mileage: 14_800, now: now).urgency, .soon)
        XCTAssertEqual(MaintenanceDue(task: task, mileage: nil, now: now).urgency, .scheduled)
    }
    func testCompletingServiceRecalculatesIntervalsAndPreservesMoneyExactly() throws {
        var garage = MotorcycleMaintenance()
        var task = garage.tasks[0]
        task.intervalKilometers = 5_000; task.intervalMonths = 12
        try garage.saveTask(task)
        try garage.complete(taskID: task.id, date: now, kilometers: 10_000,
                            costCents: 8_990, notes: "Filtre changé", now: now)
        let updated = try XCTUnwrap(garage.tasks.first(where: { $0.id == task.id }))
        XCTAssertEqual(updated.nextKilometers, 15_000)
        XCTAssertEqual(updated.nextDate, Calendar.current.date(byAdding: .month, value: 12, to: now))
        XCTAssertEqual(garage.mileage, 10_000)
        XCTAssertEqual(garage.totalCostCents, 8_990)
        XCTAssertEqual(try MotorcycleMaintenance.decodeBackup(garage.encodedData()), garage)
    }
    func testHistoricalEntryDoesNotLowerOdometerOrRegressLatestService() throws {
        var garage = MotorcycleMaintenance(); var task = garage.tasks[0]
        task.intervalKilometers = 5_000; try garage.saveTask(task)
        try garage.complete(taskID: task.id, date: now, kilometers: 20_000, costCents: nil, notes: "", now: now)
        try garage.complete(taskID: task.id, date: now.addingTimeInterval(-86_400 * 30),
                            kilometers: 15_000, costCents: nil, notes: "Ancienne facture", now: now)
        XCTAssertEqual(garage.mileage, 20_000)
        XCTAssertEqual(garage.tasks[0].nextKilometers, 25_000)
        XCTAssertEqual(garage.tasks[0].lastDate, now)
        XCTAssertEqual(garage.records.count, 2)
    }
    func testInvalidCompletionIsAtomicAndNeedsMileageForKmRecurrence() throws {
        var garage = MotorcycleMaintenance(); var task = garage.tasks[0]
        task.intervalKilometers = 5_000; try garage.saveTask(task)
        let before = garage
        XCTAssertThrowsError(try garage.complete(taskID: task.id, date: now, kilometers: nil,
                                                costCents: nil, notes: "", now: now))
        XCTAssertEqual(garage, before)
        XCTAssertThrowsError(try garage.complete(taskID: task.id, date: now.addingTimeInterval(10),
                                                kilometers: 100, costCents: nil, notes: "", now: now))
        XCTAssertEqual(garage, before)
    }
    func testBackupRejectsCorruptDataAndUnsupportedSchema() throws {
        XCTAssertThrowsError(try MotorcycleMaintenance.decodeBackup(Data("{}".utf8)))
        var garage = MotorcycleMaintenance(); garage.schemaVersion = 999
        XCTAssertThrowsError(try garage.encodedData())
        garage.schemaVersion = 1; garage.tasks.append(garage.tasks[0])
        XCTAssertThrowsError(try garage.encodedData())
    }
    func testFrenchCostInputAndCsvAreSafeForSpreadsheetImports() throws {
        XCTAssertEqual(MaintenanceInput.costCents("89,90"), 8_990)
        XCTAssertEqual(MaintenanceInput.costCents("12.5"), 1_250)
        XCTAssertNil(MaintenanceInput.costCents("12,345"))
        XCTAssertNil(MaintenanceInput.costCents("-1"))
        XCTAssertEqual(MaintenanceInput.kilometers("12 500"), 12_500)
        XCTAssertNil(MaintenanceInput.kilometers("12.5"))
        var garage = MotorcycleMaintenance(); let task = garage.tasks[0]
        try garage.complete(taskID: task.id, date: now, kilometers: 1_000, costCents: 50,
                            notes: "=formula;\"note\"\nnext", now: now)
        XCTAssertTrue(garage.historyCSV.contains("\"'=formula;\"\"note\"\"\nnext\""))
        XCTAssertTrue(garage.historyCSV.contains("\"0.50\""))
    }
}
