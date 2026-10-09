import AppKit
import SwiftUI
import UniformTypeIdentifiers
import GoveeKit
import ShadcnUI

struct SceneBrowserView: View {
    let store: LightStore
    let deviceID: String
    let model: String
    let available: Bool
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @Binding private var query: String
    @Binding private var category: String
    @State private var importing = false
    init(store: LightStore, device: LightDevice, query: Binding<String>, category: Binding<String>) {
        self.store = store; deviceID = device.id; model = device.model; available = device.isAvailable
        _query = query; _category = category
    }
    private var library: [NativeScene] { store.scenes[model] ?? [] }
    private var categories: [String] { ["All"] + Array(Set(library.map(\.category))).sorted() }
    private var filtered: [NativeScene] { library.filter { (category == "All" || $0.category == category) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    ShadcnCardTitle("Govee scenes")
                    ShadcnCardDescription(store.sceneStatus[model] ?? "Loading your model’s library…")
                }
                Spacer()
                if store.loadingScenes.contains(model) { ProgressView().controlSize(.small) }
                ShadcnButton(icon: "arrow.clockwise", variant: .secondary, size: .iconSM) { Task { await store.loadScenes(model: model, refresh: true) } }
                    .help("Refresh Govee scene library").disabled(store.loadingScenes.contains(model))
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
                        Task { _ = await store.applyScene(scene, to: deviceID) }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 8).fill(palette.muted)
                                .frame(height: 96)
                                .overlay {
                                    SceneIconView(url: sceneIcon(scene))
                                        .frame(width: 76, height: 76).accessibilityHidden(true)
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: store.activeScenes[deviceID] == scene.name ? "checkmark.circle.fill" : "play.fill")
                                        .font(.caption).foregroundStyle(palette.foreground).padding(8)
                                }
                            Text(scene.name).font(.callout.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                            Text(scene.category).font(.caption2).foregroundStyle(.secondary)
                        }.padding(10).background(.background, in: RoundedRectangle(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.08)) }
                    }.buttonStyle(.plain).accessibilityLabel("Apply Govee scene \(scene.name)")
                        .disabled(!available)
                }
            }
            if filtered.isEmpty && !store.loadingScenes.contains(model) {
                ContentUnavailableView("No matching scenes", systemImage: "sparkles", description: Text("Try another category or refresh the library."))
            }
        }
        .task { await store.loadScenes(model: model) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            Task {
                do { let url = try result.get(); _ = try await store.importLibrary(url: url, model: model) }
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
