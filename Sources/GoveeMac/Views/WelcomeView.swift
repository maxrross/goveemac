import SwiftUI
import GoveeKit
import ShadcnUI

struct WelcomeView: View {
    let discover: (ConnectionKind) -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Add your first light", systemImage: "lamp.floor")
        } actions: {
            HStack(spacing: Space.x3) {
                ShadcnButton("Bluetooth", systemImage: ConnectionKind.bluetooth.symbol) { discover(.bluetooth) }
                    .accessibilityLabel("Find Bluetooth lights")
                ShadcnButton("Wi-Fi", systemImage: "wifi", variant: .outline) { discover(.lan) }
                    .accessibilityLabel("Find Wi-Fi lights")
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
