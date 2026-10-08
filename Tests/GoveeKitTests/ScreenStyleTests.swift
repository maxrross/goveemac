import Testing
@testable import GoveeKit

struct ScreenStyleTests {
    @Test func vividFindsAccentColorsWithoutDarkLetterboxDilution() throws {
        let width = 20, height = 20
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<width * height { bytes[i * 4 + 3] = 255 }
        for y in 8..<12 {
            for x in 8..<12 { bytes[(y * width + x) * 4 + 2] = 100 }
        }
        let average = try #require(ScreenColors.sample(bgra: bytes, width: width, height: height, rowBytes: width * 4, mapping: "whole"))
        let vivid = try #require(ScreenColors.sample(bgra: bytes, width: width, height: height, rowBytes: width * 4, mapping: "whole", style: "vivid"))
        #expect(average[0].red < 10)
        #expect(vivid == Array(repeating: RGB(180, 0, 0), count: 3))
    }
    @Test func blackAndNeutralScreensStayAccurateInBothStyles() {
        for value: UInt8 in [0, 90, 255] {
            let bytes = Array(repeating: [value, value, value, UInt8(255)], count: 36).flatMap { $0 }
            for style in ["average", "vivid"] {
                #expect(ScreenColors.sample(bgra: bytes, width: 6, height: 6, rowBytes: 24, mapping: "rows", style: style)
                        == Array(repeating: RGB(value, value, value), count: 3))
            }
        }
    }
    @Test func transparentPaddingDoesNotDarkenTheSample() {
        var bytes = [UInt8](repeating: 0, count: 6 * 6 * 4)
        for y in 0..<6 {
            let offset = y * 24
            bytes[offset] = 255; bytes[offset + 3] = 255
        }
        #expect(ScreenColors.sample(bgra: bytes, width: 6, height: 6, rowBytes: 24, mapping: "rows")
                == Array(repeating: RGB(0, 0, 255), count: 3))
    }
}
