import Foundation

public enum LANEvent: Equatable, Sendable {
    case discovery(id: String, model: String)
    case status(LightState)
}

public enum LANProtocol {
    public static let multicastAddress = "239.255.255.250"
    public static let discoveryPort: UInt16 = 4001
    public static let responsePort: UInt16 = 4002
    public static let controlPort: UInt16 = 4003

    public static func scan() throws -> Data {
        try encode("scan", data: ["account_topic": "reserve"])
    }

    public static func encode(_ command: LightCommand) throws -> Data {
        switch command {
        case .power(let value): try encode("turn", data: ["value": value ? 1 : 0])
        case .brightness(let value): try encode("brightness", data: ["value": max(1, min(100, value))])
        case .color(let rgb): try encode("colorwc", data: ["color": ["r": Int(rgb.red), "g": Int(rgb.green), "b": Int(rgb.blue)], "colorTemInKelvin": 0])
        case .temperature(let value): try encode("colorwc", data: ["color": ["r": 0, "g": 0, "b": 0], "colorTemInKelvin": max(2000, min(9000, value))])
        case .status: try encode("devStatus", data: [:])
        case .head: throw ProtocolEncodingError.unsupportedHead
        }
    }

    public static func encode(_ command: LightCommand, model: String) throws -> Data {
        if case .head = command {
            guard let packet = BLEProtocol.encode(command, model: model, encrypted: false) else {
                throw ProtocolEncodingError.unsupportedHead
            }
            return try encode("ptReal", data: ["command": [packet.base64EncodedString()]])
        }
        if model == "H60B2", case .color = command,
           let packet = BLEProtocol.encode(command, percentBrightness: true, extendedColor: true, segmentMask: 7) {
            // H60B2 LAN segment control: bits 0–2 select all three lamp heads.
            return try encode("ptReal", data: ["command": [packet.base64EncodedString()]])
        }
        return try encode(command)
    }

    private static func encode(_ command: String, data: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["msg": ["cmd": command, "data": data]], options: [.sortedKeys])
    }

    public static func decode(_ packet: Data) -> LANEvent? {
        guard packet.count <= 8192,
              let root = try? JSONSerialization.jsonObject(with: packet) as? [String: Any],
              let message = root["msg"] as? [String: Any],
              let command = message["cmd"] as? String,
              let data = message["data"] as? [String: Any] else { return nil }
        if command == "scan", let id = data["device"] as? String, !id.isEmpty,
           let model = data["sku"] as? String, !model.isEmpty {
            return .discovery(id: id, model: model)
        }
        if command == "devStatus", let on = data["onOff"] as? Int, (0...1).contains(on),
           let brightness = data["brightness"] as? Int, (1...100).contains(brightness),
           let color = data["color"] as? [String: Int],
           let r = color["r"], let g = color["g"], let b = color["b"],
           [r, g, b].allSatisfy({ (0...255).contains($0) }) {
            return .status(LightState(isOn: on == 1, brightness: brightness,
                                     color: RGB(UInt8(r), UInt8(g), UInt8(b)),
                                     temperature: data["colorTemInKelvin"] as? Int ?? 0))
        }
        return nil
    }
}
