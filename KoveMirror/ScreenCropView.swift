import SwiftUI

struct ScreenCropView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = false
    @State private var left = 0.54
    @State private var top = 0.08
    @State private var width = 0.42
    @State private var height = 0.24
    @State private var keepAspect = true
    @State private var invalidSavedCrop = false
    @State private var selectionError = false

    private var screen: CGRect { UIScreen.main.bounds }

    var body: some View {
        RideSheet("Cadrage du TFT") {
            Text("Une fenêtre, tout le compteur.")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            RideCard {
                Toggle("Agrandir une zone de l’écran", isOn: $enabled)
                    .accessibilityIdentifier("framing.enabled")
                Text("Le TFT reçoit la zone choisie, agrandie à son format. Le reste de l’écran de l’iPhone reste hors de cette image.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
            }
            if enabled {
                RideCard {
                    Text("Zone à envoyer").font(.headline)
                    cropGuide
                    Text("Ce dessin est un repère de cadrage, pas une capture en direct.")
                        .font(.caption).foregroundStyle(RideTheme.muted)
                    ViewThatFits(in: .horizontal) {
                        HStack { cornerButtons }
                        VStack(alignment: .leading) { cornerButtons }
                    }
                    fractionSlider("Largeur", value: $width, range: 0.05...1, identifier: "framing.width")
                        .onChange(of: width) { _, value in left = min(left, 1 - value) }
                    fractionSlider("Hauteur", value: $height, range: 0.05...1, identifier: "framing.height")
                        .onChange(of: height) { _, value in top = min(top, 1 - value) }
                    fractionSlider("Depuis la gauche", value: Binding(
                        get: { left }, set: { left = min($0, 1 - width) }),
                        range: 0...max(0.001, 1 - width), identifier: "framing.left")
                        .disabled(width == 1)
                    fractionSlider("Depuis le haut", value: Binding(
                        get: { top }, set: { top = min($0, 1 - height) }),
                        range: 0...max(0.001, 1 - height), identifier: "framing.top")
                        .disabled(height == 1)
                    Toggle("Conserver les proportions", isOn: $keepAspect)
                    Text("Place la fenêtre flottante dans la zone indiquée. Si tu la déplaces ou changes sa taille, ajuste ce cadrage.")
                        .font(.caption).foregroundStyle(RideTheme.muted)
                    Text("Le cadrage est mémorisé pour l’orientation actuelle de l’iPhone.")
                        .font(.caption).foregroundStyle(RideTheme.muted)
                    Text("Une fenêtre plus grande sur le téléphone donne une image plus lisible sur le TFT.")
                        .font(.caption).foregroundStyle(RideTheme.muted)
                }
                RideCard {
                    Label("La fenêtre doit déjà être visible", systemImage: "rectangle.inset.filled")
                        .font(.headline)
                    Text("L’application GPS doit proposer son propre mode fenêtre flottante. Ce réglage agrandit une zone visible ; il ne crée pas ce mode dans Waze ou OsmAnd.")
                        .font(.subheadline).foregroundStyle(RideTheme.muted)
                }
            } else {
                Text("L’ensemble de l’écran visible de l’iPhone est diffusé en mode miroir.")
                    .font(.subheadline).foregroundStyle(RideTheme.muted)
            }
            if invalidSavedCrop {
                Text("Le cadrage enregistré était invalide. Enregistre un nouveau réglage pour reprendre l’envoi.")
                    .foregroundStyle(RideTheme.orange).font(.subheadline)
            }
            if selectionError {
                Text("La zone choisie est invalide. Ajuste sa position et sa taille.")
                    .foregroundStyle(RideTheme.orange).font(.subheadline)
            }
            Button("Appliquer au TFT", systemImage: "checkmark", action: apply)
                .buttonStyle(RideButtonStyle())
                .accessibilityIdentifier("framing.apply")
        }
        .onAppear(perform: load)
    }

    private var cropGuide: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18).fill(RivetCockpit.asphalt)
                RoundedRectangle(cornerRadius: 18).strokeBorder(RivetCockpit.secondary.opacity(0.5))
                RoundedRectangle(cornerRadius: 8)
                    .fill(RivetCockpit.lime.opacity(0.25))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(RivetCockpit.lime, lineWidth: 2))
                    .frame(width: CGFloat(width) * geometry.size.width,
                           height: CGFloat(height) * geometry.size.height)
                    .offset(x: CGFloat(left) * geometry.size.width, y: CGFloat(top) * geometry.size.height)
            }
        }
        .aspectRatio(screen.width / max(1, screen.height), contentMode: .fit)
        .frame(maxHeight: 360)
        .accessibilityLabel("Repère de la zone envoyée au TFT")
    }

    @ViewBuilder private var cornerButtons: some View {
        Button("Haut gauche") { place(right: false, bottom: false) }
        Button("Haut droit") { place(right: true, bottom: false) }
        Button("Bas gauche") { place(right: false, bottom: true) }
        Button("Bas droit") { place(right: true, bottom: true) }
    }

    private func place(right: Bool, bottom: Bool) {
        left = right ? max(0, 1 - width - 0.03) : min(0.03, 1 - width)
        top = bottom ? max(0, 1 - height - 0.03) : min(0.03, 1 - height)
    }

    private func fractionSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LocalizedStringKey(title))
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded())) %").monospacedDigit()
            }.font(.subheadline)
            Slider(value: value, in: range)
                .accessibilityLabel(Text(LocalizedStringKey(title)))
                .accessibilityIdentifier(identifier)
        }
    }

    private func load() {
        keepAspect = KoveScreenPreset.keepAspectRatio
        switch KoveScreenPreset.broadcastFraming {
        case .fullScreen: enabled = false
        case .invalid: enabled = true; invalidSavedCrop = true
        case .window(let crop):
            enabled = true
            left = crop.left
            top = crop.top
            width = max(0.05, crop.width)
            height = max(0.05, crop.height)
            left = min(left, 1 - width)
            top = min(top, 1 - height)
        }
    }

    private func apply() {
        if enabled {
            let orientation: ScreenCrop.Orientation = screen.height >= screen.width ? .portrait : .landscape
            guard let crop = ScreenCrop(left: left, top: top, width: width, height: height,
                                        orientation: orientation) else { selectionError = true; return }
            KoveScreenPreset.broadcastFraming = .window(crop)
            KoveScreenPreset.keepAspectRatio = keepAspect
        } else { KoveScreenPreset.broadcastFraming = .fullScreen }
        dismiss()
    }
}
