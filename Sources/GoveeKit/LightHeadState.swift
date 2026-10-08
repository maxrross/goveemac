import Foundation

public struct LightHeadState: Identifiable, Codable, Equatable, Sendable {
    public let id: Int
    public var color: RGB
    public var brightness: Int
    public var isOn: Bool
    public var hasRequestedState: Bool

    public init(id: Int, color: RGB = RGB(255, 190, 120), brightness: Int = 100,
                isOn: Bool = true, hasRequestedState: Bool = false) {
        self.id = id
        self.color = color
        self.brightness = max(1, min(100, brightness))
        self.isOn = isOn
        self.hasRequestedState = hasRequestedState
    }

    /// A black segment darkens just this head; its chosen color is retained.
    public var wireColor: RGB {
        guard isOn else { return RGB(0, 0, 0) }
        let scale = Double(max(1, min(100, brightness))) / 100
        return RGB(UInt8((Double(color.red) * scale).rounded()),
                   UInt8((Double(color.green) * scale).rounded()),
                   UInt8((Double(color.blue) * scale).rounded()))
    }
}

public enum ProtocolEncodingError: LocalizedError {
    case unsupportedHead
    public var errorDescription: String? { "This model does not support that individual lamp head." }
}
