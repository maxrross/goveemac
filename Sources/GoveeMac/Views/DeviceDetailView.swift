import SwiftUI
import GoveeKit
import ShadcnUI

struct DeviceDetailView: View {
    let store: LightStore
    let device: LightDevice
    @State private var tab = "Color"
    @State private var sceneQuery = ""
    @State private var sceneCategory = "All"
    @State private var renaming = false
    @State private var newName = ""
    @State private var savingPreset = false
    @State private var presetName = ""

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.x6) {
                hero
                if device.connection == .bluetooth && !device.isAvailable {
                    FlatCard {
                        ShadcnCardHeader {
                            ShadcnCardTitle(device.isConnecting ? "Connecting to your light…" : "Connect to control this light")
                            ShadcnCardDescription("Keep it nearby and close other Bluetooth controllers.")
                        }
                        ShadcnCardFooter {
                            ShadcnButton(device.isConnecting ? "Connecting…" : "Connect", systemImage: "antenna.radiowaves.left.and.right") { store.connect(device) }
                                .disabled(device.isConnecting)
                        }
                    }
                } else if device.connection == .lan && !device.isAvailable {
                    ShadcnAlert(systemImage: "wifi.exclamationmark") {
                        ShadcnAlertTitle("Waiting for your light")
                        ShadcnAlertDescription("Check LAN Control and your network.")
                        ShadcnButton("Retry", variant: .outline, size: .small) { Task { await store.scanLAN() } }
                    }
                }
                LiveStatusRow(live: store.live, deviceID: device.id, sceneName: store.activeScenes[device.id])
                LightTabsView(selection: $tab)

                switch tab {
                case "Scenes": SceneBrowserView(store: store, device: device, query: $sceneQuery, category: $sceneCategory)
                case "Music": SyncControlsView(store: store, device: device, screen: false)
                case "Screen": SyncControlsView(store: store, device: device, screen: true)
                case "Saved looks":
                    HStack {
                        Text("Your collection").font(.headline)
                        Spacer()
                        ShadcnButton("Save current look", systemImage: "plus", variant: .secondary, size: .small) { presetName = ""; savingPreset = true }
                            .disabled(!device.isAvailable || (!device.heads.isEmpty && !device.heads.allSatisfy(\.hasRequestedState)))
                    }
                    PresetsView(store: store, device: device)
                default:
                    LightControlsView(store: store, device: device).disabled(!device.isAvailable)
                    ColorEffectsBar(store: store, deviceID: device.id, available: device.isAvailable)
                    if !device.heads.isEmpty { HeadControlsView(store: store, device: device).disabled(!device.isAvailable) }
                }
            }.padding(Space.x6).frame(maxWidth: 1024).frame(maxWidth: .infinity)
                .background(ScrollIndicatorHider())
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $renaming) {
            nameSheet(title: "Name your light", prompt: "Choose a name for your light.", name: $newName, actionTitle: "Save") {
                store.rename(device.id, to: newName); renaming = false
            }.shadcnSurface(glass: false)
        }
        .sheet(isPresented: $savingPreset) {
            nameSheet(title: "Save this look", prompt: "Keep these colors and brightness levels for next time.", name: $presetName, actionTitle: "Save preset") {
                store.savePreset(name: presetName, device: device); savingPreset = false
            }.shadcnSurface(glass: false)
        }
    }

    private var hero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(device.isAvailable ? Color.green : Color.secondary).frame(width: 6, height: 6)
                    Text("\(device.connection.title) · \(device.status)").font(.caption).foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(device.name).font(.system(size: 28, weight: .semibold)).lineLimit(2)
                    ShadcnButton("Rename", systemImage: "pencil", variant: .secondary) { newName = device.name; renaming = true }
                        .fixedSize().accessibilityLabel("Rename light").help("Rename this light")
                }
                Text(store.activeScenes[device.id] ?? device.model)
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if device.heads.count == 3 {
                TreeLampPreview(heads: device.heads, sceneName: store.activeScenes[device.id])
                    .accessibilityHidden(true).padding(.trailing, 8)
            }
        }.padding(.vertical, 8)
    }

    private func nameSheet(title: String, prompt: String, name: Binding<String>, actionTitle: String, action: @escaping () -> Void) -> some View {
        let valid = !name.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return FlatCard {
            ShadcnCardHeader {
                ShadcnCardTitle(title)
                ShadcnCardDescription(prompt)
            }
            ShadcnCardContent {
                ShadcnTextField("Name", text: name, onSubmit: {
                    if !name.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { action() }
                }).accessibilityLabel(title)
            }
            ShadcnCardFooter {
                Spacer()
                ShadcnButton("Cancel", variant: .outline) { renaming = false; savingPreset = false }
                    .keyboardShortcut(.cancelAction)
                ShadcnButton(actionTitle, action: action).keyboardShortcut(.defaultAction).disabled(!valid)
            }
        }.padding(Space.x6).frame(width: 420)
    }
}

/// A permanent row keeps the page in place when lighting starts or stops.
private struct LiveStatusRow: View {
    let live: LiveController
    let deviceID: String
    let sceneName: String?
    private var active: Bool { live.deviceID == deviceID || live.colorEffects.deviceID == deviceID }
    private var title: String {
        let base = live.deviceID == deviceID ? live.mode : sceneName.map { "Scene · \($0)" } ?? "Manual control"
        return live.colorEffects.deviceID == deviceID ? "\(base) · \(live.colorEffects.effect?.title ?? "Effect")" : base
    }

    var body: some View {
        HStack(spacing: 12) {
            Label(title,
                  systemImage: active ? "waveform.path" : sceneName == nil ? "slider.horizontal.3" : "sparkles")
                .font(.callout.weight(.medium))
            Spacer(minLength: 0)
            ProgressView().controlSize(.small).opacity(live.isStarting || live.colorEffects.isStarting ? 1 : 0)
                .accessibilityHidden(!live.isStarting && !live.colorEffects.isStarting)
            if active {
                ShadcnButton("Stop & restore", variant: .secondary, size: .small) {
                    Task { await live.stop(restore: true) }
                }
            }
        }
        .padding(12)
        .frame(height: 56)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("live-status-row")
    }
}
