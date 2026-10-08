// Packages the approved ImageGen artwork as a macOS icon without redrawing it.
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let source = root.appendingPathComponent("docs/icon.png")
let folder = root.appendingPathComponent("work/GoveeMac.iconset")
guard FileManager.default.fileExists(atPath: source.path) else {
    fatalError("Missing approved icon artwork: \(source.path)")
}
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "GoveeMac.Icon", code: Int(process.terminationStatus),
                      userInfo: [NSLocalizedDescriptionKey: "\(executable) failed"])
    }
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = String(size * scale)
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try run("/usr/bin/sips", ["-z", pixels, pixels, source.path,
                                 "--out", folder.appendingPathComponent(name).path])
    }
}
try run("/usr/bin/iconutil", ["-c", "icns", folder.path, "-o",
                              root.appendingPathComponent("Resources/GoveeMac.icns").path])
print("Packaged the approved lamp icon.")
