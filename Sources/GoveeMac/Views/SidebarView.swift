import SwiftUI
import GoveeKit

struct SidebarView: View {
    @Bindable var store: LightStore
    let discover: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 19)).foregroundStyle(Brand.accent)
                    .frame(width: 35, height: 35)
                    .background(Brand.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Govee Mac").font(.headline)
                    Text("Make room for light.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)
            List(selection: $store.selectedID) {
                if store.devices.isEmpty {
                    Section("Your lights") {
                        Text("Your lights will appear here.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                } else {
                    let favoriteLights = store.devices.filter { store.favorites.contains($0.id) }
                    if !favoriteLights.isEmpty {
                        Section("Favorites") { ForEach(favoriteLights) { row($0) } }
                    }
                    Section("Lights") {
                        ForEach(store.devices.filter { !store.favorites.contains($0.id) }) { row($0) }
                    }
                }
            }
            .listStyle(.sidebar)
            Button(action: discover) {
                Label("Add a light", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain).padding(.horizontal, 20).padding(.vertical, 14)
            Divider().padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 6) {
                    Circle().fill(store.availableCount > 0 ? Brand.accent : Color.secondary.opacity(0.4)).frame(width: 6, height: 6)
                    Text("\(store.availableCount) \(store.availableCount == 1 ? "light" : "lights") available")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Link(destination: Brand.repository) {
                    HStack {
                        Text("Built by the community")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }.font(.caption)
                }
            }.padding(18)
        }
    }

    private func row(_ device: LightDevice) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name).lineLimit(1)
                Text(device.connection == .demo ? "Demo light" : "\(device.connection.title) · \(device.status)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }.padding(.vertical, 4)
        } icon: {
            Image(systemName: device.state.isOn && device.hasKnownState ? "lightbulb.fill" : "lightbulb")
                .foregroundStyle(device.isAvailable ? Brand.accent : .secondary)
        }
        .tag(device.id)
        .contextMenu {
            Button(store.favorites.contains(device.id) ? "Remove from Favorites" : "Add to Favorites") { store.toggleFavorite(device.id) }
            Button("Remove Light", role: .destructive) { store.remove(device) }
        }
    }
}
