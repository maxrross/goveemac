import SwiftUI
import GoveeKit
import ShadcnUI

struct DeviceDetailView: View {
    let store: LightStore
    let device: LightDevice
    @State private var tab = "Color"
    @State private var renaming = false
    @State private var newName = ""
    @State private var savingPreset = false
    @State private var presetName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.x6) {
                hero
                if device.connection == .bluetooth && !device.isAvailable {
                    ShadcnCard {
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
                if store.live.deviceID == device.id {
                    HStack {
                        Label(store.live.mode, systemImage: "waveform.path").font(.callout.weight(.medium))
                        Spacer()
                        Button("Stop & restore") { Task { await store.live.stop(restore: true) } }
                            .buttonStyle(.bordered)
                    }.padding(12).background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                Picker("Light controls", selection: $tab) {
                    Text("Color").tag("Color")
                    Text("Scenes").tag("Scenes")
                    Text("Music").tag("Music")
                    Text("Screen").tag("Screen")
                    Text("Saved looks").tag("Saved looks")
                }.pickerStyle(.segmented).labelsHidden()
                switch tab {
                case "Scenes": SceneBrowserView(store: store, device: device)
                case "Music": SyncControlsView(store: store, device: device, screen: false)
                case "Screen": SyncControlsView(store: store, device: device, screen: true)
                case "Saved looks":
                    HStack {
                        Text("Your collection").font(.headline)
                        Spacer()
                        Button("Save current look", systemImage: "plus") { presetName = ""; savingPreset = true }
                            .buttonStyle(.bordered)
                            .disabled(!device.isAvailable || (!device.heads.isEmpty && !device.heads.allSatisfy(\.hasRequestedState)))
                    }
                    PresetsView(store: store, device: device)
                default:
                    LightControlsView(store: store, device: device).disabled(!device.isAvailable)
                    if !device.heads.isEmpty { HeadControlsView(store: store, device: device).disabled(!device.isAvailable) }
                }
                DisclosureGroup("Connection details") { connectionDetails }
            }.padding(Space.x6).frame(maxWidth: 1024).frame(maxWidth: .infinity)
        }
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
                    Button { newName = device.name; renaming = true } label: { Image(systemName: "pencil") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Rename light")
                }
                Text(store.activeScenes[device.id] ?? device.model)
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 5) {
                ForEach(device.heads.reversed()) { head in
                    Capsule().fill(head.wireColor.swiftUIColor.gradient).frame(width: 56, height: 13)
                        .shadow(color: head.color.swiftUIColor.opacity(head.isOn ? 0.25 : 0), radius: 8)
                }
                if device.heads.isEmpty {
                    RoundedRectangle(cornerRadius: 16).fill(device.state.color.swiftUIColor.gradient).frame(width: 55, height: 55)
                }
            }.accessibilityHidden(true).padding(.trailing, 8)
        }.padding(.vertical, 8)
    }

    private var connectionDetails: some View {
        ShadcnCard {
            ShadcnCardHeader(content: {
                ShadcnCardTitle("Connection")
                ShadcnCardDescription(device.usesEncryptedBLE ? "Bluetooth · encrypted session" : device.connection.title)
            }, action: {
                ShadcnButton(icon: store.favorites.contains(device.id) ? "star.fill" : "star", size: .iconSM) { store.toggleFavorite(device.id) }
                    .accessibilityLabel(store.favorites.contains(device.id) ? "Remove from Favorites" : "Add to Favorites")
            })
            ShadcnCardContent {
                if !device.address.isEmpty {
                    LabeledContent(device.connection == .lan ? "IP address" : "Identifier") {
                        Text(device.address).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                ShadcnCardDescription("Power and brightness are read from the light. Color shows the last requested value when the light reports only its mode. Check the physical light to confirm a color change.")
                if let sent = device.lastSent {
                    ShadcnCardDescription("Last command sent \(sent.formatted(date: .omitted, time: .standard))")
                }
            }
            if device.connection == .bluetooth && device.isAvailable {
                ShadcnCardFooter {
                    ShadcnButton("Disconnect", variant: .outline, size: .small) { store.disconnect(device) }
                }
            }
        }
    }

    private func nameSheet(title: String, prompt: String, name: Binding<String>, actionTitle: String, action: @escaping () -> Void) -> some View {
        let valid = !name.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return ShadcnCard {
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
