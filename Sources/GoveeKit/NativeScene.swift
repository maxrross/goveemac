import Foundation

public struct NativeScene: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var model: String
    public var name: String
    public var category: String
    public var code: Int
    public var parameter: Data
    public var iconURLs: [URL]?
    public init(model: String, name: String, category: String, code: Int, parameter: Data, iconURLs: [URL]? = nil) {
        self.id = "\(model):\(code)"; self.model = model; self.name = name
        self.category = category; self.code = code; self.parameter = parameter; self.iconURLs = iconURLs
    }
    /// Fragmented scene upload followed by the little-endian scene selection.
    /// Protocol described by wez/govee2mqtt's SetSceneCode (MIT).
    public var packets: [Data]? {
        guard (1...65535).contains(code), parameter.count <= 2048 else { return nil }
        let selection = BLEProtocol.packet(command: 5, payload: [4, UInt8(code & 255), UInt8(code >> 8)])!
        // Firmware-resident scenes need only the selection, with no upload.
        if parameter.isEmpty { return [selection] }
        var raw: [UInt8] = [0xA3, 0, 1, 0, 2]
        var lines = 0
        var lastMarker = 1
        for byte in parameter {
            if raw.count % 19 == 0 {
                lines += 1; raw.append(0xA3); lastMarker = raw.count; raw.append(UInt8(lines))
            }
            raw.append(byte)
        }
        raw[lastMarker] = 0xFF; raw[3] = UInt8(lines + 1)
        var result: [Data] = []
        for offset in stride(from: 0, to: raw.count, by: 19) {
            var frame = Array(raw[offset..<min(offset + 19, raw.count)])
            frame += Array(repeating: 0, count: 19 - frame.count)
            result.append(Data(frame + [frame.reduce(0, ^)]))
        }
        result.append(selection)
        return result
    }
    public static func parseLibrary(_ data: Data, model: String) throws -> [NativeScene] {
        guard data.count <= 8_000_000, model.range(of: "^H[0-9A-F]{4}$", options: .regularExpression) != nil else { throw SceneError.invalidLibrary }
        let root = try JSONSerialization.jsonObject(with: data)
        if let flat = root as? [[String: Any]] {
            return flat.compactMap { entry in
                guard let name = entry["scene_name"] as? String, let code = entry["scene_code"] as? Int,
                      let p = entry["scence_param"] as? String, let bytes = Data(base64Encoded: p) else { return nil }
                let scene = NativeScene(model: model, name: name, category: entry["category"] as? String ?? "Imported", code: code, parameter: bytes)
                return scene.packets == nil ? nil : scene
            }
        }
        guard let object = root as? [String: Any], let body = object["data"] as? [String: Any],
              let categories = body["categories"] as? [[String: Any]] else { throw SceneError.invalidLibrary }
        var scenes: [NativeScene] = []
        for category in categories {
            for scene in category["scenes"] as? [[String: Any]] ?? [] {
                guard let name = scene["sceneName"] as? String else { continue }
                for effect in scene["lightEffects"] as? [[String: Any]] ?? [] {
                    guard let code = effect["sceneCode"] as? Int else { continue }
                    var param = effect["scenceParam"] as? String ?? ""
                    for special in effect["specialEffect"] as? [[String: Any]] ?? [] {
                        if (special["supportSku"] as? [String] ?? []).contains(model) {
                            param = special["scenceParam"] as? String ?? param; break
                        }
                    }
                    guard let bytes = Data(base64Encoded: param) else { continue }
                    let icons = (scene["iconUrls"] as? [String] ?? []).prefix(3).compactMap { value -> URL? in
                        guard let url = URL(string: value), url.scheme?.lowercased() == "https", url.host != nil,
                              url.user == nil, url.password == nil else { return nil }
                        return url
                    }
                    let item = NativeScene(model: model, name: name, category: category["categoryName"] as? String ?? "Scenes", code: code, parameter: bytes,
                                           iconURLs: icons.isEmpty ? nil : icons)
                    if item.packets != nil, !scenes.contains(where: { $0.id == item.id }) { scenes.append(item) }
                }
            }
        }
        return scenes
    }
}
public enum SceneError: LocalizedError {
    case invalidLibrary, wrongModel
    public var errorDescription: String? {
        switch self {
        case .invalidLibrary: "This file is not a supported Govee scene library."
        case .wrongModel: "This scene belongs to a different Govee model."
        }
    }
}
