import AppKit
import SwiftUI
import UniformTypeIdentifiers
import GoveeKit
import ShadcnUI

struct SceneBrowserView: View {
    let store: LightStore
    let device: LightDevice
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    @State private var category = "All"
    @State private var importing = false
    private var library: [NativeScene] { store.scenes[device.model] ?? [] }
    private var categories: [String] { ["All"] + Array(Set(library.map(\.category))).sorted() }
    private var filtered: [NativeScene] { library.filter { (category == "All" || $0.category == category) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ControlPanel {
                ShadcnCardTitle("Mac effects")
                ShadcnCardDescription("These replace your current lighting. Breathe pulses your selected color; the other effects use their own colors. Keep Govee Mac open while they run.")
                ShadcnWrapLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(LiveEffect.allCases, id: \.self) { effect in
                        ShadcnButton(effect.title, variant: store.live.deviceID == device.id && store.live.mode == effect.title ? .primary : .secondary, size: .small) {
                            guard !store.live.isStarting else { return }
                            Task {
                                do { try await store.live.start(mode: effect.title, device: device, effect: effect) }
                                catch is CancellationError { }
                                catch { store.errorMessage = error.localizedDescription }
                            }
                        }.disabled(!device.isAvailable)
                    }
                }
                HStack {
                    Text("Speed").font(.caption).foregroundStyle(.secondary)
                    ShadcnSlider(value: Binding(get: { store.live.speed }, set: { store.live.speed = $0 }), in: 0.1...5, step: 0.1).frame(maxWidth: 220).accessibilityLabel("Effect speed")
                    Text("\(store.live.speed, specifier: "%.1f")×").font(.caption.monospacedDigit())
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    ShadcnCardTitle("Govee scenes")
                    ShadcnCardDescription(store.sceneStatus[device.model] ?? "Loading your model’s library…")
                }
                Spacer()
                if store.loadingScenes.contains(device.model) { ProgressView().controlSize(.small) }
                ShadcnButton(icon: "arrow.clockwise", variant: .secondary, size: .iconSM) { Task { await store.loadScenes(model: device.model, refresh: true) } }
                    .help("Refresh Govee scene library").disabled(store.loadingScenes.contains(device.model))
                ShadcnButton("Import JSON", systemImage: "square.and.arrow.down", variant: .secondary, size: .small) { importing = true }
            }
            HStack(spacing: 12) {
                ShadcnTextField("Search scenes", text: $query).accessibilityLabel("Search scenes")
                Menu {
                    Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }
                } label: {
                    HStack(spacing: 8) { Text(category); Image(systemName: "chevron.down").font(.caption2) }
                }.buttonStyle(.shadcn(.secondary)).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("Scene category")
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                ForEach(filtered) { scene in
                    Button {
                        Task { _ = await store.applyScene(scene, to: device.id) }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 8).fill(palette.muted)
                                .frame(height: 58)
                                .overlay {
                                    AsyncImage(url: sceneIcon(scene)) { image in
                                        image.resizable().scaledToFit()
                                    } placeholder: {
                                        Image(systemName: "sparkles").font(.title2).foregroundStyle(palette.mutedForeground)
                                    }.frame(width: 44, height: 44).accessibilityHidden(true)
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: store.activeScenes[device.id] == scene.name ? "checkmark.circle.fill" : "play.fill")
                                        .font(.caption).foregroundStyle(palette.foreground).padding(8)
                                }
                            Text(scene.name).font(.callout.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                            Text(scene.category).font(.caption2).foregroundStyle(.secondary)
                        }.padding(10).background(.background, in: RoundedRectangle(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.08)) }
                    }.buttonStyle(.plain).accessibilityLabel("Apply Govee scene \(scene.name)")
                        .disabled(!device.isAvailable)
                }
            }
            if filtered.isEmpty && !store.loadingScenes.contains(device.model) {
                ContentUnavailableView("No matching scenes", systemImage: "sparkles", description: Text("Try another category or refresh the library."))
            }
        }
        .task { await store.loadScenes(model: device.model) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            Task {
                do { let url = try result.get(); _ = try await store.importLibrary(url: url, model: device.model) }
                catch { store.errorMessage = error.localizedDescription }
            }
        }
    }
    private func sceneIcon(_ scene: NativeScene) -> URL? {
        // Selection only changes the checkmark. Keep the image URL stable so
        // clicking a scene cannot replace its thumbnail with a loading state.
        guard let icons = scene.iconURLs, !icons.isEmpty else { return nil }
        return colorScheme == .dark && icons.count >= 3 ? icons[2] : icons[0]
    }
}
