import SwiftUI
import GoveeKit

struct PresetsView: View {
    let store: LightStore
    let device: LightDevice
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(store.presets) { preset in
                Button { store.apply(preset, to: device.id) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: preset.symbol).font(.system(size: 19))
                            .foregroundStyle(preset.color.swiftUIColor)
                            .frame(width: 39, height: 39)
                            .background(preset.color.swiftUIColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(preset.name).font(.callout.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                            Text("\(preset.brightness)% brightness").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(preset.color.swiftUIColor.opacity(0.18)))
                }.buttonStyle(.plain).disabled(!device.isAvailable || store.busyIDs.contains(device.id))
                    .help("Apply \(preset.name) to \(device.name)")
                    .contextMenu {
                        if !preset.isBuiltIn {
                            Button("Delete Preset", role: .destructive) { store.deletePreset(preset.id) }
                        }
                    }
            }
        }
    }
}
