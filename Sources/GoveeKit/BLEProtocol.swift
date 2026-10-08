// Packet framing and commands adapted from Govee-Sync by Adil Rahmani.
// Copyright (c) 2025 Adil Rahmani. MIT license; see THIRD_PARTY_NOTICES.md.
import Foundation

public enum BLEProtocol {
    public static let controlCharacteristic = "00010203-0405-0607-0809-0a0b0c0d2b11"
    public static let notifyCharacteristic = "00010203-0405-0607-0809-0a0b0c0d2b10"

    public static func packet(head: UInt8 = 0x33, command: UInt8, payload: [UInt8]) -> Data? {
        guard payload.count <= 17 else { return nil }
        var frame: [UInt8] = [head, command] + payload
        frame.append(contentsOf: repeatElement(0, count: 19 - frame.count))
        return Data(frame + [frame.reduce(0, ^)])
    }

    public static func encode(_ command: LightCommand, percentBrightness: Bool = false, extendedColor: Bool = false, segmentMask: UInt16 = 0x7FFF) -> Data? {
        switch command {
        case .power(let value): packet(command: 0x01, payload: [value ? 1 : 0])
        case .brightness(let value): packet(command: 0x04, payload: [UInt8((Double(max(1, min(100, value))) / 100 * (percentBrightness ? 100 : 254)).rounded())])
        case .color(let rgb): packet(command: 0x05, payload: extendedColor ? [0x15, 0x01, rgb.red, rgb.green, rgb.blue, 0, 0, 0, 0, 0, UInt8(segmentMask & 255), UInt8(segmentMask >> 8)] : [0x02, rgb.red, rgb.green, rgb.blue])
        case .temperature, .status, .head: nil
        }
    }

    public static func query(_ command: UInt8) -> Data { packet(head: 0xAA, command: command, payload: [])! }
    public static var keepAlive: Data { query(0x01) }

    public static func encode(_ command: LightCommand, model: String, encrypted: Bool) -> Data? {
        if case .head(let head) = command {
            guard model == "H60B2", (0..<3).contains(head.id) else { return nil }
            return encode(.color(head.wireColor), percentBrightness: true, extendedColor: true,
                          segmentMask: UInt16(1) << head.id)
        }
        let percent = encrypted || ["H60B2", "H6098", "H6099"].contains(model)
        return encode(command, percentBrightness: percent,
                      extendedColor: ["H60B2", "H6098", "H6099"].contains(model),
                      segmentMask: model == "H60B2" ? 0x0007 : 0x7FFF)
    }

    public static func commandSequence(_ command: LightCommand, model: String, encrypted: Bool) -> [Data]? {
        guard let commandPacket = encode(command, model: model, encrypted: encrypted) else { return nil }
        // Leave scene mode before addressing the Tree lamp's three RGBIC heads.
        if model == "H60B2", case .color = command,
           let manualColor = encode(command, percentBrightness: true) {
            return [manualColor, commandPacket]
        }
        return [commandPacket]
    }
}
