import AppKit
import SwiftUI
import GoveeKit
import ShadcnUI

struct PresetsView: View {
    let store: LightStore
    let device: LightDevice

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: Space.x3)], spacing: Space.x3) {
            ForEach(store.presets) { preset in
                FlatCard {
                    ShadcnCardHeader {
                        Label(preset.name, systemImage: preset.symbol).font(.headline).lineLimit(1)
                        ShadcnCardDescription(preset.heads == nil ? "\(preset.brightness)% brightness" : "3 heads · \(preset.brightness)%")
                    }
                    ShadcnCardFooter {
                        ShadcnButton("Apply", variant: .outline, size: .small, fillsWidth: true) {
                            NSApp.mainWindow?.makeFirstResponder(nil)
                            store.apply(preset, to: device.id)
                        }
                            .accessibilityLabel("Apply \(preset.name)")
                            .disabled(!device.isAvailable
                                || (preset.heads.map { $0.count != device.heads.count } ?? false))
                            .help("Apply \(preset.name) to \(device.name)")
                    }
                }
                .contextMenu {
                    if !preset.isBuiltIn {
                        Button("Delete Preset", role: .destructive) { store.deletePreset(preset.id) }
                    }
                }
            }
        }
    }
}
