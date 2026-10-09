import SwiftUI
import GoveeKit
import ShadcnUI

struct ColorEffectsBar: View {
    let store: LightStore
    let deviceID: String
    let available: Bool
    private var controller: ColorEffectController { store.live.colorEffects }
    private var active: Bool { controller.deviceID == deviceID }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("Effect").font(.callout.weight(.medium))
                Menu {
                    Button("None") { Task { if active { await controller.stop(restore: true) } } }
                    ForEach(ColorEffect.allCases, id: \.self) { effect in
                        Button(effect.title) {
                            guard let device = store.devices.first(where: { $0.id == deviceID }) else { return }
                            Task {
                                do { try await controller.start(effect, device: device) }
                                catch { store.errorMessage = error.localizedDescription }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(active ? controller.effect?.title ?? "None" : "None")
                        Image(systemName: "chevron.down").font(.caption2)
                    }.frame(minWidth: 75)
                }.buttonStyle(.shadcn(.secondary, size: .small)).menuIndicator(.hidden)
                    .accessibilityLabel("Effect over current colors")
                    .disabled(!available || controller.isStarting)
                Spacer(minLength: 0)
                Text("Speed").font(.caption).foregroundStyle(.secondary)
                ShadcnSlider(value: Binding(get: { controller.speed }, set: { controller.speed = $0 }), in: 0.1...5, step: 0.1)
                    .frame(maxWidth: 140).accessibilityLabel("Color effect speed")
                Text("\(controller.speed, specifier: "%.1f")×").font(.caption.monospacedDigit())
            }
            Text("Keeps your colors and Govee scenes; adds motion to brightness.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
