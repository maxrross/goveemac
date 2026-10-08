import SwiftUI
import GoveeKit

struct LightControlsView: View {
    let store: LightStore
    let device: LightDevice
    @State private var brightness = 100.0
    @State private var temperature = 4000.0
    @State private var editingBrightness = false
    @State private var editingTemperature = false
    @State private var colorMode = "Color"
    @State private var pickerColor = Brand.accent

    private let swatches: [RGB] = [RGB(255, 86, 76), RGB(255, 167, 64), RGB(250, 218, 82), RGB(73, 200, 133), RGB(40, 185, 205), RGB(68, 132, 250), RGB(165, 104, 250), RGB(247, 119, 191)]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Power", systemImage: "power").font(.headline)
                        Text(device.hasKnownState ? (device.state.isOn ? "Let there be light." : "Ready when you are.") : "Choose a power state.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if device.hasKnownState {
                        Toggle("Power", isOn: Binding(get: { device.state.isOn }, set: { store.send(.power($0), to: device.id) }))
                            .toggleStyle(.switch).labelsHidden().accessibilityLabel("Light power")
                            .disabled(store.busyIDs.contains(device.id))
                    } else {
                        Button("Turn on") { store.send(.power(true), to: device.id) }.buttonStyle(.borderedProminent)
                        Button("Off") { store.send(.power(false), to: device.id) }
                    }
                }
                Divider()
                HStack {
                    Label("Brightness", systemImage: "sun.max").font(.headline)
                    Spacer()
                    Text("\(Int(brightness))%").font(.system(size: 22, weight: .medium, design: .rounded)).monospacedDigit()
                }
                Slider(value: $brightness, in: 1...100) { editing in
                    editingBrightness = editing
                    if !editing { store.send(.brightness(Int(brightness.rounded())), to: device.id) }
                }.accessibilityLabel("Brightness")
                HStack {
                    Text("Subtle")
                    Spacer()
                    Text("Bright")
                }.font(.caption2).foregroundStyle(.secondary)
            }.surface().frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Label("Light", systemImage: "paintpalette").font(.headline)
                    Spacer()
                    if colorMode == "Color" {
                        Text(RGB(color: pickerColor).hex).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    } else {
                        Text("\(Int(temperature)) K").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                Picker("Light mode", selection: $colorMode) {
                    Text("Color").tag("Color")
                    if device.supportsTemperature { Text("White").tag("White") }
                }.pickerStyle(.segmented).labelsHidden()
                if colorMode == "Color" {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                        ForEach(swatches, id: \.hex) { rgb in
                            Button {
                                pickerColor = rgb.swiftUIColor
                                store.send(.color(rgb), to: device.id)
                            } label: {
                                Circle().fill(rgb.swiftUIColor).frame(width: 23, height: 23)
                                    .overlay(Circle().strokeBorder(.primary.opacity(0.08)))
                            }.buttonStyle(.plain).accessibilityLabel("Set color \(rgb.hex)").help(rgb.hex)
                        }
                    }.padding(.vertical, 3)
                    ColorPicker("Custom color", selection: Binding(get: { pickerColor }, set: { color in
                        pickerColor = color
                        store.send(.color(RGB(color: color)), to: device.id, debounce: true)
                    }), supportsOpacity: false)
                    Text(device.supportsTemperature ? "Pick a favorite, or find your own." : "Color control · white temperature requires Wi-Fi.")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Slider(value: $temperature, in: 2000...9000) { editing in
                        editingTemperature = editing
                        if !editing { store.send(.temperature(Int((temperature / 100).rounded()) * 100), to: device.id) }
                    }.accessibilityLabel("White temperature")
                    HStack { Text("Warm · 2000 K"); Spacer(); Text("Cool · 9000 K") }.font(.caption2).foregroundStyle(.secondary)
                    Button("Apply white") { store.send(.temperature(Int(temperature)), to: device.id) }
                }
            }.surface().frame(maxWidth: .infinity)
        }
        .onAppear { synchronize() }
        .onChange(of: device.state) { _, _ in synchronize() }
    }

    private func synchronize() {
        if !editingBrightness { brightness = Double(device.state.brightness) }
        if !editingTemperature { temperature = Double(device.state.temperature > 0 ? device.state.temperature : 4000) }
        pickerColor = device.state.color.swiftUIColor
        colorMode = device.state.temperature > 0 && device.supportsTemperature ? "White" : "Color"
    }
}
