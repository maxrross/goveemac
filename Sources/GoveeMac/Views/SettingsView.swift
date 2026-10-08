import SwiftUI

struct SettingsView: View {
    let store: LightStore
    @AppStorage("showMenuBar") private var showMenuBar = true

    var body: some View {
        Form {
            Section("Govee Mac") {
                Toggle("Show quick controls in the menu bar", isOn: $showMenuBar)
                LabeledContent("Version", value: "0.1.0")
            }
            Section("Preview") {
                Toggle("Explore with demo lights", isOn: Binding(get: { store.isDemo }, set: {
                    if $0 { store.enableDemo() } else { store.disableDemo() }
                }))
                Text("Demo lights are virtual and labeled in the app.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Community") {
                Link("Source code & contributions", destination: Brand.repository)
                Link("Report an issue", destination: Brand.repository.appendingPathComponent("issues/new/choose"))
                Text("An independent, community-built project. Not affiliated with Govee. No accounts, API keys, analytics, or cloud requests.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).frame(width: 470, height: 420)
    }
}
