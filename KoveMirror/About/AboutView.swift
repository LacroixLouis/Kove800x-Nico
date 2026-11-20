import SwiftUI

struct AboutView: View {
    var body: some View {
        RideSheet("À propos") {
            Image("RideMark").resizable().scaledToFit().frame(width: 130, height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 26))
            Text(RideTheme.appName).font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("Pour Nicolas Rivet · Kove 800X Rally").foregroundStyle(RideTheme.muted)
            RideCard {
                Label("Une interface à toi", systemImage: "motorcycle.fill").font(.headline)
                Text("Une navigation intégrée et un site web dans deux fenêtres échangeables. La petite fenêtre est envoyée au compteur. Retrouve aussi tes traces GPX, la météo et l’entretien de la moto.")
                Text("Version " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"))
                    .font(.caption).foregroundStyle(RideTheme.muted)
            }
            RideCard {
                Text("Crédits").font(.headline)
                Text("Adaptation personnelle de KoveMirror, créé par MapaX (Matti Mustonen). La licence MIT et les attributions d’origine sont conservées dans les sources.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
                Link("Projet KoveMirror d’origine", destination: URL(string: "https://github.com/MapaX/KoveMirror")!)
                Link("Données météo : Open-Meteo", destination: URL(string: "https://open-meteo.com")!)
                Text("Application indépendante ; elle n’est pas une application officielle de Kove, OsmAnd, Waze ou Wikiloc.")
                    .font(.caption).foregroundStyle(RideTheme.muted)
            }
        }
    }
}
