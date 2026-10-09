import Foundation
import Darwin

public struct ControlRequest: Codable, Sendable {
    public var action: String
    public var device: String?
    public var value: String?
    public var head: String?
    public var brightness: Int?
    public var source: String?
    public var display: UInt32?
    public var speed: Double?
    public var sensitivity: Double?
    public var mapping: String?
    public var style: String?
    public var library: Data?
    public var restore: Bool?
    public init(action: String) { self.action = action }
}
public struct ControlLight: Codable, Sendable {
    public var id: String
    public var name: String
    public var model: String
    public var connection: ConnectionKind
    public var available: Bool
    public var state: LightState
    public var heads: [LightHeadState]
    public init(_ device: LightDevice) {
        id = device.id; name = device.name; model = device.model; connection = device.connection
        available = device.isAvailable; state = device.state; heads = device.heads
    }
}
public struct ControlScene: Codable, Sendable {
    public var id: String
    public var model: String
    public var name: String
    public var category: String
    public var code: Int
    public init(_ scene: NativeScene) { id = scene.id; model = scene.model; name = scene.name; category = scene.category; code = scene.code }
}
public struct ControlReply: Codable, Sendable {
    public var ok: Bool
    public var message: String?
    public var lights: [ControlLight]?
    public var scenes: [ControlScene]?
    public var presets: [LightPreset]?
    public var displays: [CaptureDisplay]?
    public var mode: String?
    public var levels: [Double]?
    public var preview: [RGB]?
    public var captureStatus: String?
    public var outputFPS: Double?
    public var beats: Int?
    public var overlay: String?
    public var outputBrightness: Int?
    public var nativeScene: String?
    public init(ok: Bool = true, message: String? = nil) { self.ok = ok; self.message = message }
}
public struct CaptureDisplay: Codable, Identifiable, Sendable {
    public var id: UInt32
    public var name: String
    public init(id: UInt32, name: String) { self.id = id; self.name = name }
}
public enum ControlError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let text) = self { text } else { nil } }
}

/// Local-only IPC. A private directory, filesystem permissions, and peer UID
/// checking restrict control to processes running as the current Mac user.
public enum ControlSocket {
    public static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GoveeMac", isDirectory: true)
    }
    public static var path: String { directory.appendingPathComponent("control.sock").path }
    public static func address(_ path: String) throws -> sockaddr_un {
        var address = sockaddr_un(); address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw ControlError.message("Control socket path is too long.") }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in buffer.copyBytes(from: bytes) }
        return address
    }
    public static func connect() throws -> Int32 {
        var info = stat()
        guard lstat(path, &info) == 0, info.st_uid == getuid(), (info.st_mode & S_IFMT) == S_IFSOCK else {
            throw ControlError.message("Govee Mac is not running. Open the app, connect a light, then retry.")
        }
        var address = try address(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ControlError.message("Could not open control socket.") }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard result == 0 else { close(fd); throw ControlError.message("Could not reach Govee Mac. Reopen the app.") }
        configure(fd); return fd
    }
    public static func configure(_ fd: Int32) {
        var noSignal: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
        var timeout = timeval(tv_sec: 30, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    }
    public static func readMessage(_ fd: Int32, limit: Int = 1_000_000) throws -> Data {
        var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while data.count < limit {
            let count = recv(fd, &buffer, buffer.count, 0)
            guard count > 0 else { throw ControlError.message("The app did not answer before the timeout.") }
            if let end = buffer[..<count].firstIndex(of: 10) { guard data.count+end <= limit else { throw ControlError.message("Control message exceeds the size limit.") }; data.append(contentsOf: buffer[..<end]); return data }
            data.append(contentsOf: buffer[..<count])
        }
        throw ControlError.message("Control message exceeds the size limit.")
    }
    public static func writeMessage(_ data: Data, to fd: Int32) throws {
        let framed = data + Data([10])
        try framed.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let n = Darwin.send(fd, buffer.baseAddress!.advanced(by: offset), buffer.count-offset, 0)
                guard n > 0 else { throw ControlError.message("Control socket closed while sending.") }; offset += n
            }
        }
    }
}
