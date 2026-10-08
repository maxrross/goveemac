import SwiftUI
import GoveeKit

struct SyncControlsView: View {
    let store: LightStore
    let device: LightDevice
    let screen: Bool
    private var live: LiveController { store.live }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: screen ? "display" : "waveform").font(.system(size: 28)).foregroundStyle(.tint)
                Text(screen ? "Bring your screen into the room" : "Let your music set the mood")
                    .font(.title2.weight(.semibold))
                Text(screen ? "Match the colors on your display, with a separate region for each lamp head." : "Bass, mids, and treble drive the three heads. Any app’s audio can set the rhythm.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 16) {
                if screen {
                    HStack {
                        Picker("Display", selection: Binding(get: { live.displayID ?? 0 }, set: { live.displayID = $0 == 0 ? nil : $0 })) {
                            Text("Default display").tag(UInt32(0))
                            ForEach(live.displays) { Text($0.name).tag($0.id) }
                        }
                        Button("Find displays") { Task { await live.refreshDisplays() } }.controlSize(.small)
                    }
                    Picker("Color regions", selection: Binding(get: { live.mapping }, set: { live.mapping = $0 })) {
                        Text("Vertical · bottom / middle / top").tag("rows")
                        Text("Horizontal · left / center / right").tag("columns")
                        Text("Whole screen").tag("whole")
                    }
                } else {
                    Picker("Audio source", selection: Binding(get: { live.source }, set: { live.source = $0 })) {
                        Text("System audio").tag("system")
                        Text("Microphone").tag("microphone")
                    }.pickerStyle(.segmented)
                    HStack {
                        Text("Sensitivity").font(.callout)
                        Slider(value: Binding(get: { live.sensitivity }, set: { live.sensitivity = $0 }), in: 0.2...5)
                        Text("\(live.sensitivity, specifier: "%.1f")×").font(.caption.monospacedDigit()).frame(width: 40)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 8).fill(live.preview[i].swiftUIColor.gradient)
                            .frame(height: 48).overlay { Text(screen ? ["Bottom","Middle","Top"][i] : ["Bass","Mids","Treble"][i]).font(.caption.weight(.medium)).foregroundStyle(.white).shadow(radius: 2) }
                    }
                }
                HStack {
                    Button(live.isStarting ? "Starting…" : "Start \(screen ? "screen match" : "music sync")", systemImage: "play.fill") {
                        Task { do { try await live.start(mode: screen ? "Screen match" : "Music", device: device) } catch { store.errorMessage = error.localizedDescription } }
                    }.buttonStyle(.borderedProminent).disabled(!device.isAvailable || live.isStarting)
                    if live.isRunning {
                        Button("Stop & restore", systemImage: "stop.fill") { Task { await live.stop(restore: true) } }.buttonStyle(.bordered)
                    }
                }
                Text(screen || live.source == "system" ? "macOS asks for Screen & System Audio Recording access when you start. Capture stays on your Mac; no recordings are saved." : "macOS asks for Microphone access when you start. Audio stays on your Mac; no recordings are saved.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(20).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            Text("Change the source or display, then press Start again to apply it. Manual color controls stop sync. Native Govee scenes keep playing on the light; Mac effects, music, and screen matching need this app running.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
