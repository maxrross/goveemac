import SwiftUI
import GoveeKit

struct WelcomeView: View {
    let store: LightStore
    let discover: (ConnectionKind) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("HELLO, BRIGHTER DAYS")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(2).foregroundStyle(Brand.accent)
                        Text("Your lights.\nYour Mac.")
                            .font(.system(size: 43, weight: .semibold, design: .rounded))
                            .tracking(-1.5).fixedSize(horizontal: false, vertical: true)
                        Text("Set the mood without reaching\nfor your phone.")
                            .font(.system(size: 15)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    LightArtwork(color: Brand.accent, isOn: true).frame(width: 185, height: 210)
                        .accessibilityHidden(true)
                }
                HStack(spacing: 12) {
                    connectionCard(.lan, title: "Connect with Wi-Fi", detail: "Discover LAN-enabled lights\non your local network.")
                    connectionCard(.bluetooth, title: "Connect with Bluetooth", detail: "Find compatible BLE lights\nclose to your Mac.")
                }
                VStack(alignment: .leading, spacing: 18) {
                    Text("A quick setup, then you’re glowing.").font(.headline)
                    setupRow("1", title: "Power on your light", detail: "Keep your Mac nearby, or on the same Wi-Fi network.")
                    setupRow("2", title: "Choose how to connect", detail: "For Wi-Fi, enable LAN Control in the light’s Govee Home settings.")
                    setupRow("3", title: "Make it yours", detail: "Pick a color, dial in the brightness, and save your favorite looks.")
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
                HStack {
                    Label("Local control. No account required.", systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Explore demo") { store.enableDemo() }.buttonStyle(.link)
                }
            }.padding(36).frame(maxWidth: 790)
                .frame(maxWidth: .infinity)
        }
    }

    private func connectionCard(_ kind: ConnectionKind, title: String, detail: String) -> some View {
        Button { discover(kind) } label: {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: kind.symbol).font(.system(size: 21)).foregroundStyle(Brand.accent)
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(detail).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                HStack { Text("Find lights").fontWeight(.medium); Spacer(); Image(systemName: "arrow.right") }
                    .font(.callout).foregroundStyle(Brand.accent).padding(.top, 5)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary))
        }.buttonStyle(.plain)
    }

    private func setupRow(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Brand.accent).frame(width: 24, height: 24)
                .background(Brand.accent.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct LightArtwork: View {
    var color: Color
    var isOn: Bool
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [color.opacity(isOn ? 0.25 : 0.03), .clear], center: .center, startRadius: 8, endRadius: 100))
                .frame(width: 230, height: 230)
            Circle().stroke(color.opacity(0.10), lineWidth: 1).frame(width: 155, height: 155)
            Circle().stroke(color.opacity(0.07), lineWidth: 1).frame(width: 198, height: 198)
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 15).fill(LinearGradient(colors: [color.opacity(isOn ? 0.9 : 0.2), color.opacity(isOn ? 0.35 : 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 74, height: 94)
                    .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(color.opacity(0.5)))
                    .shadow(color: color.opacity(isOn ? 0.35 : 0), radius: 25)
                Rectangle().fill(.secondary.opacity(0.5)).frame(width: 3, height: 40)
                Ellipse().fill(.secondary.opacity(0.3)).frame(width: 65, height: 9)
            }
            Image(systemName: "sparkle").font(.system(size: 16)).foregroundStyle(color.opacity(0.6)).offset(x: 67, y: -60)
        }
    }
}
