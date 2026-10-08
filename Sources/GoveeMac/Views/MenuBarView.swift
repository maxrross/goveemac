import AppKit
import SwiftUI

struct MenuBarView: View {
    let store: LightStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Govee Mac") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
        Divider()
        if store.devices.isEmpty { Text("No lights connected") }
        ForEach(store.devices.filter(\.isAvailable)) { device in
            Menu(String(device.name.prefix(27))) {
                Button("Turn on") { store.send(.power(true), to: device.id) }
                Button("Turn off") { store.send(.power(false), to: device.id) }
                Divider()
                ForEach(store.presets) { preset in
                    Button(String(preset.name.prefix(27))) { store.apply(preset, to: device.id) }
                }
            }
        }
        Divider()
        Button("All lights on") { store.setAllPower(true) }.disabled(store.availableCount == 0)
        Button("All lights off") { store.setAllPower(false) }.disabled(store.availableCount == 0)
        Divider()
        SettingsLink { Text("Settings…") }
        Button("Quit Govee Mac") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
