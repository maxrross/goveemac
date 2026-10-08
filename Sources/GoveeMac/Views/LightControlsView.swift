import SwiftUI
import GoveeKit

struct ControlPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16, content: content)
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.06)) }
    }
}

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
    private let swatches: [RGB] = [RGB(255,86,76), RGB(255,167,64), RGB(250,218,82), RGB(73,200,133), RGB(40,185,205), RGB(68,132,250), RGB(165,104,250), RGB(247,119,191)]
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ControlPanel {
                HStack {
                    Text("Whole lamp").font(.headline)
                    Spacer()
                    Toggle("Power", isOn: Binding(get: { device.state.isOn }, set: { store.send(.power($0), to: device.id) }))
                        .toggleStyle(.switch).labelsHidden().accessibilityLabel("Light power")
                }
                HStack {
                    Text("Brightness").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(brightness))%").font(.callout.monospacedDigit())
                }
                Slider(value: Binding(get: { brightness }, set: { brightness = $0; store.send(.brightness(Int($0.rounded())), to: device.id, debounce: true) }), in: 1...100) { editingBrightness = $0 }
                    .accessibilityLabel("Brightness")

                HStack(spacing: 8) {
                    ForEach([25,50,75,100], id: \.self) { value in
                        Button("\(value)%") { brightness = Double(value); store.send(.brightness(value), to: device.id) }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }
            ControlPanel {
                HStack {
                    Text("Color").font(.headline)
                    Spacer()
                    if device.supportsTemperature {
                        Picker("Color mode", selection: $white) { Text("RGB").tag(false); Text("White").tag(true) }.pickerStyle(.segmented).labelsHidden().frame(width: 145)
                    }
                }
                if white {
                    HStack { Text("Temperature").foregroundStyle(.secondary); Spacer(); Text("\(Int(temperature)) K").monospacedDigit() }.font(.callout)
                    Slider(value: Binding(get: { temperature }, set: { temperature = $0; store.send(.temperature(Int($0.rounded())), to: device.id, debounce: true) }), in: 2000...9000) { editingTemperature = $0 }
                        .accessibilityLabel("White temperature")

                    Button("Apply white") { store.send(.temperature(Int(temperature)), to: device.id) }.buttonStyle(.bordered).controlSize(.small)
                } else {
                    HStack(spacing: 5) {
                        ForEach(swatches, id: \.hex) { rgb in ColorSwatch(color: rgb, selected: device.state.color == rgb) { setColor(rgb) } }
                        Spacer(minLength: 0)
                    }
                    ColorPicker("Custom color", selection: Binding(get: { device.state.color.swiftUIColor }, set: { setColor(RGB(color: $0), debounce: true) }), supportsOpacity: false)
                    HStack(spacing: 8) {
                        TextField("#RRGGBB", text: Binding(get: { hex }, set: { hex = $0; hexEdited = true })).textFieldStyle(.roundedBorder).font(.callout.monospaced())
                            .accessibilityLabel("Custom hex color").onSubmit(applyHex)

                        Button("Apply", action: applyHex).buttonStyle(.bordered).disabled(RGB(hex: hex) == nil)
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
