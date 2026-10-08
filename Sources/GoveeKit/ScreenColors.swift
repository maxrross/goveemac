import Foundation

public enum ScreenColors {
    /// Average BGRA pixels in physical head order: bottom/middle/top for rows,
    /// or left/center/right for columns. Padding at the end of each row is ignored.
    public static func sample(bgra: [UInt8], width: Int, height: Int, rowBytes: Int, mapping: String) -> [RGB]? {
        guard (1...4096).contains(width), (1...4096).contains(height),
              rowBytes >= width*4, rowBytes <= 65536, bgra.count >= rowBytes*height,
              ["rows","columns","whole"].contains(mapping) else { return nil }
        var sums = Array(repeating: [0,0,0,0], count: 3)
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let zone = mapping == "rows" ? 2-min(2, y*3/height) : min(2, x*3/width)
                let p = y*rowBytes+x*4
                let indices = mapping == "whole" ? [0,1,2] : [zone]
                for i in indices { sums[i][0] += Int(bgra[p+2]); sums[i][1] += Int(bgra[p+1]); sums[i][2] += Int(bgra[p]); sums[i][3] += 1 }
            }
        }
        return sums.map { s in RGB(UInt8(s[0]/max(1,s[3])), UInt8(s[1]/max(1,s[3])), UInt8(s[2]/max(1,s[3]))) }
    }
}
