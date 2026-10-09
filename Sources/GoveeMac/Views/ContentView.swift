import SwiftUI
import GoveeKit
import ShadcnUI

struct ContentView: View {
    @Bindable var store: LightStore
    @State private var discovery: DiscoveryRequest?
    @Environment(\.shadcnPalette) private var palette

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, discover: { discovery = DiscoveryRequest(kind: .lan) })
                .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 290)
        } detail: {
            Group {
                if store.showsSettings {
                    SettingsView(store: store)
                } else if let id = store.selectedID {
                    SelectedLightDetail(store: store, id: id).id(id)
                } else {
                    WelcomeView { kind in
                        discovery = DiscoveryRequest(kind: kind)
                    }
                }
            }
            .background(palette.background)
            .navigationTitle("Govee Mac")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if store.isScanningLAN || store.isScanningBluetooth { ProgressView().controlSize(.small) }
                    Menu {
                        Button("All lights on") { store.setAllPower(true) }
                        Button("All lights off") { store.setAllPower(false) }
                        Divider()
                        Button("Refresh Wi-Fi lights") { Task { await store.scanLAN() } }
                    } label: { Label("Light actions", systemImage: "ellipsis.circle") }
                    Button { store.showsSettings.toggle() } label: { Label("Settings", systemImage: "gearshape") }
                        .help("Settings in this window")
                }
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .scrollIndicators(.hidden)
        .onChange(of: store.selectedID) { _, _ in store.showsSettings = false }
        .sheet(item: $discovery) { request in
            DiscoveryView(store: store, initialKind: request.kind).shadcnSurface(glass: false)
        }
        .alert("Couldn’t control the light", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}

/// Device telemetry updates this detail without invalidating window chrome.
private struct SelectedLightDetail: View {
    let store: LightStore
    let id: String
    var body: some View {
        if let device = store.devices.first(where: { $0.id == id }) {
            DeviceDetailView(store: store, device: device)
        }
    }
}

private struct DiscoveryRequest: Identifiable {
    let kind: ConnectionKind
    var id: String { kind.rawValue }
}
