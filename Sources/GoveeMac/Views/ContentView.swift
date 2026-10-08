import SwiftUI
import GoveeKit

struct ContentView: View {
    @Bindable var store: LightStore
    @State private var discovery: DiscoveryRequest?

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, discover: { discovery = DiscoveryRequest(kind: .lan) })
                .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 290)
        } detail: {
            Group {
                if let device = store.selectedDevice {
                    DeviceDetailView(store: store, device: device)
                        .id(device.id)
                } else {
                    WelcomeView(store: store) { kind in
                        discovery = DiscoveryRequest(kind: kind)
                    }
                }
            }
            .navigationTitle(store.selectedDevice?.name ?? "Govee Mac")
            .toolbar {
                ToolbarItemGroup {
                    if store.isScanningLAN || store.isScanningBluetooth { ProgressView().controlSize(.small) }
                    Button { discovery = DiscoveryRequest(kind: .lan) } label: { Label("Add light", systemImage: "plus") }
                        .help("Discover or add a light")
                    Menu {
                        Button("All lights on") { store.setAllPower(true) }
                        Button("All lights off") { store.setAllPower(false) }
                        Divider()
                        Button("Refresh Wi-Fi lights") { Task { await store.scanLAN() } }
                    } label: { Label("Light actions", systemImage: "ellipsis.circle") }
                    SettingsLink { Label("Settings", systemImage: "gearshape") }
                }
            }
        }
        .sheet(item: $discovery) { request in DiscoveryView(store: store, initialKind: request.kind) }
        .alert("Couldn’t control the light", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}

private struct DiscoveryRequest: Identifiable {
    let kind: ConnectionKind
    var id: String { kind.rawValue }
}
