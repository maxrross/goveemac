import AppKit
import SwiftUI
import GoveeKit
import ShadcnUI

struct SidebarView: View {
    @Bindable var store: LightStore
    let discover: () -> Void
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.x3) {
                Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit()
                    .frame(width: 40, height: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.x1) {
                    Text("Govee Mac").font(.headline)
                    Text("Local light control").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(Space.x4)
            List(selection: $store.selectedID) {
                if store.devices.isEmpty {
                    Section("Lights") { }
                } else {
                    let favoriteLights = store.devices.filter { store.favorites.contains($0.id) }
                    if !favoriteLights.isEmpty {
                        Section("Favorites") { ForEach(favoriteLights) { row($0) } }
                    }
                    Section("Lights") {
                        ForEach(store.devices.filter { !store.favorites.contains($0.id) }) { row($0) }
                    }
                }
            }.listStyle(.sidebar)
            ShadcnButton("Add a light", systemImage: "plus", variant: .outline, fillsWidth: true, action: discover)
                .padding(Space.x4)
            ShadcnSeparator().padding(.horizontal, Space.x4)
            Link("Built by the community ↗", destination: Brand.repository)
                .buttonStyle(.shadcn(.link, size: .small))
                .frame(maxWidth: .infinity, alignment: .leading).padding(Space.x4)
        }
    }

    private func row(_ device: LightDevice) -> some View {
        HStack(alignment: .center, spacing: Space.x3) {
            Image(systemName: device.state.isOn && device.hasKnownState ? "lamp.floor.fill" : "lamp.floor")
                .font(.title3)
                .foregroundStyle(store.selectedID == device.id && controlActiveState != .inactive ? Color.white : Color.accentColor)
                .frame(width: 24, alignment: .center)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.x1) {
                Text(device.name).lineLimit(1)
                Text("\(device.connection.title) · \(device.status)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, Space.x1)
        .tag(device.id)
        .contextMenu {
            Button(store.favorites.contains(device.id) ? "Remove from Favorites" : "Add to Favorites") { store.toggleFavorite(device.id) }
            Button("Remove Light", role: .destructive) { store.remove(device) }
        }
    }
}
