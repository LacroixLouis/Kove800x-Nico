import Foundation
import CoreFoundation

enum MaintenanceCategory: String, Codable, CaseIterable, Identifiable {
    case engine, airFilter, transmission, tires, brakes, suspension, general
    var id: String { rawValue }
    var title: String {
        switch self {
        case .engine: return "Moteur"
        case .airFilter: return "Filtre à air"
        case .transmission: return "Transmission"
        case .tires: return "Pneus"
        case .brakes: return "Freins"
        case .suspension: return "Suspensions"
        case .general: return "Révision"
        }
    }
    var symbol: String {
        switch self {
        case .engine: return "oilcan.fill"
        case .airFilter: return "wind"
        case .transmission: return "link"
        case .tires: return "circle.circle"
        case .brakes: return "hand.raised.fill"
        case .suspension: return "slider.vertical.3"
        case .general: return "wrench.and.screwdriver.fill"
        }
    }
}

struct MaintenanceTask: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var category: MaintenanceCategory
    var nextKilometers: Int?
    var nextDate: Date?
    var intervalKilometers: Int?
    var intervalMonths: Int?
    var lastKilometers: Int?
    var lastDate: Date?
    var notes = ""

    var isConfigured: Bool { nextKilometers != nil || nextDate != nil }

    static var starterTasks: [Self] {
        [Self(title: "Vidange & filtre à huile", category: .engine),
         Self(title: "Filtre à air", category: .airFilter),
         Self(title: "Chaîne & transmission", category: .transmission),
         Self(title: "Pneu avant", category: .tires),
         Self(title: "Pneu arrière", category: .tires),
         Self(title: "Freins", category: .brakes),
         Self(title: "Suspensions", category: .suspension),
         Self(title: "Révision générale", category: .general)]
    }
}

struct MaintenanceRecord: Codable, Equatable, Identifiable {
    var id = UUID()
    let taskID: UUID
    let title: String
    let category: MaintenanceCategory
    let date: Date
    let kilometers: Int?
    let costCents: Int?
    let notes: String
}

enum MaintenanceUrgency: Int, Comparable {
    case overdue, due, soon, scheduled, unconfigured
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    var title: String {
        switch self {
        case .overdue: return "Échéance dépassée"
        case .due: return "À faire"
        case .soon: return "Bientôt"
        case .scheduled: return "Programmé"
        case .unconfigured: return "À programmer"
        }
    }
}

struct MaintenanceDue {
    let urgency: MaintenanceUrgency
    let kilometersRemaining: Int?
    let daysRemaining: Int?

    init(task: MaintenanceTask, mileage: Int?, now: Date = Date(), calendar: Calendar = .current) {
        kilometersRemaining = task.nextKilometers.flatMap { target in mileage.map { target - $0 } }
        daysRemaining = task.nextDate.flatMap {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: $0)).day
        }
        if (kilometersRemaining.map { $0 < 0 } ?? false) || (daysRemaining.map { $0 < 0 } ?? false) {
            urgency = .overdue
        } else if kilometersRemaining == 0 || daysRemaining == 0 {
            urgency = .due
        } else if (kilometersRemaining.map { $0 <= 250 } ?? false) || (daysRemaining.map { $0 <= 14 } ?? false) {
            urgency = .soon
        } else {
            urgency = task.isConfigured ? .scheduled : .unconfigured
        }
    }
}

enum MaintenanceError: LocalizedError {
    case invalidInput, missingTask, mileageRequired, invalidBackup
    var errorDescription: String? {
        switch self {
        case .invalidInput: return "Vérifie les valeurs saisies. Le kilométrage et le prix doivent être positifs ou nuls.".rivetLocalized
        case .missingTask: return "Cette opération n’existe plus. Rouvre l’entretien.".rivetLocalized
        case .mileageRequired: return "Renseigne le kilométrage pour calculer la prochaine échéance.".rivetLocalized
        case .invalidBackup: return "Ce fichier n’est pas une sauvegarde d’entretien Double Interface valide.".rivetLocalized
        }
    }
}

struct MotorcycleMaintenance: Codable, Equatable {
    static let preferenceKey = "rivet.maintenance.v1"
    var schemaVersion = 1
    var motorcycleName = "Kove 800X Rally"
    var mileage: Int?
    var odometer: MotorcycleOdometer?
    var tasks = MaintenanceTask.starterTasks
    var records: [MaintenanceRecord] = []

    static func load(_ value: String) -> Self {
        guard let data = value.data(using: .utf8), let decoded = try? decodeBackup(data) else { return Self() }
        return decoded
    }

    static func decodeBackup(_ data: Data) throws -> Self {
        guard data.count <= 8_000_000,
              let value = try? JSONDecoder().decode(Self.self, from: data), value.isValid else {
            throw MaintenanceError.invalidBackup
        }
        return value
    }

    var isValid: Bool {
        guard schemaVersion == 1, !motorcycleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              motorcycleName.count <= 80, Self.validKilometers(mileage), tasks.count <= 100,
              records.count <= 10_000, Set(tasks.map(\.id)).count == tasks.count,
              Set(records.map(\.id)).count == records.count else { return false }
        if let odometer {
            guard odometer.isValid, mileage == Int(odometer.kilometers) else { return false }
        }
        guard tasks.allSatisfy({ task in
            !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && task.title.count <= 80
            && task.notes.count <= 2_000 && Self.validKilometers(task.nextKilometers)
            && Self.validKilometers(task.lastKilometers)
            && (task.intervalKilometers.map { (1...200_000).contains($0) } ?? true)
            && (task.intervalMonths.map { (1...120).contains($0) } ?? true)
            && Self.validDate(task.nextDate) && Self.validDate(task.lastDate)
        }) else { return false }
        return records.allSatisfy {
            !$0.title.isEmpty && $0.title.count <= 80 && $0.notes.count <= 2_000
            && Self.validKilometers($0.kilometers) && Self.validDate($0.date)
            && ($0.costCents.map { (0...100_000_000).contains($0) } ?? true)
        }
    }

    static func validKilometers(_ value: Int?) -> Bool { value.map { (0...2_000_000).contains($0) } ?? true }
    private static func validDate(_ value: Date?) -> Bool {
        value.map { $0.timeIntervalSince1970.isFinite && abs($0.timeIntervalSince1970) < 31_536_000_000 } ?? true
    }

    func encodedData() throws -> Data {
        guard isValid else { throw MaintenanceError.invalidInput }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= 8_000_000 else { throw MaintenanceError.invalidInput }
        return data
    }
    func encoded() throws -> String {
        guard let string = String(data: try encodedData(), encoding: .utf8) else { throw MaintenanceError.invalidInput }
        return string
    }

    func orderedTasks(now: Date = Date()) -> [MaintenanceTask] {
        tasks.sorted {
            let a = MaintenanceDue(task: $0, mileage: mileage, now: now)
            let b = MaintenanceDue(task: $1, mileage: mileage, now: now)
            if a.urgency != b.urgency { return a.urgency < b.urgency }
            if $0.nextDate != $1.nextDate { return ($0.nextDate ?? .distantFuture) < ($1.nextDate ?? .distantFuture) }
            if $0.nextKilometers != $1.nextKilometers { return ($0.nextKilometers ?? Int.max) < ($1.nextKilometers ?? Int.max) }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
    func attentionCount(now: Date = Date()) -> Int {
        tasks.filter { MaintenanceDue(task: $0, mileage: mileage, now: now).urgency <= .soon }.count
    }
    var history: [MaintenanceRecord] { records.sorted { $0.date > $1.date } }
    var totalCostCents: Int { records.compactMap(\.costCents).reduce(0, +) }

    @discardableResult
    mutating func synchronizeOdometer(_ reading: MotorcycleOdometer) -> Bool {
        guard reading.isValid else { return false }
        if let previous = odometer {
            guard reading.peripheralID == previous.peripheralID,
                  reading.kilometers >= previous.kilometers,
                  reading.receivedAt >= previous.receivedAt else { return false }
        }
        // The first motorcycle reading supersedes a legacy manual value.
        // A partial trip or an older service record cannot replace the ODO.
        odometer = reading
        mileage = Int(reading.kilometers)
        return true
    }

    mutating func saveTask(_ task: MaintenanceTask) throws {
        var changed = self
        if let index = changed.tasks.firstIndex(where: { $0.id == task.id }) { changed.tasks[index] = task }
        else { changed.tasks.append(task) }
        guard changed.isValid else { throw MaintenanceError.invalidInput }
        self = changed
    }

    mutating func complete(taskID: UUID, date: Date, kilometers: Int?, costCents: Int?, notes: String,
                           calendar: Calendar = .current, now: Date = Date()) throws {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { throw MaintenanceError.missingTask }
        guard date <= now, Self.validKilometers(kilometers), notes.count <= 2_000,
              costCents.map({ (0...100_000_000).contains($0) }) ?? true else { throw MaintenanceError.invalidInput }
        if tasks[index].intervalKilometers != nil && kilometers == nil { throw MaintenanceError.mileageRequired }
        var changed = self
        let task = tasks[index]
        changed.records.append(MaintenanceRecord(taskID: taskID, title: task.title, category: task.category,
            date: date, kilometers: kilometers, costCents: costCents, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)))
        if odometer == nil, let kilometers { changed.mileage = max(changed.mileage ?? 0, kilometers) }
        // A late entry in the history must not move a more recent service backwards.
        if task.lastDate == nil || date >= task.lastDate! {
            changed.tasks[index].lastDate = date
            changed.tasks[index].lastKilometers = kilometers
            changed.tasks[index].nextKilometers = task.intervalKilometers.flatMap { interval in kilometers.map { $0 + interval } }
            changed.tasks[index].nextDate = task.intervalMonths.flatMap { calendar.date(byAdding: .month, value: $0, to: date) }
        }
        guard changed.isValid else { throw MaintenanceError.invalidInput }
        self = changed
    }

    var historyCSV: String {
        let formatter = ISO8601DateFormatter()
        func cell(_ text: String) -> String {
            // Spreadsheet imports must treat notes beginning with formula tokens as text.
            let value = ["=", "+", "-", "@", "\t", "\r"].contains(where: { text.hasPrefix($0) }) ? "'" + text : text
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let rows = history.map { item in
            [motorcycleName, formatter.string(from: item.date), item.title,
             item.kilometers.map(String.init) ?? "", item.costCents.map { String(format: "%.2f", Double($0) / 100) } ?? "",
             item.notes].map(cell).joined(separator: ";")
        }
        return "Moto;Date;Opération;Kilométrage;Coût EUR;Notes\r\n" + rows.joined(separator: "\r\n") + "\r\n"
    }
}

struct MotorcycleOdometer: Codable, Equatable {
    let kilometers: Double
    let peripheralID: UUID
    let receivedAt: Date

    var isValid: Bool {
        kilometers.isFinite && (0...2_000_000).contains(kilometers)
            && receivedAt.timeIntervalSince1970.isFinite
            && abs(receivedAt.timeIntervalSince1970) < 31_536_000_000
    }
}

/// Distances already supported by the TFT's ThinkerRide protocol.
/// Total and trip are separate fields, in tenths of a kilometre.
struct MotorcycleDistancePacket {
    let odometerKilometers: Double?
    let tripKilometers: Double?

    static func decode(_ json: [String: Any]) -> Self? {
        if json["msg_id"] != nil {
            guard json["msg_id"] as? Int == 10, json["item"] as? Int == 2 else { return nil }
        } else if json["item"] != nil, json["item"] as? Int != 2 {
            return nil
        }
        let total = kilometers(json["total"])
        let trip = kilometers(json["subtotal"])
        guard total != nil || trip != nil else { return nil }
        return Self(odometerKilometers: total, tripKilometers: trip)
    }

    private static func kilometers(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let raw = number.doubleValue
        guard raw.isFinite, (0...20_000_000).contains(raw), raw.rounded(.towardZero) == raw else { return nil }
        return raw / 10
    }
}

enum MaintenanceInput {
    static func kilometers(_ value: String) -> Int? {
        let clean = value.filter { !$0.isWhitespace }
        guard !clean.isEmpty, clean.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(clean),
              MotorcycleMaintenance.validKilometers(number) else { return nil }
        return number
    }
    static func costCents(_ value: String) -> Int? {
        let clean = value.filter { !$0.isWhitespace }.replacingOccurrences(of: ",", with: ".")
        guard !clean.isEmpty, clean.allSatisfy({ ($0.isASCII && $0.isNumber) || $0 == "." }) else { return nil }
        let parts = clean.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, !parts[0].isEmpty, let euros = Int(parts[0]), euros <= 1_000_000 else { return nil }
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        guard fraction.count <= 2, let cents = Int(fraction.padding(toLength: 2, withPad: "0", startingAt: 0)) else { return nil }
        let total = euros * 100 + cents
        return (0...100_000_000).contains(total) ? total : nil
    }
}
