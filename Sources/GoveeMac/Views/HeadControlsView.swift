import AppKit
import SwiftUI
import GoveeKit
import ShadcnUI

struct HeadControlsView: View {
    let store: LightStore
    let device: LightDevice

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x4) {
            ShadcnCardTitle("Individual heads")
                .help("Head brightness is relative to the whole lamp. Heads show the last settings sent from Govee Mac.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: Space.x3)], spacing: Space.x3) {
                ForEach(device.heads) { head in
                    HeadControlCard(store: store, device: device, head: head)
                }
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
    @GestureState private var editingBrightness = false
    private let colors = [RGB(255, 0, 0), RGB(73, 200, 133), RGB(36, 165, 255), RGB(174, 107, 255)]

    init(store: LightStore, device: LightDevice, head: LightHeadState) {
        self.store = store; self.device = device; self.head = head
        _draft = State(initialValue: head)
        _hex = State(initialValue: head.color.hex)
    }

    private var label: String { DeviceCatalog.headName(model: device.model, index: head.id) }
    private var busy: Bool { store.busyIDs.contains(device.id) }

    var body: some View {
        ShadcnCard {
            ShadcnCardHeader(content: {
                ShadcnCardTitle(label)
                if !head.hasRequestedState { ShadcnCardDescription("Choose a color") }
            }, action: {
                if head.hasRequestedState {
                    ShadcnSwitch(isOn: Binding(get: { draft.isOn }, set: {
                        draft.isOn = $0; send()
                    }))
                    .accessibilityLabel("\(label) power").disabled(busy)
                } else {
                    ShadcnButton("Off", variant: .outline, size: .small) { draft.isOn = false; send() }
                        .accessibilityLabel("Turn \(label) off").disabled(busy)
                }
            })
            ShadcnCardContent {
                ColorPicker("Color", selection: Binding(get: { draft.color.swiftUIColor }, set: {
                    setColor(RGB(color: $0), debounce: true)
                }), supportsOpacity: false).accessibilityLabel("\(label) color")
                HStack(spacing: Space.x2) {
                    ForEach(colors, id: \.hex) { color in
                        ShadcnButton(variant: .outline, size: .iconSM, action: { setColor(color) }) {
                            Image(systemName: "circle.fill").foregroundStyle(color.swiftUIColor)
                        }.accessibilityLabel("\(label) set color \(color.hex)").help(color.hex)
                    }
                }
                HStack(spacing: Space.x2) {
                    ShadcnTextField("#24A5FF", text: Binding(get: { hex }, set: {
                        hex = $0; hexEdited = true
                    }), onSubmit: applyHex).accessibilityLabel("\(label) hex color")
                    ShadcnButton("Apply", variant: .outline, size: .small, action: applyHex)
                        .accessibilityLabel("Apply \(label) color")
                        .disabled(RGB(hex: hex) == nil || busy)
                }
                ShadcnSeparator()
                HStack {
                    Text("Brightness").font(.callout)
                    Spacer()
                    ShadcnBadge("\(draft.brightness)%", variant: .secondary)
                }
                ShadcnSlider(value: Binding(get: { Double(draft.brightness) }, set: {
                    draft.brightness = Int($0.rounded()); send(debounce: true)
                }), in: 1...100, step: 1)
                    .accessibilityLabel("\(label) brightness")
                    .accessibilityValue("\(draft.brightness) percent")
                    .simultaneousGesture(DragGesture(minimumDistance: 0).updating($editingBrightness) { _, editing, _ in editing = true })
                    .disabled((busy && !editingBrightness) || !head.hasRequestedState)
            }
        }
        .onChange(of: head) { _, value in
            if !editingBrightness { draft.brightness = value.brightness }
            draft.isOn = value.isOn
            draft.hasRequestedState = value.hasRequestedState
            draft.color = value.color
            if !hexEdited { hex = value.color.hex }
        }
    }

    private func setColor(_ color: RGB, debounce: Bool = false) {
        NSApp.mainWindow?.makeFirstResponder(nil)
        draft.color = color
        draft.isOn = true
        hex = color.hex
        hexEdited = false
        send(debounce: debounce)
    }

    private func applyHex() {
        guard let color = RGB(hex: hex), !busy else { return }
        setColor(color)
    }

    private func send(debounce: Bool = false) {
        store.send(.head(draft), to: device.id, debounce: debounce)
    }
}
