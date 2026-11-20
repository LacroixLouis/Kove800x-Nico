import SwiftUI
import ReplayKit

struct NavigationAppGrid: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let apps: [ProjectionShortcutTarget]
    let selectedValue: String
    var keepsIndependentTFT = false
    let onOpen: (ProjectionShortcutTarget) -> Void
    let onConfigure: (ProjectionShortcutTarget) -> Void
    var onAdd: (() -> Void)? = nil

    var body: some View {
        LazyVGrid(columns: typeSize.isAccessibilitySize
            ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(apps) { app in
                appButton(app)
            }
            if let onAdd {
                Button(action: onAdd) {
                    VStack(alignment: .leading, spacing: 18) {
                        Image(systemName: "plus").font(.system(size: 23, weight: .medium))
                            .frame(width: 52, height: 52)
                            .background(RivetCockpit.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Une app de plus ?").font(.system(.headline, design: .rounded))
                            Text("Compose ton cockpit").font(.caption)
                                .foregroundStyle(RivetCockpit.secondary)
                        }
                    }
                    .foregroundStyle(RivetCockpit.orange)
                    .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
                    .padding(16)
                    .background(RivetCockpit.orange.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(RivetCockpit.orange.opacity(0.38), style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
                }
                .buttonStyle(RivetPressStyle())
                .accessibilityLabel("Ajouter une application")
                .accessibilityIdentifier("projectionApp.add")
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: selectedValue)
    }

    private func appButton(_ app: ProjectionShortcutTarget) -> some View {
        let selected = selectedValue == app.id
        return Button { onOpen(app) } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    NavigationAppIcon(app: app)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    Spacer(minLength: 4)
                    Image(systemName: selected ? "checkmark.circle.fill" : "arrow.up.right")
                        .font(.system(size: selected ? 23 : 16, weight: .semibold))
                        .foregroundStyle(selected ? RivetCockpit.lime : RivetCockpit.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.title).font(.system(.headline, design: .rounded).weight(.bold))
                        .lineLimit(2)
                    Text(LocalizedStringKey(app.subtitle)).font(.caption).fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(RivetCockpit.secondary)
                }
                if selected {
                    Text("À AFFICHER").font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.2).foregroundStyle(RivetCockpit.lime)
                }
            }
            .foregroundStyle(RivetCockpit.paper)
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
            .padding(16)
            .background(selected ? RivetCockpit.raised : RivetCockpit.panel)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24)
                .strokeBorder(selected ? RivetCockpit.lime : RivetCockpit.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(RivetPressStyle())
        .contextMenu {
            Button("Ouvrir pour régler", systemImage: "gearshape") { onConfigure(app) }
        }
        .accessibilityIdentifier("projectionApp." + app.id)
        .accessibilityLabel(app.title)
        .accessibilityValue(selected ? "Sélectionnée" : "Non sélectionnée")
        .accessibilityHint(app.requiresManualOpen
            ? (keepsIndependentTFT ? "Prépare la vue Double Interface du TFT puis indique d’ouvrir l’app sur l’iPhone."
               : "Prépare la diffusion puis indique d’ouvrir l’app sur l’iPhone.")
            : (keepsIndependentTFT ? "Ouvre cette application sur l’iPhone en gardant la vue Double Interface du TFT."
               : "Ouvre cette application pour la diffuser sur le compteur."))
    }
}

/// The same launch actions as the home cockpit, reachable from the screen settings.
struct ProjectionAppPicker: View {
    let apps: [ProjectionShortcutTarget]
    let selectedValue: String
    let openingApp: Bool
    var independentTFTTitle: String? = nil
    var phoneSelection = false
    let onOpen: (ProjectionShortcutTarget) -> Void
    let onConfigure: (ProjectionShortcutTarget) -> Void
    let onManage: () -> Void

    var body: some View {
        RideSheet("Choisir une application") {
            Text(LocalizedStringKey(phoneSelection || independentTFTTitle != nil
                ? "Ton application sur l’iPhone." : "Ton application sur le TFT."))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            RideCard {
                Label(LocalizedStringKey(independentTFTTitle != nil ? "Une app iPhone, une vue Double Interface sur le TFT"
                    : (phoneSelection ? "Choisir pour le téléphone" : "La même app sur les deux écrans")),
                      systemImage: "rectangle.on.rectangle")
                    .font(.headline)
                if let independentTFTTitle {
                    Text("TFT : " + independentTFTTitle).font(.headline).foregroundStyle(RivetCockpit.orange)
                    Text("L’app s’ouvre sur l’iPhone. Le TFT conserve la vue Double Interface choisie, sans recopier l’écran du téléphone.")
                        .foregroundStyle(RideTheme.muted)
                } else if phoneSelection {
                    Text("Touche l’application à ouvrir sur ton iPhone.")
                        .foregroundStyle(RideTheme.muted)
                    Text("Si le miroir est actif, le TFT suit aussi l’écran visible de l’iPhone.")
                        .font(.subheadline).foregroundStyle(RideTheme.muted)
                } else {
                    Text("Touche une application pour l’ouvrir et l’afficher sur le compteur. La connexion et la diffusion existantes sont réutilisées.")
                        .foregroundStyle(RideTheme.muted)
                    Text("Le TFT suit l’écran de l’iPhone. Ce mode ne permet pas d’afficher deux applications différentes en même temps.")
                        .font(.subheadline).foregroundStyle(RideTheme.muted)
                }
            }
            NavigationAppGrid(apps: apps, selectedValue: selectedValue,
                keepsIndependentTFT: independentTFTTitle != nil,
                onOpen: onOpen, onConfigure: onConfigure, onAdd: onManage)
                .disabled(openingApp)
            Button("Ajouter ou retirer une application", systemImage: "plus.circle", action: onManage)
                .buttonStyle(RideButtonStyle(primary: false))
                .disabled(openingApp)
                .accessibilityIdentifier("projectionPicker.manage")
            Text("Maintiens une icône pour ouvrir l’app et la régler sans connecter la moto. DMD HUB et les apps sans raccourci s’ouvrent manuellement sur l’iPhone.")
                .font(.caption).foregroundStyle(RideTheme.muted)
        }
    }
}

struct NavigationAppMenu: View {
    @AppStorage(NavigationAppChoice.shortcutsKey) private var shortcutsValue = NavigationAppChoice.defaultShortcuts
    @AppStorage(UserNavigationShortcut.preferenceKey) private var customValue = "[]"
    @State private var addingApp = false
    let onOpenForSetup: (ProjectionShortcutTarget) -> Void
    var onChooseForDisplay: (() -> Void)? = nil

    var body: some View {
        RideSheet("Mes applications") {
            if let onChooseForDisplay {
                Button("Afficher une app sur le TFT", systemImage: "display", action: onChooseForDisplay)
                    .buttonStyle(RideButtonStyle())
            }
            Button("Ajouter une appli", systemImage: "plus.circle.fill") { addingApp = true }
                .buttonStyle(RideButtonStyle())
                .disabled(UserNavigationShortcut.load(customValue).count >= 50)
                .accessibilityIdentifier("apps.add")
            RideCard {
                ForEach(NavigationAppChoice.shortcuts(in: shortcutsValue)) { app in
                    appRow(.builtIn(app)) {
                        shortcutsValue = NavigationAppChoice.setting(app, enabled: false, in: shortcutsValue)
                    }
                    Divider()
                }
                ForEach(UserNavigationShortcut.load(customValue)) { item in
                    appRow(.custom(item)) {
                        customValue = UserNavigationShortcut.encode(UserNavigationShortcut.load(customValue).filter { $0.id != item.id })
                    }
                    Divider()
                }
                if NavigationAppChoice.shortcuts(in: shortcutsValue).isEmpty && UserNavigationShortcut.load(customValue).isEmpty {
                    Text("Ajoute tes applis avec le bouton au-dessus.").foregroundStyle(RideTheme.muted)
                }
            }
            Text("Un toucher sur un nom permet d’ouvrir l’appli pour la régler.")
                .font(.caption).foregroundStyle(RideTheme.muted)
        }
        .sheet(isPresented: $addingApp) {
            AddNavigationShortcutView { item in
                var items = UserNavigationShortcut.load(customValue)
                guard items.count < 50 else { return }
                items.append(item)
                customValue = UserNavigationShortcut.encode(items)
            }
        }
    }

    private func appRow(_ app: ProjectionShortcutTarget, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button { onOpenForSetup(app) } label: {
                HStack(spacing: 12) {
                    NavigationAppIcon(app: app, size: 42)
                    Text(app.title).font(.headline)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.caption.weight(.bold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(role: .destructive, action: remove) {
                Image(systemName: "minus.circle").padding(10)
            }
            .accessibilityLabel("Retirer " + app.title)
        }
    }
}

/// A visible system control: iOS owns consent and the start/stop countdown.
/// Discovering the embedded extension also respects a user's signing identifier.
struct ScreenBroadcastControl: UIViewRepresentable {
    var enabled = true
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 48, height: 48))
        picker.preferredExtension = Self.extensionIdentifier
        picker.showsMicrophoneButton = false
        picker.tintColor = RivetCockpit.lime.uiColor()
        picker.isUserInteractionEnabled = enabled
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        uiView.isUserInteractionEnabled = enabled
    }

    private static var extensionIdentifier: String? { broadcastExtension?.bundleIdentifier }
    static var serviceName: String {
        broadcastExtension?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "Double Interface"
    }

    private static var broadcastExtension: Bundle? {
        guard let directory = Bundle.main.builtInPlugInsURL,
              let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return nil }
        return contents.filter { $0.pathExtension == "appex" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { Bundle(url: $0) }
            .first {
                let info = $0.object(forInfoDictionaryKey: "NSExtension") as? [String: Any]
                return info?["NSExtensionPointIdentifier"] as? String == "com.apple.broadcast-services-upload"
            }
    }
}
