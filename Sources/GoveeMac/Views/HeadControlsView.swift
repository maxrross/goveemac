import SwiftUI
import GoveeKit
import ShadcnUI

struct HeadControlsView: View {
    let store: LightStore
    let device: LightDevice
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Individual heads").font(.headline)
                Spacer()
                Text("Brightness is relative to the whole lamp").font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 215), spacing: 12)], spacing: 12) {
                ForEach(device.heads.reversed()) { head in HeadControlCard(store: store, device: device, head: head) }
            }
        }
    }
}
private struct HeadControlCard: View {
    let store: LightStore
    let device: LightDevice
    let head: LightHeadState
    @State private var draft: LightHeadState
    @State private var hex: String
    @State private var hexEdited = false
    @State private var editingBrightness = false
    private let colors = [RGB(255,0,0), RGB(73,200,133), RGB(36,165,255), RGB(174,107,255)]
    init(store: LightStore, device: LightDevice, head: LightHeadState) {
        self.store = store; self.device = device; self.head = head
        _draft = State(initialValue: head); _hex = State(initialValue: head.color.hex)
    }
    private var label: String { DeviceCatalog.headName(model: device.model, index: head.id) }
    var body: some View {
        ControlPanel {
            HStack {
                ShadcnCardTitle(label)
                Spacer()
                ShadcnSwitch(isOn: Binding(get: { draft.isOn }, set: { draft.isOn = $0; send() }))
                    .accessibilityLabel("\(label) power")
            }
            ColorPicker("Color", selection: Binding(get: { draft.color.swiftUIColor }, set: { setColor(RGB(color: $0), debounce: true) }), supportsOpacity: false).accessibilityLabel("\(label) color")
            HStack(spacing: 6) {
                ForEach(colors, id: \.hex) { color in ColorSwatch(color: color, selected: draft.color == color, label: "\(label) set color \(color.hex)") { setColor(color) } }
            }
            HStack(spacing: 6) {
                ShadcnTextField("#RRGGBB", text: Binding(get: { hex }, set: { hex = $0; hexEdited = true }), onSubmit: applyHex)
                    .accessibilityLabel("\(label) hex color")

                ShadcnButton("Apply", variant: .secondary, action: applyHex)
                    .accessibilityLabel("Apply \(label) color").disabled(RGB(hex: hex) == nil)
            }
            HStack { Text("Brightness").foregroundStyle(.secondary); Spacer(); Text("\(draft.brightness)%").monospacedDigit() }.font(.caption)
            ShadcnSlider(value: Binding(get: { Double(draft.brightness) }, set: { draft.brightness = Int($0.rounded()); send(debounce: true) }), in: 1...100, step: 1)
                .accessibilityLabel("\(label) brightness")
                .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in editingBrightness = true }.onEnded { _ in editingBrightness = false })

        }
        .onChange(of: head) { _, value in
            if !editingBrightness { draft.brightness = value.brightness }
            draft.isOn = value.isOn; draft.color = value.color; draft.hasRequestedState = value.hasRequestedState
            if !hexEdited { hex = value.color.hex }
        }
    }
    private func setColor(_ color: RGB, debounce: Bool = false) { draft.color = color; draft.isOn = true; hex = color.hex; hexEdited = false; send(debounce: debounce) }
    private func applyHex() { if let color = RGB(hex: hex) { setColor(color) } }
    private func send(debounce: Bool = false) { store.send(.head(draft), to: device.id, debounce: debounce) }
}
