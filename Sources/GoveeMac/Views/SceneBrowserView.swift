import AppKit
import SwiftUI
import UniformTypeIdentifiers
import GoveeKit

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
            VStack(alignment: .leading, spacing: 12) {
                Text("Mac effects").font(.headline)
                Text("Continuous colors driven by your Mac. Speed applies while an effect is running.").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 8) {
                    ForEach(LiveEffect.allCases, id: \.self) { effect in
                        Button(effect.title) {
                            Task { do { try await store.live.start(mode: effect.title, device: device, effect: effect) } catch { store.errorMessage = error.localizedDescription } }
                        }.buttonStyle(.bordered).controlSize(.small).disabled(!device.isAvailable || store.live.isStarting)
                    }
                  }
                }
                HStack {
                    Text("Speed").font(.caption).foregroundStyle(.secondary)
                    Slider(value: Binding(get: { store.live.speed }, set: { store.live.speed = $0 }), in: 0.1...5).frame(maxWidth: 220)
                    Text("\(store.live.speed, specifier: "%.1f")×").font(.caption.monospacedDigit())
                }
            }.padding(16).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Govee scenes").font(.headline)
                    Text(store.sceneStatus[device.model] ?? "Loading your model’s library…").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if store.loadingScenes.contains(device.model) { ProgressView().controlSize(.small) }
                Button { Task { await store.loadScenes(model: device.model, refresh: true) } } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh Govee scene library").disabled(store.loadingScenes.contains(device.model))
                Button("Import JSON", systemImage: "square.and.arrow.down") { importing = true }
                    .controlSize(.small)
            }
            HStack {
                TextField("Search scenes", text: $query).textFieldStyle(.roundedBorder)
                Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }.frame(maxWidth: 200)
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
