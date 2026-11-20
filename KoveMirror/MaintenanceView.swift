import SwiftUI
import UniformTypeIdentifiers

private enum MaintenancePage: String { case schedule, history }
private enum MaintenanceSheet: Identifiable {
    case motorcycle, edit(MaintenanceTask), complete(MaintenanceTask), record(MaintenanceRecord)
    var id: String {
        switch self {
        case .motorcycle: return "motorcycle"
        case .edit(let task): return "edit:" + task.id.uuidString
        case .complete(let task): return "complete:" + task.id.uuidString
        case .record(let record): return "record:" + record.id.uuidString
        }
    }
}

struct MaintenanceView: View {
    @ObservedObject var bleController: BleController
    @Environment(\.dismiss) private var dismiss
    @AppStorage(MotorcycleMaintenance.preferenceKey) private var saved = ""
    @State private var page = MaintenancePage.schedule
    @State private var sheet: MaintenanceSheet?
    @State private var exporting = false
    @State private var exportItems: [Any] = []
    @State private var importing = false
    @State private var incomingBackup: MotorcycleMaintenance?
    @State private var confirmRestore = false
    @State private var confirmMotorcycleAssociation = false
    @State private var message: String?
    private var garage: MotorcycleMaintenance { .load(saved) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    motorcycleHeader
                    Picker("Afficher", selection: $page) {
                        Text("Échéances").tag(MaintenancePage.schedule)
                        Text("Historique").tag(MaintenancePage.history)
                    }.pickerStyle(.segmented)
                    if page == .schedule { schedule } else { history }
                    Text("Les échéances sont celles que tu renseignes d’après ton carnet d’entretien. « Bientôt » : 250 km ou 14 jours restants. Le premier terme atteint s’applique.")
                        .font(.caption).foregroundStyle(RivetCockpit.secondary)
                }.padding(20)
            }
            .background(RivetCockpit.asphalt).foregroundStyle(RivetCockpit.paper)
            .navigationTitle("L’atelier Double Interface").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Modifier la moto", systemImage: "motorcycle") { sheet = .motorcycle }
                        if bleController.connectionState == .connected,
                           let incoming = bleController.motorcycleOdometer, let saved = garage.odometer,
                           incoming.peripheralID != saved.peripheralID {
                            Button("Associer le carnet à cette moto", systemImage: "link") { confirmMotorcycleAssociation = true }
                        }
                        Button("Sauvegarder le suivi", systemImage: "square.and.arrow.up") { export(backup: true) }
                        Button("Exporter l’historique CSV", systemImage: "tablecells") { export(backup: false) }
                        Button("Restaurer une sauvegarde", systemImage: "square.and.arrow.down") { importing = true }
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                    .accessibilityLabel("Options d’entretien")
                }
            }
            .toolbarBackground(RivetCockpit.asphalt, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(RivetCockpit.lime).preferredColorScheme(.dark)
        .onAppear {
            if saved.isEmpty { saved = (try? MotorcycleMaintenance().encoded()) ?? "" }
            if bleController.connectionState == .connected { bleController.requestMileage() }
        }
        .sensoryFeedback(.success, trigger: garage.records.count)
        .sheet(item: $sheet) { item in
            switch item {
            case .motorcycle:
                MaintenanceMotorcycleForm(garage: garage) { name in
                    var changed = garage; changed.motorcycleName = name
                    try persist(changed)
                }
            case .edit(let task):
                MaintenanceTaskForm(task: task, canDelete: garage.tasks.contains(where: { $0.id == task.id }), onSave: { task in
                    var changed = garage; try changed.saveTask(task); try persist(changed)
                }, onDelete: {
                    var changed = garage; changed.tasks.removeAll { $0.id == task.id }; try persist(changed)
                })
            case .complete(let task):
                MaintenanceCompletionForm(task: task, currentMileage: garage.mileage) { date, kilometers, cost, notes in
                    var changed = garage
                    try changed.complete(taskID: task.id, date: date, kilometers: kilometers, costCents: cost, notes: notes)
                    try persist(changed)
                }
            case .record(let record): MaintenanceRecordView(record: record)
            }
        }
        .sheet(isPresented: $exporting) { ActivityViewController(activityItems: exportItems) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 8_000_000 else { throw MaintenanceError.invalidBackup }
                incomingBackup = try MotorcycleMaintenance.decodeBackup(Data(contentsOf: url))
                confirmRestore = true
            } catch { message = error.localizedDescription }
        }
        .confirmationDialog("Remplacer le suivi actuel par cette sauvegarde ?", isPresented: $confirmRestore) {
            Button("Remplacer le suivi", role: .destructive) {
                guard let backup = incomingBackup else { return }
                do { try persist(backup) } catch { message = error.localizedDescription }
                incomingBackup = nil
            }
            Button("Annuler", role: .cancel) { incomingBackup = nil }
        } message: { Text("Les échéances et l’historique actuels seront remplacés. Sauvegarde-les avant de continuer si tu souhaites les conserver.") }
        .confirmationDialog("Utiliser le kilométrage de la moto connectée pour ce carnet ?", isPresented: $confirmMotorcycleAssociation) {
            Button("Associer le carnet à cette moto") {
                guard bleController.connectionState == .connected,
                      let reading = bleController.motorcycleOdometer else { return }
                var changed = garage
                changed.odometer = nil
                changed.synchronizeOdometer(reading)
                do {
                    try persist(changed)
                    bleController.requestMileage()
                } catch { message = error.localizedDescription }
            }
            Button("Annuler", role: .cancel) { }
        }
        .alert("Entretien", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(LocalizedStringKey(message ?? "")) }
    }

    private var motorcycleHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("MA MOTO", systemImage: "motorcycle.fill")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced)).tracking(1.5)
                Spacer()
                Button("Modifier") { sheet = .motorcycle }.font(.caption.weight(.bold))
            }.foregroundStyle(RivetCockpit.lime)
            Text(garage.motorcycleName).font(.system(.title, design: .rounded).weight(.heavy))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(garage.mileage.map { $0.formatted() } ?? "—")
                    .font(.system(size: 42, weight: .heavy, design: .rounded)).monospacedDigit()
                Text(LocalizedStringKey(garage.mileage == nil ? "En attente du compteur" : "km au compteur"))
                    .font(.caption).foregroundStyle(RivetCockpit.secondary)
            }
            if let reading = garage.odometer {
                Label(LocalizedStringKey(bleController.connectionState == .connected && bleController.motorcycleOdometer == reading
                      ? "Kilométrage reçu de la moto" : "Dernière lecture du compteur"),
                      systemImage: "motorcycle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(RivetCockpit.lime)
                Text(reading.receivedAt, format: .dateTime.day().month().hour().minute())
                    .font(.caption).foregroundStyle(RivetCockpit.secondary)
            } else {
                Text("Le kilométrage se synchronise automatiquement à la connexion Bluetooth de la moto.")
                    .font(.caption).foregroundStyle(RivetCockpit.secondary)
            }
            if let message = bleController.mileageSyncMessage {
                Text(message.rivetLocalized).font(.caption).foregroundStyle(RivetCockpit.orange)
            }
            Button("Actualiser depuis la moto", systemImage: "arrow.clockwise") { bleController.requestMileage() }
                .font(.subheadline.weight(.semibold))
                .disabled(bleController.connectionState != .connected)
            HStack(spacing: 12) {
                Label("\(garage.attentionCount()) à surveiller", systemImage: "clock")
                Spacer(minLength: 0)
                Label("\(garage.records.count) effectuées", systemImage: "checkmark.circle")
            }.font(.caption.weight(.semibold)).foregroundStyle(RivetCockpit.secondary)
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background { ZStack { RivetCockpit.raised; RivetContours() } }
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var schedule: some View {
        VStack(spacing: 12) {
            ForEach(garage.orderedTasks()) { task in
                MaintenanceTaskCard(task: task, mileage: garage.mileage,
                    onEdit: { sheet = .edit(task) }, onComplete: { sheet = .complete(task) })
            }
            if garage.tasks.isEmpty {
                Text("Ton carnet est prêt. Ajoute la première opération.")
                    .foregroundStyle(RivetCockpit.secondary).padding(24)
            }
            Button("Ajouter une opération", systemImage: "plus.circle.fill") {
                sheet = .edit(MaintenanceTask(title: "", category: .general))
            }
            .font(.headline).foregroundStyle(RivetCockpit.asphalt)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RivetCockpit.lime).clipShape(RoundedRectangle(cornerRadius: 16))
            .buttonStyle(RivetPressStyle()).disabled(garage.tasks.count >= 100)
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Coûts renseignés").font(.subheadline)
                Spacer()
                Text((Double(garage.totalCostCents) / 100).formatted(.currency(code: "EUR")))
                    .font(.system(.title3, design: .rounded).weight(.bold))
            }.foregroundStyle(RivetCockpit.lime).padding(.vertical, 8)
            if garage.records.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "checkmark.seal").font(.largeTitle).foregroundStyle(RivetCockpit.lime)
                    Text("Chaque soin compte.").font(.title3.bold())
                    Text("Enregistre une opération avec « Fait ». Tu retrouveras ici la date, le kilométrage, le prix et tes notes.")
                        .font(.subheadline).foregroundStyle(RivetCockpit.secondary)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RivetCockpit.panel).clipShape(RoundedRectangle(cornerRadius: 24))
            }
            ForEach(garage.history) { record in
                Button { sheet = .record(record) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: record.category.symbol).foregroundStyle(RivetCockpit.lime).frame(width: 26)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.title.rivetLocalized).font(.headline)
                            Text(record.date, format: .dateTime.day().month().year())
                                .font(.caption).foregroundStyle(RivetCockpit.secondary)
                            if let kilometers = record.kilometers {
                                Text(kilometers.formatted() + " km").font(.caption).foregroundStyle(RivetCockpit.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(RivetCockpit.secondary)
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RivetCockpit.panel).clipShape(RoundedRectangle(cornerRadius: 20))
                }.foregroundStyle(RivetCockpit.paper).buttonStyle(RivetPressStyle())
            }
        }
    }

    private func persist(_ value: MotorcycleMaintenance) throws {
        var changed = value
        if let reading = bleController.motorcycleOdometer { changed.synchronizeOdometer(reading) }
        saved = try changed.encoded()
    }

    private func export(backup: Bool) {
        do {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("Double-Interface-Entretien-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(backup ? "Entretien-Double-Interface.json" : "Historique-Double-Interface.csv")
            let data = backup ? try garage.encodedData() : Data(("\u{FEFF}" + garage.historyCSV).utf8)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            exportItems = [url]; exporting = true
        } catch { message = error.localizedDescription }
    }
}

private struct MaintenanceTaskCard: View {
    let task: MaintenanceTask
    let mileage: Int?
    let onEdit: () -> Void
    let onComplete: () -> Void
    private var due: MaintenanceDue { MaintenanceDue(task: task, mileage: mileage) }
    private var color: Color { due.urgency <= .due ? RivetCockpit.orange : RivetCockpit.lime }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: task.category.symbol).font(.title3)
                    .foregroundStyle(color).frame(width: 42, height: 42)
                    .background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title.rivetLocalized).font(.system(.headline, design: .rounded))
                    Text(LocalizedStringKey(due.urgency.title)).font(.caption.weight(.bold))
                        .foregroundStyle(task.isConfigured ? color : RivetCockpit.secondary)
                }
                Spacer(minLength: 0)
            }
            if let target = task.nextKilometers {
                Label(target.formatted() + " km", systemImage: "speedometer")
                    .font(.subheadline.weight(.semibold))
                if let remaining = due.kilometersRemaining {
                    Text(String(format: (remaining < 0 ? "%@ km dépassés" : "Dans %@ km").rivetLocalized, abs(remaining).formatted()))
                        .font(.caption).foregroundStyle(remaining < 0 ? RivetCockpit.orange : RivetCockpit.secondary)
                }
            }
            if let date = task.nextDate {
                Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption).foregroundStyle(RivetCockpit.secondary)
            }
            if !task.isConfigured {
                Text("Ajoute une échéance en kilomètres ou une date.")
                    .font(.caption).foregroundStyle(RivetCockpit.secondary)
            }
            if let last = task.lastDate {
                Text("Dernier entretien : \(last.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2).foregroundStyle(RivetCockpit.secondary)
            }
            HStack(spacing: 10) {
                Button("Échéance", systemImage: "slider.horizontal.3", action: onEdit)
                    .frame(maxWidth: .infinity, minHeight: 44).background(.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12)).foregroundStyle(RivetCockpit.paper)
                Button("Fait", systemImage: "checkmark", action: onComplete)
                    .frame(maxWidth: .infinity, minHeight: 44).background(RivetCockpit.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 12)).foregroundStyle(RivetCockpit.asphalt)
            }.font(.subheadline.weight(.bold)).buttonStyle(RivetPressStyle())
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(RivetCockpit.panel).clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(RivetCockpit.line))
    }
}
