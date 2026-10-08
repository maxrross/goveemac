import SwiftUI
import GoveeKit

struct DiscoveryView: View {
    let store: LightStore
    let initialKind: ConnectionKind
    @Environment(\.dismiss) private var dismiss
    @State private var kind = ConnectionKind.lan
    @State private var manualAddress = ""
    @State private var manualName = ""
    @State private var adding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Make a connection").font(.title2.weight(.semibold))
                    Text("Bring your Govee lights to your Mac.").foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).keyboardShortcut(.cancelAction).accessibilityLabel("Close discovery")
            }
            Picker("Connection", selection: $kind) {
                Text("Local Wi-Fi").tag(ConnectionKind.lan)
                Text("Bluetooth").tag(ConnectionKind.bluetooth)
            }.pickerStyle(.segmented)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: kind.symbol).font(.title2).foregroundStyle(Brand.accent)
                VStack(alignment: .leading, spacing: 8) {
                    Text(kind == .lan ? store.lanStatus : store.bluetoothStatus).font(.callout)
                    Text(kind == .lan ? "In Govee Home, open your light → Settings → LAN Control. Enable it, and connect your Mac to the same network. Only supported Wi-Fi models have this setting." : "Power on your light and keep it near your Mac. Allow Bluetooth access when prompted. Close Govee Home if the light won’t connect.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }.surface()
            HStack {
                let scanning = kind == .lan ? store.isScanningLAN : store.isScanningBluetooth
                if scanning { ProgressView().controlSize(.small); Text("Searching…").font(.callout).foregroundStyle(.secondary) }
                Spacer()
                Button("Scan again") { scan() }.disabled(scanning).buttonStyle(.borderedProminent)
            }
            let found = store.devices.filter { $0.connection == kind }
            if !found.isEmpty {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(found) { device in
                            HStack {
                                Image(systemName: "lightbulb").foregroundStyle(Brand.accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.name).font(.callout.weight(.medium))
                                    Text("\(device.model) · \(device.status)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Select") { store.selectedID = device.id; dismiss() }
                            }.padding(12).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }.frame(maxHeight: 170)
            }
            if kind == .lan {
                DisclosureGroup("Know your light’s IP address?") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Use a manual IP when your router blocks multicast discovery. The light still needs LAN Control enabled.").font(.caption).foregroundStyle(.secondary)
                        TextField("IPv4 address, e.g. 192.168.1.50", text: $manualAddress)
                        TextField("Light name (optional)", text: $manualName)
                        HStack {
                            Spacer()
                            Button(adding ? "Adding…" : "Add light") {
                                adding = true
                                Task {
                                    let success = await store.addManual(address: manualAddress, name: manualName)
                                    adding = false
                                    if success { dismiss() }
                                }
                            }.disabled(adding || manualAddress.isEmpty)
                        }
                    }.padding(.top, 10).textFieldStyle(.roundedBorder)
                }
            }
            HStack {
                Link("Compatibility guide", destination: Brand.repository.appendingPathComponent("blob/main/docs/COMPATIBILITY.md"))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }.font(.callout)
        }.padding(28).frame(width: 500)
            .onAppear { kind = initialKind; scan() }
            .onChange(of: kind) { _, _ in scan() }
    }

    private func scan() {
        if kind == .lan { Task { await store.scanLAN() } }
        else { store.scanBluetooth() }
    }
}
