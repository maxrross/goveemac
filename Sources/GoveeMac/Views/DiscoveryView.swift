import SwiftUI
import GoveeKit
import ShadcnUI

struct DiscoveryView: View {
    let store: LightStore
    let initialKind: ConnectionKind
    @Environment(\.dismiss) private var dismiss
    @State private var kind = ConnectionKind.lan
    @State private var manualOpen = false
    @State private var manualAddress = ""
    @State private var manualName = ""
    @State private var adding = false

    var body: some View {
        ScrollView {
            ShadcnCard {
                ShadcnCardHeader(content: {
                    ShadcnCardTitle("Make a connection")
                    ShadcnCardDescription("Bring your Govee lights to your Mac.")
                }, action: {
                    ShadcnButton(icon: "xmark", size: .iconSM) { dismiss() }
                        .keyboardShortcut(.cancelAction).accessibilityLabel("Close discovery")
                })
                ShadcnCardContent {
                    ShadcnTabs(selection: $kind, items: [(.lan, "Local Wi-Fi"), (.bluetooth, "Bluetooth")])
                    ShadcnAlert(systemImage: kind.symbol) {
                        ShadcnAlertTitle(kind == .lan ? "Local Wi-Fi" : "Bluetooth")
                        ShadcnAlertDescription(kind == .lan ? store.lanStatus : store.bluetoothStatus)
                        ShadcnAlertDescription(kind == .lan
                            ? "In Govee Home, open your light → Settings → LAN Control. Enable it, and connect your Mac to the same network. Only supported Wi-Fi models have this setting."
                            : "Power on your light and keep it near your Mac. Allow Bluetooth access when prompted. Close Govee Home if the light won’t connect.")
                    }
                    HStack {
                        let scanning = kind == .lan ? store.isScanningLAN : store.isScanningBluetooth
                        if scanning {
                            ProgressView().controlSize(.small)
                            Text("Searching…").font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        ShadcnButton("Scan again", systemImage: "arrow.clockwise", variant: .outline, size: .small, action: scan)
                            .disabled(scanning)
                    }
                    let found = store.devices.filter { $0.connection == kind }
                    if !found.isEmpty {
                        ForEach(found) { device in
                            ShadcnCard {
                                ShadcnCardHeader(content: {
                                    ShadcnCardTitle(device.name)
                                    ShadcnCardDescription("\(device.model) · \(device.status)")
                                }, action: {
                                    ShadcnButton("Select", variant: .outline, size: .small) {
                                        store.selectedID = device.id; dismiss()
                                    }.accessibilityLabel("Select \(device.name)")
                                })
                            }
                        }
                    }
                    if kind == .lan {
                        ShadcnCollapsible(isOpen: $manualOpen, spacing: Space.x4, trigger: { isOpen in
                            HStack {
                                Text("Know your light’s IP address?").font(.callout)
                                Spacer()
                                ShadcnDisclosureChevron(isOpen: isOpen)
                            }
                        }, content: {
                            VStack(alignment: .leading, spacing: Space.x3) {
                                ShadcnCardDescription("Use a manual IP when your router blocks multicast discovery. The light still needs LAN Control enabled.")
                                ShadcnTextField("IPv4 address, e.g. 192.168.1.50", text: $manualAddress)
                                    .accessibilityLabel("Light IP address")
                                ShadcnTextField("Light name (optional)", text: $manualName)
                                    .accessibilityLabel("Manual light name")
                                ShadcnButton(adding ? "Adding…" : "Add light", variant: .outline, size: .small) { addManualLight() }
                                    .disabled(adding || manualAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        })
                    }
                }
                ShadcnCardFooter {
                    Link("Compatibility guide", destination: Brand.repository.appendingPathComponent("blob/main/docs/COMPATIBILITY.md"))
                        .buttonStyle(.shadcn(.link, size: .small))
                    Spacer()
                    ShadcnButton("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                }
            }.padding(Space.x6)
        }.frame(width: 550, height: 640)
            .onAppear { kind = initialKind; scan() }
            .onChange(of: kind) { _, _ in scan() }
    }

    private func scan() {
        if kind == .lan { Task { await store.scanLAN() } }
        else { store.scanBluetooth() }
    }

    private func addManualLight() {
        adding = true
        Task {
            let success = await store.addManual(address: manualAddress, name: manualName)
            adding = false
            if success { dismiss() }
        }
    }
}
