import Foundation

public struct RGB: Codable, Equatable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.red = red; self.green = green; self.blue = blue
    }

    public var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }
}

public enum ConnectionKind: String, Codable, Sendable {
    case lan, bluetooth, demo
    public var title: String {
        switch self {
        case .lan: "Local Wi-Fi"
        case .bluetooth: "Bluetooth"
        case .demo: "Demo"
        }
    }
    public var symbol: String {
        switch self {
        case .lan: "wifi"
        case .bluetooth: "antenna.radiowaves.left.and.right"
        case .demo: "sparkles"
        }
    }
}

public struct LightState: Codable, Equatable, Sendable {
    public var isOn: Bool
    public var brightness: Int
    public var color: RGB
    public var temperature: Int
    public init(isOn: Bool = false, brightness: Int = 100, color: RGB = RGB(255, 190, 120), temperature: Int = 0) {
        self.isOn = isOn
        self.brightness = max(1, min(100, brightness))
        self.color = color
        self.temperature = max(0, min(9000, temperature))
    }
}

public struct LightDevice: Identifiable, Sendable {
    public let id: String
    public var name: String
    public var model: String
    public let connection: ConnectionKind
    public var address: String
    public var state = LightState()
    public var isAvailable = false
    public var isConnecting = false
    public var hasKnownState = false
    public var usesEncryptedBLE = false
    public var lastSeen: Date?
    public var lastSent: Date?

    public init(id: String, name: String, model: String, connection: ConnectionKind, address: String = "") {
        self.id = id; self.name = name; self.model = model
        self.connection = connection; self.address = address
    }

    public var supportsTemperature: Bool { connection != .bluetooth }
    public var status: String {
        if isConnecting { return "Connecting…" }
        if !isAvailable { return connection == .bluetooth ? "Not connected" : "Waiting for light" }
        if !hasKnownState { return "Ready · power unknown" }
        return state.isOn ? "On" : "Off"
    }
}

public enum LightCommand: Equatable, Sendable {
    case power(Bool), brightness(Int), color(RGB), temperature(Int), status

    public var key: String {
        switch self {
        case .power: "power"
        case .brightness: "brightness"
        case .color, .temperature: "color"
        case .status: "status"
        }
    }

    public func applying(to state: LightState) -> LightState {
        var result = state
        switch self {
        case .power(let on): result.isOn = on
        case .brightness(let value): result.brightness = max(1, min(100, value))
        case .color(let rgb): result.color = rgb; result.temperature = 0
        case .temperature(let kelvin): result.temperature = max(2000, min(9000, kelvin))
        case .status: break
        }
        return result
    }
}
