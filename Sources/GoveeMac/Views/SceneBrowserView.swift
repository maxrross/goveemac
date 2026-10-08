import AppKit
import SwiftUI
import UniformTypeIdentifiers
import GoveeKit
import ShadcnUI

struct SceneBrowserView: View {
    let store: LightStore
    let device: LightDevice
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
                ShadcnCardDescription("Continuous colors driven by your Mac. Adjust speed while an effect is running.")
                ShadcnWrapLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(LiveEffect.allCases, id: \.self) { effect in
                        ShadcnButton(effect.title, variant: store.live.deviceID == device.id && store.live.mode == effect.title ? .primary : .secondary, size: .small) {
                            Task { do { try await store.live.start(mode: effect.title, device: device, effect: effect) } catch { store.errorMessage = error.localizedDescription } }
                        }.disabled(!device.isAvailable || store.live.isStarting)
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
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: sceneColors(scene), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 58)
                                .overlay(alignment: .bottomTrailing) { Image(systemName: store.activeScenes[device.id] == scene.name ? "checkmark.circle.fill" : "play.fill").font(.caption).foregroundStyle(.white).padding(8) }
                            Text(scene.name).font(.callout.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                            Text(scene.category).font(.caption2).foregroundStyle(.secondary)
                        }.padding(10).background(.background, in: RoundedRectangle(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.08)) }
                    }.buttonStyle(.plain).accessibilityLabel("Apply Govee scene \(scene.name)")
                        .disabled(!device.isAvailable || store.busyIDs.contains(device.id))
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
    private func sceneColors(_ scene: NativeScene) -> [Color] {
        // Procedural thumbnails, not copies of Govee's proprietary artwork.
        let seed = scene.name.utf8.reduce(0) { ($0*31+Int($1)) % 360 }
        return [LiveColors.hsv(Double(seed)/360, saturation: 0.8, value: 0.8).swiftUIColor,
                LiveColors.hsv(Double(seed+65)/360, saturation: 0.75, value: 0.4).swiftUIColor]
    }
}
