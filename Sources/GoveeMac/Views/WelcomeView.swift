import AppKit
import SwiftUI
import GoveeKit
import ShadcnUI

struct WelcomeView: View {
    let store: LightStore
    let discover: (ConnectionKind) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.x6) {
                HStack(spacing: Space.x4) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit()
                        .frame(width: 80, height: 80).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Space.x2) {
                        Text("Your lights. Your Mac.").font(.title.weight(.semibold))
                        ShadcnCardDescription("Set the mood without reaching for your phone.")
                    }
                }
                HStack(alignment: .top, spacing: Space.x4) {
                    connectionCard(.lan, title: "Local Wi-Fi", detail: "Discover LAN-enabled lights on your local network.")
                    connectionCard(.bluetooth, title: "Bluetooth", detail: "Find compatible BLE lights close to your Mac.")
                }
                ShadcnCard {
                    ShadcnCardHeader {
                        ShadcnCardTitle("Get started")
                        ShadcnCardDescription("A few steps to connect your first light.")
                    }
                    ShadcnCardContent {
                        setupRow("1", title: "Power on your light", detail: "Keep your Mac nearby, or on the same Wi-Fi network.")
                        ShadcnSeparator()
                        setupRow("2", title: "Choose how to connect", detail: "For Wi-Fi, enable LAN Control in your light’s Govee Home settings.")
                        ShadcnSeparator()
                        setupRow("3", title: "Make it yours", detail: "Pick a color, adjust brightness, and save your favorite looks.")
                    }
                }
                HStack {
                    ShadcnBadge("Local control · No account required", systemImage: "lock.shield", variant: .outline)
                    Spacer()
                    ShadcnButton("Explore demo", variant: .link) { store.enableDemo() }
                }
            }.padding(Space.x6).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
    }

    private func connectionCard(_ kind: ConnectionKind, title: String, detail: String) -> some View {
        ShadcnCard {
            ShadcnCardHeader {
                Label(title, systemImage: kind.symbol).font(.headline)
                ShadcnCardDescription(detail)
            }
            ShadcnCardFooter {
                ShadcnButton("Find lights", variant: .outline, fillsWidth: true) { discover(kind) }
            }
        }
    }

    private func setupRow(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.x3) {
            ShadcnBadge(number, variant: .secondary)
            VStack(alignment: .leading, spacing: Space.x1) {
                Text(title).font(.callout.weight(.medium))
                ShadcnCardDescription(detail)
            }
        }
    }
}
