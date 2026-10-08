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

    public static func encode(_ command: LightCommand, percentBrightness: Bool = false, extendedColor: Bool = false) -> Data? {
        switch command {
        case .power(let value): packet(command: 0x01, payload: [value ? 1 : 0])
        case .brightness(let value): packet(command: 0x04, payload: [UInt8((Double(max(1, min(100, value))) / 100 * (percentBrightness ? 100 : 254)).rounded())])
        case .color(let rgb): packet(command: 0x05, payload: extendedColor ? [0x15, 0x01, rgb.red, rgb.green, rgb.blue, 0, 0, 0, 0, 0, 0xFF, 0x7F] : [0x02, rgb.red, rgb.green, rgb.blue])
        case .temperature, .status: nil
        }
    }

    public static func query(_ command: UInt8) -> Data { packet(head: 0xAA, command: command, payload: [])! }
    public static var keepAlive: Data { query(0x01) }
}
