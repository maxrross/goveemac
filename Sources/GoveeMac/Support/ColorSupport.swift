import AppKit
import SwiftUI
import GoveeKit

extension RGB {
    var swiftUIColor: Color { Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255) }
    init(color: Color) {
        let converted = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(UInt8((max(0, min(1, converted.redComponent)) * 255).rounded()),
                  UInt8((max(0, min(1, converted.greenComponent)) * 255).rounded()),
                  UInt8((max(0, min(1, converted.blueComponent)) * 255).rounded()))
    }
}

enum Brand {
    static let accent = Color(red: 0.08, green: 0.64, blue: 0.57)
    static let repository = URL(string: "https://github.com/maxrross/goveemac")!
}
