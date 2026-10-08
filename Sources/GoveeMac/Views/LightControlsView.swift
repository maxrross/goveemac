import AppKit
import SwiftUI
import GoveeKit
import ShadcnUI

struct LightControlsView: View {
    let store: LightStore
    let device: LightDevice
    @State private var brightness = 100.0
    @State private var temperature = 4000.0
    @GestureState private var editingBrightness = false
    @GestureState private var editingTemperature = false
    @State private var colorMode = "Color"
    @State private var pickerColor = Color.white
    @State private var customHex = ""
    @State private var hexEdited = false

    private let swatches: [RGB] = [RGB(255, 86, 76), RGB(255, 167, 64), RGB(250, 218, 82), RGB(73, 200, 133), RGB(40, 185, 205), RGB(68, 132, 250), RGB(165, 104, 250), RGB(247, 119, 191)]

    var body: some View {
        HStack(alignment: .top, spacing: Space.x4) {
            ShadcnCard {
                ShadcnCardHeader {
                    ShadcnCardTitle("Power & brightness")
                }
                ShadcnCardContent {
                    HStack {
                        Label("Power", systemImage: "power")
                        Spacer()
                        if device.hasKnownState {
                            ShadcnSwitch(isOn: Binding(get: { device.state.isOn }, set: { store.send(.power($0), to: device.id) }))
                                .accessibilityLabel("Light power")
                                .disabled(store.busyIDs.contains(device.id))
                        } else {
                            ShadcnButtonGroup {
                                ShadcnButton("On", size: .small) { store.send(.power(true), to: device.id) }
                                ShadcnButton("Off", variant: .outline, size: .small) { store.send(.power(false), to: device.id) }
                            }.disabled(store.busyIDs.contains(device.id))
                        }
                    }
                    ShadcnSeparator()
                    HStack {
                        Label("Brightness", systemImage: "sun.max")
                        Spacer()
                        ShadcnBadge("\(Int(brightness))%", variant: .secondary)
                    }
                    ShadcnSlider(value: Binding(get: { brightness }, set: {
                        brightness = $0
                        store.send(.brightness(Int($0.rounded())), to: device.id, debounce: true)
                    }), in: 1...100, step: 1)
                        .accessibilityLabel("Brightness")
                        .accessibilityValue("\(Int(brightness)) percent")
                        .simultaneousGesture(DragGesture(minimumDistance: 0).updating($editingBrightness) { _, editing, _ in editing = true })
                    HStack(spacing: Space.x2) {
                        ForEach([25, 50, 75, 100], id: \.self) { value in
                            ShadcnButton("\(value)%", variant: .outline, size: .small, fillsWidth: true) {
                                brightness = Double(value)
                                store.send(.brightness(value), to: device.id)
                            }.accessibilityLabel("Set brightness to \(value) percent")
                        }
                    }
                }.frame(maxHeight: .infinity, alignment: .top)
            }.frame(maxHeight: .infinity, alignment: .top)
            ShadcnCard {
                ShadcnCardHeader {
                    ShadcnCardTitle(device.supportsTemperature ? "Color & white" : "Color")
                }
                ShadcnCardContent {
                    ShadcnTabs(selection: $colorMode, items: device.supportsTemperature ? [("Color", "Color"), ("White", "White")] : [("Color", "Color")])
                    if colorMode == "Color" {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.x2), count: 4), spacing: Space.x2) {
                            ForEach(swatches, id: \.hex) { rgb in
                                ShadcnButton(variant: .outline, size: .iconSM, action: { setColor(rgb) }) {
                                    Image(systemName: "circle.fill").foregroundStyle(rgb.swiftUIColor)
                                }
                                .accessibilityLabel("Set color \(rgb.hex)").help(rgb.hex)
                            }
                        }
                        ColorPicker("Custom color", selection: Binding(get: { pickerColor }, set: {
                            setColor(RGB(color: $0), debounce: true)
                        }), supportsOpacity: false)
                        HStack(spacing: Space.x2) {
                            ShadcnTextField("#24A5FF", text: Binding(get: { customHex }, set: {
                                customHex = $0; hexEdited = true
                            }), onSubmit: applyCustomColor)
                                .accessibilityLabel("Custom hex color")
                            ShadcnButton("Apply", variant: .outline, size: .small, action: applyCustomColor)
                                .accessibilityLabel("Apply custom color")
                                .disabled(RGB(hex: customHex) == nil || store.busyIDs.contains(device.id))
                        }
                    } else {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            ShadcnBadge("\(Int(temperature)) K", variant: .secondary)
                        }
                        ShadcnSlider(value: Binding(get: { temperature }, set: {
                            temperature = $0
                            store.send(.temperature(Int($0)), to: device.id, debounce: true)
                        }), in: 2000...9000, step: 100)
                            .accessibilityLabel("White temperature")
                            .accessibilityValue("\(Int(temperature)) kelvin")
                            .simultaneousGesture(DragGesture(minimumDistance: 0).updating($editingTemperature) { _, editing, _ in editing = true })
                        HStack {
                            Text("2000 K")
                            Spacer()
                            Text("9000 K")
                        }.font(.caption).foregroundStyle(.secondary)
                        ShadcnButton("Apply white", variant: .outline) { store.send(.temperature(Int(temperature)), to: device.id) }
                    }
                }.frame(maxHeight: .infinity, alignment: .top)
            }.frame(maxHeight: .infinity, alignment: .top)
        }.fixedSize(horizontal: false, vertical: true)
        .onAppear { synchronize() }
        .onChange(of: device.state) { _, _ in synchronize() }
    }

    private func synchronize() {
        if !editingBrightness { brightness = Double(device.state.brightness) }
        if !editingTemperature { temperature = Double(device.state.temperature > 0 ? device.state.temperature : 4000) }
        pickerColor = device.state.color.swiftUIColor
        if !hexEdited { customHex = device.state.color.hex }
        colorMode = device.state.temperature > 0 && device.supportsTemperature ? "White" : "Color"
    }

    private func setColor(_ rgb: RGB, debounce: Bool = false) {
        // ShadKit preserves an active field editor; end editing before
        // replacing its draft with a chosen color.
        NSApp.mainWindow?.makeFirstResponder(nil)
        pickerColor = rgb.swiftUIColor
        customHex = rgb.hex
        hexEdited = false
        store.send(.color(rgb), to: device.id, debounce: debounce)
    }

    private func applyCustomColor() {
        guard let rgb = RGB(hex: customHex), !store.busyIDs.contains(device.id) else { return }
        setColor(rgb)
    }
}
