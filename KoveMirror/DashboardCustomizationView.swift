import SwiftUI
import UniformTypeIdentifiers

struct DashboardCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var layout: DashboardLayout
    let cockpitNumber: Int
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(layout.order) { widget in
                        HStack(spacing: 12) {
                            Image(systemName: widget.symbol).frame(width: 24).foregroundStyle(RideTheme.orange)
                            Toggle(LocalizedStringKey(widget.title), isOn: Binding(
                                get: { !layout.hidden.contains(widget) },
                                set: { value in var changed = layout; changed.setVisible(value, widget: widget); layout = changed }
                            ))
                        }
                        .padding(.vertical, 5)
                        .listRowBackground(RivetCockpit.panel)
                    }
                    .onMove { offsets, destination in
                        var changed = layout
                        changed.order.move(fromOffsets: offsets, toOffset: destination)
                        layout = changed
                    }
                } header: { Text("Cockpit \(cockpitNumber)") } footer: {
                    Text("Fais glisser les poignées pour déplacer les widgets. Les interrupteurs les affichent ou les masquent. Chaque cockpit garde sa disposition.")
                }
                Section {
                    Button("Rétablir cette disposition", role: .destructive) { confirmReset = true }
                        .listRowBackground(RivetCockpit.panel)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RivetCockpit.asphalt)
            .foregroundStyle(RivetCockpit.paper)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Ton cockpit, tes règles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() } } }
            .toolbarBackground(RivetCockpit.asphalt, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(RivetCockpit.lime)
            .confirmationDialog("Rétablir les widgets du cockpit \(cockpitNumber) ?", isPresented: $confirmReset) {
                Button("Rétablir", role: .destructive) { layout = .initial(second: cockpitNumber == 2) }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct DashboardWidgetContainer<Content: View>: View {
    let widget: DashboardWidget
    let editing: Bool
    @Binding var layout: DashboardLayout
    @Binding var dragging: DashboardWidget?
    let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(widget: DashboardWidget, editing: Bool, layout: Binding<DashboardLayout>,
         dragging: Binding<DashboardWidget?>, @ViewBuilder content: () -> Content) {
        self.widget = widget; self.editing = editing
        _layout = layout; _dragging = dragging; self.content = content()
    }

    var body: some View {
        if editing {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "line.3.horizontal").accessibilityHidden(true)
                    Text(LocalizedStringKey(widget.title)).font(.caption.weight(.bold))
                    Spacer()
                    Button {
                        var changed = layout; changed.setVisible(false, widget: widget); layout = changed
                    } label: { Image(systemName: "minus.circle.fill").frame(width: 44, height: 44) }
                        .accessibilityLabel("Masquer " + widget.title)
                }
                .foregroundStyle(RivetCockpit.lime)
                content.allowsHitTesting(false).accessibilityHidden(true)
            }
            .padding(12)
            .background(RivetCockpit.panel.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(RivetCockpit.lime.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6, 4])))
            .onDrag {
                dragging = widget
                return NSItemProvider(object: widget.rawValue as NSString)
            }
            .onDrop(of: [UTType.text], delegate: DashboardDropDelegate(target: widget, layout: $layout, dragging: $dragging,
                                                                     reduceMotion: reduceMotion))
            .accessibilityAction(named: "Monter le widget") { moveUp() }
            .accessibilityAction(named: "Descendre le widget") { moveDown() }
        } else {
            content
        }
    }

    private func moveUp() {
        guard let index = layout.visible.firstIndex(of: widget), index > 0 else { return }
        var changed = layout; changed.move(widget, before: layout.visible[index - 1]); layout = changed
    }
    private func moveDown() {
        guard let index = layout.visible.firstIndex(of: widget), index + 1 < layout.visible.count else { return }
        var changed = layout; changed.move(layout.visible[index + 1], before: widget); layout = changed
    }
}

private struct DashboardDropDelegate: DropDelegate {
    let target: DashboardWidget
    @Binding var layout: DashboardLayout
    @Binding var dragging: DashboardWidget?
    let reduceMotion: Bool

    func validateDrop(info: DropInfo) -> Bool { dragging != nil }
    func dropEntered(info: DropInfo) {
        guard let dragged = dragging, dragged != target else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            var changed = layout
            changed.move(dragged, over: target)
            layout = changed
        }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { dragging = nil; return true }
}
