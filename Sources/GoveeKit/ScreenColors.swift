import Foundation

public enum ScreenColors {
    /// Average BGRA pixels in physical head order: bottom/middle/top for rows,
    /// or left/center/right for columns. Padding at the end of each row is ignored.
    public static func sample(bgra: [UInt8], width: Int, height: Int, rowBytes: Int, mapping: String, style: String = "average") -> [RGB]? {
        guard (1...4096).contains(width), (1...4096).contains(height),
              rowBytes >= width*4, rowBytes <= 65536, bgra.count >= rowBytes*height,
              ["rows","columns","whole"].contains(mapping), ["average", "vivid"].contains(style) else { return nil }
        var sums = Array(repeating: [0,0,0,0], count: 3)
        var hues = Array(repeating: Array(repeating: [0.0, 0.0, 0.0, 0.0], count: 12), count: 3)
        var colored = [0, 0, 0]
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let zone = mapping == "rows" ? 2-min(2, y*3/height) : min(2, x*3/width)
                let p = y*rowBytes+x*4
                guard bgra[p+3] > 0 else { continue }
                let indices = mapping == "whole" ? [0,1,2] : [zone]
                for i in indices { sums[i][0] += Int(bgra[p+2]); sums[i][1] += Int(bgra[p+1]); sums[i][2] += Int(bgra[p]); sums[i][3] += 1 }
                if style == "vivid" {
                    let r = Double(bgra[p+2]), g = Double(bgra[p+1]), b = Double(bgra[p])
                    let top = max(r, g, b), delta = top - min(r, g, b)
                    guard top >= 25, delta / top >= 0.20 else { continue }
                    var hue = top == r ? (g - b) / delta : (top == g ? (b - r) / delta + 2 : (r - g) / delta + 4)
                    hue = (hue / 6 + 1).truncatingRemainder(dividingBy: 1)
                    let bin = min(11, Int(hue * 12)), weight = delta * top / 65025
                    for i in indices {
                        hues[i][bin][0] += r * weight; hues[i][bin][1] += g * weight
                        hues[i][bin][2] += b * weight; hues[i][bin][3] += weight; colored[i] += 1
                    }
                }
            }
        }
        return (0..<3).map { i in
            let s = sums[i]
            if style == "vivid", colored[i] > max(1, s[3] / 200),
               let dominant = hues[i].max(by: { $0[3] < $1[3] }), dominant[3] > 0 {
                let values = dominant.prefix(3).map { $0 / dominant[3] }
                let gain = max(1, 180 / max(1, values.max() ?? 1))
                return RGB(UInt8(min(255, values[0] * gain).rounded()), UInt8(min(255, values[1] * gain).rounded()), UInt8(min(255, values[2] * gain).rounded()))
            }
            return RGB(UInt8(s[0]/max(1,s[3])), UInt8(s[1]/max(1,s[3])), UInt8(s[2]/max(1,s[3])))
        }
    }
}
