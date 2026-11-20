import SwiftUI

struct AddNavigationShortcutView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(NavigationAppChoice.shortcutsKey) private var enabledApps = NavigationAppChoice.defaultShortcuts
    let onAdd: (UserNavigationShortcut) -> Void
    @State private var title = ""

    var body: some View {
        RideSheet("Ajouter une appli") {
            Text("Choisis ton application.")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            RideCard {
                ForEach(NavigationAppChoice.allCases) { app in
                    let added = NavigationAppChoice.shortcuts(in: enabledApps).contains(app)
                    Button {
                        enabledApps = NavigationAppChoice.setting(app, enabled: true, in: enabledApps)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            NavigationAppIcon(app: .builtIn(app), size: 42)
                            Text(app.title).font(.headline)
                            Spacer()
                            Image(systemName: added ? "checkmark.circle.fill" : "plus.circle.fill")
                        }
                        .padding(.vertical, 10).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(added)
                    .accessibilityIdentifier("addApp." + app.rawValue)
                    .accessibilityValue(added ? "Déjà ajoutée" : "Ajouter")
                    if app != NavigationAppChoice.allCases.last { Divider() }
                }
            }
            RideCard {
                Text("Une autre application ?").font(.headline)
                TextField("Son nom", text: $title)
                    .textInputAutocapitalization(.words)
                    .padding(12).background(RideTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("addApp.name")
                Text("Ajoute son nom ici. Pendant la diffusion, ouvre-la normalement depuis l’accueil de l’iPhone.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
                Button("Ajouter", systemImage: "plus") {
                    guard let item = UserNavigationShortcut(title: title) else { return }
                    onAdd(item)
                    dismiss()
                }
                .buttonStyle(RideButtonStyle())
                .disabled(UserNavigationShortcut(title: title) == nil)
                .accessibilityIdentifier("addApp.save")
            }
        }
    }
}

struct ManualAppOpenView: View {
    let title: String
    let forSetup: Bool
    var keepsTFT = false

    var body: some View {
        RideSheet(String(format: "Ouvrir %@".rivetLocalized, title)) {
            Text(LocalizedStringKey(forSetup ? "Ouvre ton application."
                : (keepsTFT ? "Le TFT garde sa vue Double Interface." : "La diffusion est prête.")))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            RideCard {
                Image(systemName: "hand.draw.fill").font(.largeTitle).foregroundStyle(RideTheme.orange)
                Text(String(format: "Reviens à l’accueil de l’iPhone, puis touche %@.".rivetLocalized, title))
                    .font(.title3.weight(.semibold))
                if keepsTFT {
                    Text("La vue Double Interface reste sur le TFT pendant que tu utilises ton application sur l’iPhone.")
                        .foregroundStyle(RideTheme.muted)
                } else if !forSetup {
                    Text("La diffusion suit automatiquement l’application que tu ouvres.")
                        .foregroundStyle(RideTheme.muted)
                }
            }
        }
    }
}
