import SwiftUI

struct AppLanguageView: View {
    @AppStorage(RivetLanguage.preferenceKey) private var saved = RivetLanguage.system.rawValue
    var body: some View {
        RideSheet("Langue") {
            Text("À toi de choisir.").font(.system(.largeTitle, design: .rounded).weight(.bold))
            RideCard {
                ForEach(RivetLanguage.allCases) { language in
                    Button { saved = language.rawValue } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe").foregroundStyle(RideTheme.orange)
                            Text(language.name).font(.headline)
                            Spacer()
                            if RivetLanguage.saved(saved) == language {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(RideTheme.ink)
                            }
                        }
                        .padding(.vertical, 13).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("language." + language.rawValue)
                    .accessibilityAddTraits(RivetLanguage.saved(saved) == language ? [.isSelected] : [])
                    if language != RivetLanguage.allCases.last { Divider() }
                }
            }
            Text("Le changement s’applique tout de suite dans l’app. Tes widgets, ta connexion et ton carnet d’entretien sont conservés.")
                .font(.subheadline).foregroundStyle(RideTheme.muted)
        }
    }
}
