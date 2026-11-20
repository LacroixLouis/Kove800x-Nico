import SwiftUI

/// These are saved display choices and real transport states, not TFT screenshots.
struct DualScreenOverview: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let phoneTitle: String
    let tftTitle: String
    let modeTitle: String
    let videoConnected: Bool
    let activeVideoTitle: String?
    let onPhone: () -> Void
    let onTFT: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MES DEUX ÉCRANS")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(2).foregroundStyle(RivetCockpit.lime)
                    Text(LocalizedStringKey(modeTitle))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                }
                Spacer(minLength: 0)
                Image(systemName: "rectangle.on.rectangle")
                    .font(.title2).foregroundStyle(RivetCockpit.lime)
            }
            LazyVGrid(columns: typeSize >= .xxxLarge
                ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                screenTile(title: "iPhone", content: phoneTitle, symbol: "iphone", accent: RivetCockpit.lime,
                           hint: "Ouvrir la vue choisie sur le téléphone", action: onPhone)
                screenTile(title: "TFT Kove", content: tftTitle, symbol: "display", accent: RivetCockpit.orange,
                           hint: "Régler le contenu du compteur", action: onTFT)
            }
            HStack(spacing: 10) {
                Circle().fill(videoConnected ? RivetCockpit.lime : RivetCockpit.orange)
                    .frame(width: 7, height: 7).accessibilityHidden(true)
                Text(LocalizedStringKey(videoConnected ? "Canal vidéo connecté" : "En attente du TFT"))
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: videoConnected ? "link" : "wifi.slash")
                    .font(.caption.weight(.bold)).foregroundStyle(RivetCockpit.secondary)
            }
            .foregroundStyle(RivetCockpit.secondary)
            if videoConnected, let activeVideoTitle {
                Text("Source vidéo : ".rivetLocalized + activeVideoTitle.rivetLocalized)
                    .font(.caption2).foregroundStyle(RivetCockpit.secondary)
            }
        }
        .padding(20)
        .background {
            ZStack {
                LinearGradient(colors: [RivetCockpit.raised, RivetCockpit.panel],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RivetContours().opacity(0.6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(RivetCockpit.lime.opacity(0.22)))
    }

    private func screenTile(title: String, content: String, symbol: String, accent: Color,
                            hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Image(systemName: symbol)
                        .font(.system(size: 35, weight: .light))
                        .foregroundStyle(accent).frame(height: 48)
                    Spacer(minLength: 2)
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                        .foregroundStyle(RivetCockpit.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(title)).font(.system(.headline, design: .rounded))
                    Text("CONTENU CHOISI")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1).foregroundStyle(RivetCockpit.secondary)
                    Text(content).font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
            .padding(16).foregroundStyle(RivetCockpit.paper)
            .background(RivetCockpit.asphalt.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(accent.opacity(0.18)))
        }
        .buttonStyle(RivetPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(LocalizedStringKey(hint)))
    }
}
