import SwiftUI
import ShadcnUI

struct SettingsView: View {
    let store: LightStore
    @AppStorage("showMenuBar") private var showMenuBar = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.x4) {
                ShadcnCard {
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
                        LabeledContent("Version", value: "0.1.0").font(.callout)
                    }
                }
                ShadcnCard {
                    ShadcnCardHeader {
                        ShadcnCardTitle("Preview")
                        ShadcnCardDescription("Demo lights are virtual and labeled in the app.")
                    }
                    ShadcnCardContent {
                        HStack {
                            Text("Explore with demo lights").font(.callout)
                            Spacer()
                            ShadcnSwitch(isOn: Binding(get: { store.isDemo }, set: {
                                if $0 { store.enableDemo() } else { store.disableDemo() }
                            })).accessibilityLabel("Explore with demo lights")
                        }
                    }
                }
                ShadcnCard {
                    ShadcnCardHeader {
                        ShadcnCardTitle("Community")
                        ShadcnCardDescription("An independent, community-built project. Not affiliated with Govee. No accounts, API keys, analytics, or cloud requests.")
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
