import SwiftUI

struct NavigationAppIcon: View {
    let app: ProjectionShortcutTarget
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let asset = app.iconAssetName {
                Image(asset).resizable().renderingMode(.original).scaledToFit()
            } else {
                // iOS does not expose the icons of arbitrary installed apps.
                // A personal shortcut keeps its initials instead of a guessed logo.
                ZStack {
                    LinearGradient(colors: [RivetCockpit.raised, RivetCockpit.asphalt],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(initials).font(.system(size: size * 0.36, weight: .black, design: .rounded))
                        .foregroundStyle(RivetCockpit.lime)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .strokeBorder(.white.opacity(0.15), lineWidth: 0.7))
        .accessibilityHidden(true)
    }

    private var initials: String {
        let words = app.title.split(whereSeparator: { $0.isWhitespace })
        return String(words.prefix(2).compactMap(\.first)).uppercased()
    }
}
