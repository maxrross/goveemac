import SwiftUI
import ShadcnUI

struct SettingsView: View {
    let store: LightStore
    @AppStorage("showMenuBar") private var showMenuBar = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.x4) {
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
                        LabeledContent("Version", value: "0.2.0").font(.callout)
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
                FlatCard {
                    ShadcnCardHeader {
                        ShadcnCardTitle("Community")
                        ShadcnCardDescription("An independent, community-built project. Not affiliated with Govee. No account or API key required. Govee scene definitions are downloaded on request and cached locally. Screen and audio data stays on your Mac.")
                    }
                    ShadcnCardContent {
                        Link("Source code & contributions", destination: Brand.repository)
                            .buttonStyle(.shadcn(.link, size: .small))
                        Link("Report an issue", destination: Brand.repository.appendingPathComponent("issues/new/choose"))
                            .buttonStyle(.shadcn(.link, size: .small))
                    }
                }
            }.padding(Space.x6)
        }.frame(width: 510, height: 600)
    }
}
