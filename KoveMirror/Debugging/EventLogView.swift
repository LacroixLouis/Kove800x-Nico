import SwiftUI

struct EventLogView: View {
    @ObservedObject var bleController: BleController
    @State private var search = ""
    @State private var copied = false

    private var lines: [String] {
        bleController.logMessages.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        RideSheet("Journal de connexion") {
            HStack {
                Text("\(bleController.logMessages.count) événements").font(.headline)
                Spacer()
                Button(copied ? "Copié" : "Copier") {
                    UIPasteboard.general.setItems([["public.utf8-plain-text": lines.joined(separator: "\n")]],
                        options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(300)])
                    copied = true
                }
            }
            TextField("Rechercher dans le journal", text: $search)
                .padding(14).background(RivetCockpit.panel).clipShape(RoundedRectangle(cornerRadius: 14))
            RideCard {
                if lines.isEmpty {
                    Text("Aucun événement à afficher.").foregroundStyle(RideTheme.muted)
                } else {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Divider()
                    }
                }
            }
        }
    }
}
