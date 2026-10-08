import Foundation

public enum DeviceCatalog {
    public static func headCount(model: String) -> Int { model == "H60B2" ? 3 : 0 }

    public static func headName(model: String, index: Int) -> String {
        guard model == "H60B2", (0..<3).contains(index) else { return "Head \(index + 1)" }
        return ["Bottom", "Middle", "Top"][index]
    }

    public static func friendlyName(model: String) -> String? {
        switch model {
        case "H60B2": "Tree floor lamp"
        case "H6098": "TV backlight 3S"
        case "H6099": "TV backlight T3 Lite"
        case "H6072": "Lyra floor lamp"
        case "H607C": "Floor lamp 2"
        case "H6079": "Floor lamp pro"
        default: nil
        }
    }

    /// These RGBIC models answer AA05 with a mode and zero-filled payload, not RGB.
    public static func hasModeOnlyColorReply(model: String) -> Bool {
        ["H60B2", "H6098", "H6099"].contains(model)
    }
}
