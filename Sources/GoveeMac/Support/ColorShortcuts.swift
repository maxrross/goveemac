import GoveeKit

/// Lighting colors shared by the whole-lamp and individual-head controls.
/// Use saturated RGB values instead of pastel UI accent colors.
struct ColorShortcut: Identifiable {
    let name: String
    let color: RGB
    var id: String { name }
    var title: String { "\(name) (\(color.hex))" }

    static let all: [ColorShortcut] = [
        .init(name: "Red", color: RGB(255, 0, 0)),
        .init(name: "Orange", color: RGB(255, 128, 0)),
        .init(name: "Yellow", color: RGB(255, 255, 0)),
        .init(name: "Green", color: RGB(0, 255, 0)),
        .init(name: "Cyan", color: RGB(0, 255, 255)),
        .init(name: "Blue", color: RGB(0, 0, 255)),
        .init(name: "Purple", color: RGB(128, 0, 255)),
        .init(name: "Pink", color: RGB(255, 0, 128))
    ]
}
