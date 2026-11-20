import SwiftUI

enum RideTheme {
    static let background = RivetCockpit.asphalt
    static let ink = RivetCockpit.paper
    static let orange = RivetCockpit.orange
    static let muted = RivetCockpit.secondary
    static let line = RivetCockpit.line
    static let soft = RivetCockpit.raised
    static let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Double Interface"
}

struct RideCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RivetCockpit.panel)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(RideTheme.line, lineWidth: 1))
    }
}

struct RideButtonStyle: ButtonStyle {
    var primary = true
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(primary ? RivetCockpit.asphalt : RivetCockpit.paper)
            .background(primary ? RivetCockpit.lime : RivetCockpit.raised)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.38)
    }
}

struct RideSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) { content }
                    .padding(20)
            }
            .background(RideTheme.background)
            .foregroundStyle(RideTheme.ink)
            .navigationTitle(Text(LocalizedStringKey(title)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }.fontWeight(.semibold)
                }
            }
            .toolbarBackground(RideTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(RivetCockpit.lime)
        .preferredColorScheme(.dark)
        .presentationBackground(RivetCockpit.asphalt)
    }
}

struct RideSectionTitle: View {
    let number: String
    let title: String
    var body: some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(RideTheme.orange)
                .padding(8).background(RideTheme.background).clipShape(Circle())
            Text(LocalizedStringKey(title)).font(.system(.title3, design: .rounded).weight(.bold))
        }
    }
}

struct RideStatusPill: View {
    let title: String
    let active: Bool
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(active ? RivetCockpit.lime : RideTheme.orange).frame(width: 7, height: 7)
            Text(LocalizedStringKey(title)).font(.caption.weight(.semibold))
        }
        .foregroundStyle(RideTheme.ink)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RivetCockpit.panel).clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

// Retained for the existing connection and map components.
extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255, opacity: 1)
    }
    func uiColor() -> UIColor { UIColor(self) }
}
