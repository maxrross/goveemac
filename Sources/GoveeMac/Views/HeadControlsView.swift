import SwiftUI
import GoveeKit

struct HeadControlsView: View {
    let store: LightStore
    let device: LightDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Individual heads").font(.title3.weight(.semibold))
                Text("Give each head its own look. Whole-lamp controls above affect all three.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                ForEach(device.heads) { head in
                    HeadControlCard(store: store, device: device, head: head)
                }
            }
            Text("Head brightness is relative to the whole lamp. Heads show the last settings sent from Govee Mac.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct HeadControlCard: View {
    let store: LightStore
    let device: LightDevice
    let head: LightHeadState
    @State private var draft: LightHeadState
    @State private var hex: String
    @State private var editingBrightness = false
    @FocusState private var editingHex: Bool
    private let colors = [RGB(255, 0, 0), RGB(73, 200, 133), RGB(36, 165, 255), RGB(174, 107, 255)]

    init(store: LightStore, device: LightDevice, head: LightHeadState) {
        self.store = store; self.device = device; self.head = head
        _draft = State(initialValue: head)
        _hex = State(initialValue: head.color.hex)
    }

    private var label: String { DeviceCatalog.headName(model: device.model, index: head.id) }
    private var busy: Bool { store.busyIDs.contains(device.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle().fill(draft.isOn ? draft.color.swiftUIColor : .secondary.opacity(0.25))
                    .frame(width: 11, height: 11)
                Text(label).font(.headline)
                Spacer()
                if head.hasRequestedState {
                    Toggle("Power", isOn: Binding(get: { draft.isOn }, set: {
                        draft.isOn = $0; send()
                    })).labelsHidden().toggleStyle(.switch)
                        .accessibilityLabel("\(label) power").disabled(busy)
                } else {
                    Button("Off") { draft.isOn = false; send() }
                        .accessibilityLabel("Turn \(label) off").disabled(busy)
                }
            }
            ColorPicker("Color", selection: Binding(get: { draft.color.swiftUIColor }, set: {
                setColor(RGB(color: $0), debounce: true)
            }), supportsOpacity: false).accessibilityLabel("\(label) color")
            HStack(spacing: 10) {
                ForEach(colors, id: \.hex) { color in
                    Button { setColor(color) } label: {
                        Circle().fill(color.swiftUIColor).frame(width: 21, height: 21)
                            .overlay(Circle().strokeBorder(.primary.opacity(0.08)))
                    }.buttonStyle(.plain).accessibilityLabel("\(label) set color \(color.hex)")
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                TextField("#24A5FF", text: $hex).textFieldStyle(.roundedBorder)
                    .font(.system(.callout, design: .monospaced))
                    .accessibilityLabel("\(label) hex color").focused($editingHex)
                    .onSubmit { applyHex() }
                Button("Apply") { applyHex() }
                    .accessibilityLabel("Apply \(label) color")
                    .disabled(RGB(hex: hex) == nil || busy)
            }
            Divider()
            HStack {
                Text("Brightness").font(.caption)
                Spacer()
                Text("\(draft.brightness)%").font(.caption.monospacedDigit())
            }
            Slider(value: Binding(get: { Double(draft.brightness) }, set: {
                draft.brightness = Int($0.rounded())
            }), in: 1...100) { editing in
                editingBrightness = editing
                if !editing { send() }
            }.accessibilityLabel("\(label) brightness").disabled(busy || !head.hasRequestedState)
            if !head.hasRequestedState {
                Text("Choose a color to get started.").font(.caption2).foregroundStyle(.secondary)
            }
        }.surface()
            .onChange(of: head) { _, value in
                if !editingBrightness { draft.brightness = value.brightness }
                draft.isOn = value.isOn
                draft.hasRequestedState = value.hasRequestedState
                if !editingHex { draft.color = value.color; hex = value.color.hex }
            }
    }

    private func setColor(_ color: RGB, debounce: Bool = false) {
        draft.color = color
        draft.isOn = true
        if !editingHex { hex = color.hex }
        send(debounce: debounce)
    }

    private func applyHex() {
        guard let color = RGB(hex: hex) else { return }
        editingHex = false
        setColor(color)
    }

    private func send(debounce: Bool = false) {
        store.send(.head(draft), to: device.id, debounce: debounce)
    }
}
