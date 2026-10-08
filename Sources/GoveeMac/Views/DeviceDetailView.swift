import SwiftUI
import GoveeKit
import ShadcnUI

struct DeviceDetailView: View {
    let store: LightStore
    let device: LightDevice
    @State private var renaming = false
    @State private var newName = ""
    @State private var savingPreset = false
    @State private var presetName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.x6) {
                if device.connection == .demo {
                    ShadcnAlert(systemImage: "sparkles") {
                        HStack {
                            ShadcnAlertTitle("Demo mode")
                            Spacer()
                            ShadcnButton("Exit demo", variant: .ghost, size: .small) { store.disableDemo() }
                        }
                    }
                }
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
                if !device.heads.isEmpty { ShadcnCardTitle("Whole lamp") }
                LightControlsView(store: store, device: device).disabled(!device.isAvailable)
                if !device.heads.isEmpty {
                    HeadControlsView(store: store, device: device).disabled(!device.isAvailable)
                }
                HStack(alignment: .top, spacing: Space.x4) {
                    ShadcnCardTitle("Presets")
                    Spacer()
                    ShadcnButton("Save current look", systemImage: "plus", variant: .outline, size: .small) {
                        presetName = ""; savingPreset = true
                    }.disabled(!device.isAvailable || (!device.heads.isEmpty && !device.heads.allSatisfy(\.hasRequestedState)))
                }
                PresetsView(store: store, device: device)
                connectionDetails
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
        VStack(alignment: .leading, spacing: Space.x3) {
            HStack(spacing: Space.x2) {
                ShadcnBadge(device.connection.title, systemImage: device.connection.symbol, variant: .outline)
                ShadcnBadge(device.status, variant: device.isAvailable ? .secondary : .outline)
            }
            HStack(alignment: .firstTextBaseline, spacing: Space.x2) {
                Text(device.name).font(.title.weight(.semibold)).lineLimit(2)
                ShadcnButton(icon: "pencil", size: .iconSM) {
                    newName = device.name; renaming = true
                }.help("Rename light").accessibilityLabel("Rename light")
            }
            if device.connection != .demo { ShadcnCardDescription(device.model) }
        }
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
                ShadcnCardDescription(device.connection == .demo ? "This virtual light is for previewing the app." : "Power and brightness are read from the light. Color shows the last requested value when the light reports only its mode. Check the physical light to confirm a color change.")
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
