import SwiftUI
import GoveeKit
import ShadcnUI

struct SyncControlsView: View {
    let store: LightStore
    let device: LightDevice
    let screen: Bool
    @Environment(\.shadcnPalette) private var palette
    private var live: LiveController { store.live }
    private var mode: String { screen ? "Screen match" : "Music" }
    private var isActive: Bool { live.deviceID == device.id && live.mode == mode }
    private var labels: [String] {
        if !screen { return ["Bass", "Mids", "Treble"] }
        if live.mapping == "columns" { return ["Left", "Center", "Right"] }
        return ["Bottom", "Middle", "Top"]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x5) {
            VStack(alignment: .leading, spacing: 8) {
                Text(screen ? "Screen matching" : "Music sync").font(.title2.weight(.semibold))
                ShadcnCardDescription(screen
                    ? "Match the colors you see on your display. Choose how its regions map to your light."
                    : "Color changes on the beat, with bass, mids and treble controlling each head’s energy.")
            }
            ControlPanel {
                if screen {
                    HStack(spacing: 12) {
                        Text("Display").font(.callout)
                        Menu {
                            Picker("Display", selection: Binding(get: { live.displayID ?? 0 }, set: { live.displayID = $0 == 0 ? nil : $0 })) {
                                Text("Main display").tag(UInt32(0))
                                ForEach(live.displays) { Text($0.name).tag($0.id) }
                            }
                        } label: {
                            HStack { Text(live.displays.first { $0.id == live.displayID }?.name ?? "Main display"); Image(systemName: "chevron.down").font(.caption2) }
                        }.buttonStyle(.shadcn(.secondary)).menuIndicator(.hidden)
                        Spacer(minLength: 0)
                        ShadcnButton(icon: "arrow.clockwise", variant: .secondary, size: .iconSM) { Task { await live.refreshDisplays() } }
                            .accessibilityLabel("Refresh displays")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color regions").font(.callout)
                        ShadcnTabs(selection: Binding(get: { live.mapping }, set: { live.mapping = $0 }),
                                   items: [("rows", "Vertical"), ("columns", "Horizontal"), ("whole", "Whole screen")])

                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color style").font(.callout)
                        ShadcnTabs(selection: Binding(get: { live.screenStyle }, set: { live.screenStyle = $0 }),
                                   items: [("vivid", "Vivid"), ("average", "Average")])
                        ShadcnCardDescription("Vivid brings out colored areas on a dark screen. Average follows the overall color.")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Audio source").font(.callout)
                        ShadcnTabs(selection: Binding(get: { live.source }, set: { live.source = $0 }),
                                   items: [("system", "System audio"), ("microphone", "Microphone")])

                    }
                    VStack(spacing: 8) {
                        HStack {
                            Text("Sensitivity").font(.callout)
                            Spacer()
                            Text("\(live.sensitivity, specifier: "%.1f")×").font(.callout.monospacedDigit())
                        }
                        ShadcnSlider(value: Binding(get: { live.sensitivity }, set: { live.sensitivity = $0 }), in: 0.2...5, step: 0.1)
                            .accessibilityLabel("Music sensitivity")
                    }
                }
                if screen {
                    Group {
                        if let image = live.screenImage, isActive {
                            Image(nsImage: image).resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                                .accessibilityLabel("Live preview of the captured display")
                        } else {
                            RoundedRectangle(cornerRadius: 8).fill(palette.muted)
                                .overlay { Label("Display preview", systemImage: "display").font(.callout).foregroundStyle(palette.mutedForeground) }
                        }
                    }
                    .frame(maxWidth: 360)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                HStack(alignment: .top, spacing: 12) {
                    ForEach(0..<3, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isActive && live.hasCaptureInput ? live.preview[i].swiftUIColor : palette.muted)
                                .frame(height: 52)
                                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(palette.border) }
                            HStack {
                                Text(labels[i]).font(.caption.weight(.medium))
                                Spacer(minLength: 0)
                                if isActive && live.hasCaptureInput { Text(live.preview[i].hex).font(.caption2.monospaced()).foregroundStyle(palette.mutedForeground) }
                            }
                            if !screen {
                                GeometryReader { geometry in
                                    Capsule().fill(palette.muted)
                                        .overlay(alignment: .leading) {
                                            Capsule().fill(palette.primary)
                                                .frame(width: geometry.size.width * min(1, (isActive ? live.levels[i] : 0) * 20))
                                        }
                                }.frame(height: 4)
                            }
                        }.frame(maxWidth: .infinity)
                    }
                }
                HStack(spacing: 8) {
                    Circle().fill(isActive && live.hasCaptureInput ? Color.green : palette.mutedForeground).frame(width: 6, height: 6)
                    Text(isActive ? live.captureStatus : "Ready — start \(screen ? "screen matching" : "music sync") to see live colors")
                        .font(.caption).foregroundStyle(palette.mutedForeground).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if isActive && live.outputFPS > 0 { Text("\(live.outputFPS, specifier: "%.1f") fps").font(.caption.monospacedDigit()).foregroundStyle(palette.mutedForeground) }
                }
                ShadcnWrapLayout(spacing: 8) {
                    ShadcnButton(live.isStarting ? "Starting…" : "\(isActive ? "Restart" : "Start") \(screen ? "screen matching" : "music sync")", systemImage: "play.fill") { start() }
                        .disabled(!device.isAvailable || live.isStarting)
                    if live.deviceID == device.id {
                        ShadcnButton("Stop & restore", systemImage: "stop.fill", variant: .secondary) { Task { await live.stop(restore: true) } }
                    }
                }
                ShadcnCardDescription(screen || live.source == "system"
                    ? "Uses macOS Screen & System Audio Recording access. Nothing is recorded or uploaded."
                    : "Uses macOS Microphone access. Nothing is recorded or uploaded.")
            }
            ShadcnCardDescription("Source and display changes apply immediately while running. Manual edits stop sync. Stop & restore returns to your previous look.")
        }
        .task { if screen { await live.refreshDisplays() } }
        .onChange(of: live.source) { _, _ in if isActive && !screen { start() } }
        .onChange(of: live.displayID) { _, _ in if isActive && screen { start() } }
        .onChange(of: live.mapping) { _, _ in if isActive && screen { start() } }
        .onChange(of: live.screenStyle) { _, _ in if isActive && screen { start() } }
    }

    private func start() {
        guard !live.isStarting else { return }
        Task {
            do { try await live.start(mode: mode, device: device) }
            catch is CancellationError { }
            catch { store.errorMessage = error.localizedDescription }
        }
    }
}
