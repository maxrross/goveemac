import SwiftUI
import GoveeKit
import ShadcnUI

struct LightControlsView: View {
    let store: LightStore
    let device: LightDevice
    @State private var brightness = 100.0
    @State private var temperature = 4000.0
    @State private var editingBrightness = false
    @State private var editingTemperature = false
    @State private var white = false
    @State private var hex = ""
    @State private var hexEdited = false
    private let swatches: [RGB] = [RGB(255,86,76), RGB(255,167,64), RGB(250,218,82), RGB(0,255,0), RGB(40,185,205), RGB(68,132,250), RGB(165,104,250), RGB(247,119,191)]
    var body: some View {
        EqualHeightColumns {
            ControlPanel(fillsHeight: true) {
                HStack {
                    ShadcnCardTitle("Whole lamp")
                    Spacer()
                    ShadcnSwitch(isOn: Binding(get: { device.state.isOn }, set: { store.send(.power($0), to: device.id) }))
                        .accessibilityLabel("Light power")
                }.frame(height: 32)
                HStack {
                    Text("Brightness").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(brightness))%").font(.callout.monospacedDigit())
                }
                ShadcnSlider(value: Binding(get: { brightness }, set: { brightness = $0; store.send(.brightness(Int($0.rounded())), to: device.id, debounce: true) }), in: 1...100, step: 1)
                    .focusEffectDisabled()
                    .accessibilityLabel("Brightness")
                    .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in editingBrightness = true }.onEnded { _ in editingBrightness = false })

                EqualHeightColumns(spacing: 8, minimumColumnWidth: 72, allowedColumnCounts: [2, 4]) {
                    ForEach([25,50,75,100], id: \.self) { value in
                        ShadcnButton("\(value)%", variant: .secondary, fillsWidth: true) { brightness = Double(value); store.send(.brightness(value), to: device.id) }
                    }
                }
            }
            ControlPanel(fillsHeight: true) {
                HStack {
                    ShadcnCardTitle("Color")
                    Spacer()
                    if device.supportsTemperature {
                        ShadcnTabs(selection: $white, items: [(false, "RGB"), (true, "White")])
                    }
                }.frame(height: 32)
                if white {
                    HStack { Text("Temperature").foregroundStyle(.secondary); Spacer(); Text("\(Int(temperature)) K").monospacedDigit() }.font(.callout)
                    ShadcnSlider(value: Binding(get: { temperature }, set: { temperature = $0; store.send(.temperature(Int($0.rounded())), to: device.id, debounce: true) }), in: 2000...9000, step: 100)
                        .focusEffectDisabled()
                        .accessibilityLabel("White temperature")
                        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in editingTemperature = true }.onEnded { _ in editingTemperature = false })

                    ShadcnButton("Apply white", variant: .secondary, size: .small) { store.send(.temperature(Int(temperature)), to: device.id) }
                } else {
                    ShadcnWrapLayout(spacing: 5) {
                        ForEach(swatches, id: \.hex) { rgb in ColorSwatch(color: rgb, selected: device.state.color == rgb) { setColor(rgb) } }
                    }
                    ColorPicker("Custom color", selection: Binding(get: { device.state.color.swiftUIColor }, set: { setColor(RGB(color: $0), debounce: true) }), supportsOpacity: false)
                    HStack(spacing: 8) {
                        ShadcnTextField("#RRGGBB", text: Binding(get: { hex }, set: { hex = $0; hexEdited = true }), onSubmit: applyHex)
                            .accessibilityLabel("Custom hex color")

                        ShadcnButton("Apply", variant: .secondary, action: applyHex).disabled(RGB(hex: hex) == nil)
                            .accessibilityLabel("Apply custom color")
                    }
                }
            }
        }
        .onAppear { synchronize() }
        .onChange(of: device.state) { _, _ in synchronize() }
    }
    private func synchronize() {
        if !editingBrightness { brightness = Double(device.state.brightness) }
        if !editingTemperature { temperature = Double(device.state.temperature > 0 ? device.state.temperature : 4000) }
        if !hexEdited { hex = device.state.color.hex }
        white = device.state.temperature > 0 && device.supportsTemperature
    }
    private func applyHex() { if let color = RGB(hex: hex) { setColor(color) } }
    private func setColor(_ color: RGB, debounce: Bool = false) {
        hex = color.hex; hexEdited = false
        store.send(.color(color), to: device.id, debounce: debounce)
    }
}
