import SwiftUI

struct MaintenanceMotorcycleForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var error: String?
    let garage: MotorcycleMaintenance
    let onSave: (String) throws -> Void

    init(garage: MotorcycleMaintenance, onSave: @escaping (String) throws -> Void) {
        _name = State(initialValue: garage.motorcycleName)
        self.garage = garage
        self.onSave = onSave
    }

    var body: some View {
        RideSheet("Ma moto") {
            RideCard {
                TextField("Nom de la moto", text: $name).textFieldStyle(.roundedBorder)
                LabeledContent("Kilométrage au compteur", value: garage.mileage.map { $0.formatted() + " km" } ?? "—")
                Text("Le kilométrage se synchronise automatiquement à la connexion Bluetooth de la moto.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
            }
            if let error { Text(LocalizedStringKey(error)).font(.caption).foregroundStyle(.red) }
            Button("Enregistrer", systemImage: "checkmark") {
                do {
                    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanName.isEmpty, cleanName.count <= 80 else {
                        throw MaintenanceError.invalidInput
                    }
                    try onSave(cleanName); dismiss()
                } catch { self.error = error.localizedDescription }
            }.buttonStyle(RideButtonStyle())
        }
    }
}

struct MaintenanceTaskForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var task: MaintenanceTask
    @State private var hasKilometers: Bool
    @State private var kilometers: String
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var intervalKilometers: String
    @State private var intervalMonths: String
    @State private var error: String?
    @State private var confirmDelete = false
    let canDelete: Bool
    let onSave: (MaintenanceTask) throws -> Void
    let onDelete: () throws -> Void

    init(task: MaintenanceTask, canDelete: Bool, onSave: @escaping (MaintenanceTask) throws -> Void,
         onDelete: @escaping () throws -> Void) {
        _task = State(initialValue: task)
        _hasKilometers = State(initialValue: task.nextKilometers != nil)
        _kilometers = State(initialValue: task.nextKilometers.map(String.init) ?? "")
        _hasDate = State(initialValue: task.nextDate != nil)
        _date = State(initialValue: task.nextDate ?? Date())
        _intervalKilometers = State(initialValue: task.intervalKilometers.map(String.init) ?? "")
        _intervalMonths = State(initialValue: task.intervalMonths.map(String.init) ?? "")
        self.canDelete = canDelete; self.onSave = onSave; self.onDelete = onDelete
    }

    var body: some View {
        RideSheet(canDelete ? "Régler l’échéance" : "Ajouter une opération") {
            RideCard {
                TextField("Nom de l’opération", text: $task.title).textFieldStyle(.roundedBorder)
                Picker("Catégorie", selection: $task.category) {
                    ForEach(MaintenanceCategory.allCases) { category in Text(category.title).tag(category) }
                }
                Text("Prochaine échéance").font(.headline)
                Toggle("À un kilométrage", isOn: $hasKilometers)
                if hasKilometers {
                    MaintenanceNumberField(title: "Kilométrage cible", placeholder: "Ex. 15000", text: $kilometers)
                }
                Toggle("À une date", isOn: $hasDate)
                if hasDate { DatePicker("Date cible", selection: $date, displayedComponents: .date) }
                Text("Si tu règles les deux, le premier terme atteint s’applique.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
            }
            RideCard {
                Text("Après chaque entretien").font(.headline)
                Text("Ces intervalles servent à recalculer la prochaine échéance lorsque tu enregistres l’opération. Laisse vide pour une opération ponctuelle.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
                MaintenanceNumberField(title: "Tous les… kilomètres", placeholder: "Intervalle du carnet", text: $intervalKilometers)
                MaintenanceNumberField(title: "Tous les… mois", placeholder: "Intervalle du carnet", text: $intervalMonths)
            }
            RideCard {
                Text("Mes notes").font(.headline)
                TextField("Référence, huile, pièces, atelier…", text: $task.notes, axis: .vertical)
                    .lineLimit(3...8).textFieldStyle(.roundedBorder)
            }
            if let error { Text(LocalizedStringKey(error)).font(.caption).foregroundStyle(.red) }
            Button("Enregistrer", systemImage: "checkmark", action: save).buttonStyle(RideButtonStyle())
            if canDelete {
                Button("Retirer cette opération", role: .destructive) { confirmDelete = true }
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .confirmationDialog("Retirer cette opération du suivi ?", isPresented: $confirmDelete) {
            Button("Retirer", role: .destructive) {
                do { try onDelete(); dismiss() } catch { self.error = error.localizedDescription }
            }
        } message: { Text("Les entretiens déjà enregistrés restent dans l’historique.") }
    }

    private func save() {
        do {
            var changed = task
            changed.title = changed.title.trimmingCharacters(in: .whitespacesAndNewlines)
            changed.nextKilometers = hasKilometers ? MaintenanceInput.kilometers(kilometers) : nil
            changed.nextDate = hasDate ? date : nil
            changed.intervalKilometers = MaintenanceInput.kilometers(intervalKilometers)
            changed.intervalMonths = MaintenanceInput.kilometers(intervalMonths)
            guard (!hasKilometers || changed.nextKilometers != nil),
                  (intervalKilometers.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || changed.intervalKilometers != nil),
                  (intervalMonths.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || changed.intervalMonths != nil) else {
                throw MaintenanceError.invalidInput
            }
            try onSave(changed); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct MaintenanceCompletionForm: View {
    @Environment(\.dismiss) private var dismiss
    let task: MaintenanceTask
    let currentMileage: Int?
    let onSave: (Date, Int?, Int?, String) throws -> Void
    @State private var date = Date()
    @State private var kilometers: String
    @State private var cost = ""
    @State private var notes = ""
    @State private var error: String?

    init(task: MaintenanceTask, currentMileage: Int?, onSave: @escaping (Date, Int?, Int?, String) throws -> Void) {
        self.task = task; self.onSave = onSave
        self.currentMileage = currentMileage
        _kilometers = State(initialValue: currentMileage.map(String.init) ?? "")
    }

    var body: some View {
        RideSheet("Entretien effectué") {
            Text(task.title.rivetLocalized).font(.system(.title, design: .rounded).weight(.bold))
            RideCard {
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                MaintenanceNumberField(title: "Kilométrage lors de l’opération", placeholder: "Km au compteur", text: $kilometers)
                MaintenanceNumberField(title: "Coût en euros · facultatif", placeholder: "Ex. 89,90", text: $cost, decimal: true)
                TextField("Notes, pièces, nom de l’atelier…", text: $notes, axis: .vertical)
                    .lineLimit(3...8).textFieldStyle(.roundedBorder)
                Text("L’opération rejoint l’historique. Les intervalles que tu as renseignés recalculent la prochaine échéance.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
            }
            if let error { Text(LocalizedStringKey(error)).font(.caption).foregroundStyle(.red) }
            Button("C’est fait !", systemImage: "checkmark.circle.fill") {
                do {
                    let km = MaintenanceInput.kilometers(kilometers)
                    let cents = MaintenanceInput.costCents(cost)
                    guard (kilometers.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || km != nil),
                          (cost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cents != nil) else {
                        throw MaintenanceError.invalidInput
                    }
                    try onSave(date, km, cents, notes); dismiss()
                } catch { self.error = error.localizedDescription }
            }.buttonStyle(RideButtonStyle())
        }
        .onChange(of: currentMileage) { oldValue, newValue in
            if kilometers.isEmpty || kilometers == (oldValue.map(String.init) ?? "") {
                kilometers = newValue.map(String.init) ?? ""
            }
        }
    }
}

struct MaintenanceRecordView: View {
    let record: MaintenanceRecord
    var body: some View {
        RideSheet("Dans le carnet") {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(RideTheme.ink)
            Text(record.title.rivetLocalized).font(.system(.largeTitle, design: .rounded).weight(.bold))
            RideCard {
                Label(record.date.formatted(date: .long, time: .omitted), systemImage: "calendar")
                if let kilometers = record.kilometers { Label(kilometers.formatted() + " km", systemImage: "speedometer") }
                if let cost = record.costCents {
                    Label((Double(cost) / 100).formatted(.currency(code: "EUR")), systemImage: "eurosign.circle")
                }
                if !record.notes.isEmpty { Text(record.notes).textSelection(.enabled) }
                else { Text("Aucune note ajoutée.").foregroundStyle(RideTheme.muted) }
            }
        }
    }
}

private struct MaintenanceNumberField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var decimal = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title)).font(.subheadline.weight(.semibold))
            TextField(LocalizedStringKey(placeholder), text: $text).keyboardType(decimal ? .decimalPad : .numberPad)
                .textFieldStyle(.roundedBorder).accessibilityLabel(title)
        }
    }
}
