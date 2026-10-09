import SwiftUI
import ShadcnUI

struct SettingsView: View {
    let store: LightStore
    @AppStorage("showMenuBar") private var showMenuBar = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Space.x4) {
                HStack {
                    Text("Settings").font(.largeTitle.weight(.semibold))
                    Spacer()
                    ShadcnButton("Back to light", systemImage: "chevron.left", variant: .secondary, size: .small) { store.showsSettings = false }
                }
                FlatCard {
                    ShadcnCardHeader {
                        ShadcnCardTitle("Govee Mac")
                        ShadcnCardDescription("Quick access to your lights.")
                    }
                    ShadcnCardContent {
                        HStack {
                            Text("Show controls in the menu bar").font(.callout)
                            Spacer()
                            ShadcnSwitch(isOn: $showMenuBar).accessibilityLabel("Show quick controls in the menu bar")
                        }
                        ShadcnSeparator()
                        LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development").font(.callout)
                    }
                }
                FlatCard {
                    ShadcnCardHeader { ShadcnCardTitle("CLI & agents") }
                    ShadcnCardContent {
                        Text(store.cliStatus).font(.callout)
                        Text("The bundled govee command controls this app using a socket accessible only to your Mac user.").font(.caption).foregroundStyle(.secondary)
                        Text(Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/govee").path)
                            .font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                if let device = store.selectedDevice { FlatCard {
                    ShadcnCardHeader { ShadcnCardTitle("Light diagnostics") }
                    ShadcnCardContent {
                        LabeledContent("Light", value: device.name)
                        LabeledContent("Model", value: device.model)
                        LabeledContent("Connection", value: device.usesEncryptedBLE ? "Bluetooth · encrypted session" : device.connection.title)
                        LabeledContent(device.connection == .lan ? "IP address" : "Identifier") {
                            Text(device.address).font(.caption.monospaced()).textSelection(.enabled)
                        }
                    }
                } }
            }.padding(Space.x6).frame(maxWidth: 800).frame(maxWidth: .infinity)
                .background(ScrollIndicatorHider())
        }.scrollIndicators(.hidden)
    }
}
