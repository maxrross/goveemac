import Foundation

public struct LightPreset: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var symbol: String
    public var color: RGB
    public var brightness: Int
    public var temperature: Int
    public var isBuiltIn: Bool
    public var heads: [LightHeadState]?

    public init(id: String = UUID().uuidString, name: String, symbol: String = "bookmark.fill", color: RGB,
                brightness: Int, temperature: Int = 0, isBuiltIn: Bool = false, heads: [LightHeadState]? = nil) {
        self.id = id; self.name = name; self.symbol = symbol; self.color = color
        self.brightness = max(1, min(100, brightness))
        self.temperature = temperature; self.isBuiltIn = isBuiltIn
        self.heads = heads
    }

    public static let builtIns: [LightPreset] = [
        .init(id: "focus", name: "Focus", symbol: "sun.max", color: RGB(230, 242, 255), brightness: 90, temperature: 5500, isBuiltIn: true),
        .init(id: "unwind", name: "Unwind", symbol: "cup.and.saucer", color: RGB(255, 174, 90), brightness: 40, temperature: 2700, isBuiltIn: true),
        .init(id: "sunset", name: "Sunset", symbol: "sun.horizon", color: RGB(255, 92, 64), brightness: 65, isBuiltIn: true),
        .init(id: "ocean", name: "Ocean", symbol: "water.waves", color: RGB(36, 165, 255), brightness: 70, isBuiltIn: true),
        .init(id: "lavender", name: "Lavender", symbol: "moon.stars", color: RGB(174, 107, 255), brightness: 45, isBuiltIn: true),
        .init(id: "night", name: "Night light", symbol: "moon", color: RGB(255, 137, 40), brightness: 8, temperature: 2000, isBuiltIn: true)
    ]
}
