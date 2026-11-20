import SwiftUI

/// Shared palette for the cockpit, settings, forms and navigation controls.
enum RivetCockpit {
    static let asphalt = Color(hex: "101A18")
    static let panel = Color(hex: "1B2925")
    static let raised = Color(hex: "243830")
    static let paper = Color(hex: "F3F2E7")
    static let lime = Color(hex: "D2F36B")
    static let orange = Color(hex: "FF794F")
    static let secondary = Color(hex: "B4C3B7")
    static let line = Color.white.opacity(0.12)
}

struct RivetPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.72),
                       value: configuration.isPressed)
    }
}

/// Decorative contours, not a map or a recorded route. No location access.
struct RivetContours: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<11 {
                let shift = CGFloat(index) * 19
                var contour = Path()
                contour.move(to: CGPoint(x: size.width * 0.56 + shift, y: -35))
                contour.addCurve(to: CGPoint(x: size.width + 35, y: size.height * 0.8 + shift),
                    control1: CGPoint(x: size.width * 0.20 + shift, y: size.height * 0.64),
                    control2: CGPoint(x: size.width * 1.12 - shift, y: size.height * 0.17))
                context.stroke(contour, with: .color(RivetCockpit.lime.opacity(0.10)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct RivetSectionHeading: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(eyebrow)).font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2).foregroundStyle(RivetCockpit.secondary)
            Text(LocalizedStringKey(title)).font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(RivetCockpit.paper)
        }
    }
}

struct RivetDockButton: View {
    let title: String
    let symbol: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 19, weight: .semibold))
                Text(LocalizedStringKey(title)).font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(selected ? RivetCockpit.lime : RivetCockpit.secondary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(RivetPressStyle())
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
