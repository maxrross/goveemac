import Foundation
import GoveeKit

extension LightStore {
    func loadScenes(model: String, refresh: Bool = false) async {
        if let pending = sceneLoads[model] { await pending.value; return }
        let task = Task { await self.fetchScenes(model: model, refresh: refresh) }
        sceneLoads[model] = task
        await task.value; sceneLoads[model] = nil
    }
    private func fetchScenes(model: String, refresh: Bool) async {
        guard !loadingScenes.contains(model), refresh || scenes[model] == nil,
              model.range(of: "^H[0-9A-F]{4}$", options: .regularExpression) != nil else { return }
        loadingScenes.insert(model); defer { loadingScenes.remove(model) }
        let cache = ControlSocket.directory.appendingPathComponent("Scenes", isDirectory: true).appendingPathComponent("\(model).json")
        do {
            if !refresh, let data = try? Data(contentsOf: cache) {
                scenes[model] = try NativeScene.parseLibrary(data, model: model)
                sceneStatus[model] = "\(scenes[model]?.count ?? 0) scenes · saved on this Mac"
                return
            }
            let url = URL(string: "https://app2.govee.com/appsku/v1/light-effect-libraries?sku=\(model)")!
            var request = URLRequest(url: url); request.timeoutInterval = 15
            request.setValue("6.5.02", forHTTPHeaderField: "AppVersion")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ControlError.message("Govee’s scene library is unavailable. Import a saved library or retry later.") }
            let library = try NativeScene.parseLibrary(data, model: model)
            guard !library.isEmpty else { throw ControlError.message("Govee has no local scene commands for this model.") }
            try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try data.write(to: cache, options: [.atomic]); scenes[model] = library
            sceneStatus[model] = "\(library.count) Govee scenes · saved for offline use"
        } catch { sceneStatus[model] = error.localizedDescription }
    }
    func importLibrary(url: URL, model: String) async throws -> String {
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try await Task.detached(priority: .utility) {
            let input = try FileHandle(forReadingFrom: url)
            defer { try? input.close() }
            let data = try input.read(upToCount: 8_000_001) ?? Data()
            guard data.count <= 8_000_000 else { throw ControlError.message("The import file is too large (maximum 8 MB).") }
            return data
        }.value
        return try importLibrary(data: data, model: model)
    }
    func importLibrary(data: Data, model: String) throws -> String {
        guard data.count <= 8_000_000 else { throw ControlError.message("The import file is too large (maximum 8 MB).") }
        if let looks = try? JSONDecoder().decode([LightPreset].self, from: data), !looks.isEmpty {
            guard looks.count <= 1000, looks.allSatisfy({ !$0.name.isEmpty && $0.name.count <= 200 && (1...100).contains($0.brightness) && (0...9000).contains($0.temperature) && ($0.heads?.allSatisfy { (0..<3).contains($0.id) && (1...100).contains($0.brightness) } ?? true) }) else { throw SceneError.invalidLibrary }
            var count = 0
            for var look in looks where !customPresets.contains(where: { $0.id == look.id }) { look.isBuiltIn = false; customPresets.append(look); count += 1 }
            persistPresets(); return "Imported \(count) saved looks."
        }
        let imported = try NativeScene.parseLibrary(data, model: model)
        guard !imported.isEmpty else { throw SceneError.invalidLibrary }
        let cache = ControlSocket.directory.appendingPathComponent("Scenes", isDirectory: true).appendingPathComponent("\(model).json")
        try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try data.write(to: cache, options: [.atomic]); scenes[model] = imported
        sceneStatus[model] = "\(imported.count) scenes imported"
        return sceneStatus[model]!
    }
    func applyScene(_ scene: NativeScene, to id: String) async -> Bool {
        await live.stop(restore: false)
        return await perform([.power(true), .scene(scene)], to: id)
    }
}
