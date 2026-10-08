import SwiftUI
import GoveeKit

struct DeviceDetailView: View {
    let store: LightStore
    let device: LightDevice
    @State private var renaming = false
    @State private var newName = ""
    @State private var savingPreset = false
    @State private var presetName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if device.connection == .demo {
                    HStack {
                        Label("Demo mode · controls affect a virtual light", systemImage: "sparkles")
                        Spacer()
                        Button("Exit demo") { store.disableDemo() }.buttonStyle(.link)
                    }.font(.caption).foregroundStyle(.secondary)
                        .padding(12).background(Brand.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                hero
                if device.connection == .bluetooth && !device.isAvailable {
                    HStack(spacing: 14) {
                        Image(systemName: "antenna.radiowaves.left.and.right").font(.title2).foregroundStyle(Brand.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.isConnecting ? "Getting to know your light…" : "Connect to start controlling this light").font(.headline)
                            Text("Keep it nearby and close other Bluetooth controllers.").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(device.isConnecting ? "Connecting…" : "Connect") { store.connect(device) }
                            .buttonStyle(.borderedProminent).disabled(device.isConnecting)
                    }.surface()
                } else if device.connection == .lan && !device.isAvailable {
                    HStack {
                        Label("Waiting for a response. Check LAN Control and your network.", systemImage: "wifi.exclamationmark")
                            .font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Button("Retry") { Task { await store.scanLAN() } }
                    }.surface()
                }
                if !device.heads.isEmpty { Text("Whole lamp").font(.title3.weight(.semibold)) }
                LightControlsView(store: store, device: device)
                    .disabled(!device.isAvailable)
                if !device.heads.isEmpty {
                    HeadControlsView(store: store, device: device).disabled(!device.isAvailable)
                }
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Set the mood").font(.title3.weight(.semibold))
                        Text("A good look is one click away.").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { presetName = ""; savingPreset = true } label: {
                        Label("Save current look", systemImage: "plus")
                    }.disabled(!device.isAvailable || (!device.heads.isEmpty && !device.heads.allSatisfy(\.hasRequestedState)))
                }
                PresetsView(store: store, device: device)
                connectionDetails
            }.padding(30).frame(maxWidth: 920).frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $renaming) {
            nameSheet(title: "Name your light", prompt: "A name that feels at home.", name: $newName, actionTitle: "Save") {
                store.rename(device.id, to: newName); renaming = false
            }
        }
        .sheet(isPresented: $savingPreset) {
            nameSheet(title: "Save this look", prompt: "Keep these colors and brightness levels for next time.", name: $presetName, actionTitle: "Save preset") {
                store.savePreset(name: presetName, device: device); savingPreset = false
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 7) {
                    Circle().fill(device.isAvailable ? Brand.accent : .secondary).frame(width: 6, height: 6)
                    Text(device.connection.title.uppercased()).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.8).foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(device.name).font(.system(size: 31, weight: .semibold, design: .rounded)).tracking(-0.7).lineLimit(2)
                    Button { newName = device.name; renaming = true } label: { Image(systemName: "pencil") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Rename light").accessibilityLabel("Rename light")
                }
                HStack(spacing: 8) {
                    Text(device.model)
                    Text("·")
                    Text(device.status)
                }.font(.callout).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: device.connection == .lan ? "checkmark.shield" : "antenna.radiowaves.left.and.right")
                    Text(device.connection == .lan ? "Direct to your light. No cloud in between." : device.connection == .demo ? "Explore freely. No hardware connected." : "A direct Bluetooth connection to your light.")
                }.font(.caption).foregroundStyle(.secondary).padding(.top, 4)
            }
            Spacer(minLength: 0)
            LightArtwork(color: device.state.color.swiftUIColor, isOn: device.state.isOn && device.hasKnownState)
                .frame(width: 155, height: 166).accessibilityHidden(true)
        }.padding(.vertical, 4)
    }

    private var connectionDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Connection", systemImage: device.connection.symbol).font(.headline)
                Spacer()
                Button { store.toggleFavorite(device.id) } label: {
                    Label(store.favorites.contains(device.id) ? "Favorited" : "Favorite", systemImage: store.favorites.contains(device.id) ? "star.fill" : "star")
                }.buttonStyle(.borderless)
                if device.connection == .bluetooth && device.isAvailable {
                    Button("Disconnect") { store.disconnect(device) }
                }
            }
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TRANSPORT").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5).foregroundStyle(.secondary)
                    Text(device.usesEncryptedBLE ? "Bluetooth · encrypted session" : device.connection.title).font(.callout)
                }
                if !device.address.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(device.connection == .lan ? "IP ADDRESS" : "IDENTIFIER").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5).foregroundStyle(.secondary)
                        Text(device.address).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    }
                }
                Spacer(minLength: 0)
            }
            Text(device.connection == .demo ? "This virtual light is for previewing the app." : "Power and brightness are read from the light. Color shows the last requested value when the light reports only its mode. Check the physical light to confirm a color change.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let sent = device.lastSent {
                Text("Last command sent \(sent.formatted(date: .omitted, time: .standard))").font(.caption2).foregroundStyle(.secondary)
            }
        }.surface()
    }

    private func nameSheet(title: String, prompt: String, name: Binding<String>, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.weight(.semibold))
            Text(prompt).foregroundStyle(.secondary)
            TextField("Name", text: name).textFieldStyle(.roundedBorder).onSubmit(action)
            HStack {
                Spacer()
                Button("Cancel") { renaming = false; savingPreset = false }.keyboardShortcut(.cancelAction)
                Button(actionTitle, action: action).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(name.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(28).frame(width: 380)
    }
}

extension View {
    func surface() -> some View {
        self.padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary))
    }
}
