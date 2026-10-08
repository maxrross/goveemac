import Foundation
import Darwin
import GoveeKit

final class ControlServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "community.goveemac.control", qos: .utility)
    private var descriptor: Int32 = -1
    private var lockFile: Int32 = -1
    func start(handler: @escaping @MainActor @Sendable (ControlRequest) async -> ControlReply) throws {
        let folder = ControlSocket.directory
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var info = stat()
        guard lstat(folder.path, &info) == 0, info.st_uid == getuid(), (info.st_mode & S_IFMT) == S_IFDIR else { throw ControlError.message("Invalid control directory.") }
        chmod(folder.path, 0o700)
        let lock = Darwin.open(folder.appendingPathComponent("control.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard lock >= 0 else { throw ControlError.message("Cannot open control lock.") }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { close(lock); throw ControlError.message("Another Govee Mac instance owns CLI control.") }
        lockFile = lock
        if lstat(ControlSocket.path, &info) == 0 {
            guard info.st_uid == getuid(), (info.st_mode & S_IFMT) == S_IFSOCK else { throw ControlError.message("Invalid control socket.") }
            unlink(ControlSocket.path)
        }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ControlError.message("Cannot create control socket.") }
        descriptor = fd
        var address = try ControlSocket.address(ControlSocket.path)
        let result = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
        guard result == 0 else { throw ControlError.message("Cannot bind control socket.") }
        chmod(ControlSocket.path, 0o600)
        guard listen(fd, 8) == 0 else { throw ControlError.message("Cannot listen for CLI requests.") }
        let slots = DispatchSemaphore(value: 4)
        queue.async {
            while true {
                let client = accept(fd, nil, nil)
                guard client >= 0 else { return }
                var uid: uid_t = 0, gid: gid_t = 0
                guard getpeereid(client, &uid, &gid) == 0, uid == getuid(), slots.wait(timeout: .now()) == .success else { close(client); continue }
                DispatchQueue.global(qos: .utility).async {
                    defer { close(client); slots.signal() }
                    ControlSocket.configure(client)
                    do {
                        let data = try ControlSocket.readMessage(client, limit: 12_000_000)
                        let request = try JSONDecoder().decode(ControlRequest.self, from: data)
                        guard data.count <= 65536 || (request.action == "import" && (request.library?.count ?? Int.max) <= 8_000_000) else { throw ControlError.message("Request is too large.") }
                        let semaphore = DispatchSemaphore(value: 0)
                        let result = ControlResult()
                        Task { @MainActor in
                            let reply = await handler(request)
                            result.set(try? JSONEncoder().encode(reply))
                            semaphore.signal()
                        }
                        semaphore.wait()
                        if let data = result.get() { try ControlSocket.writeMessage(data, to: client) }
                    } catch {
                        if let data = try? JSONEncoder().encode(ControlReply(ok: false, message: error.localizedDescription)) { try? ControlSocket.writeMessage(data, to: client) }
                    }
                }
            }
        }
    }
}

private final class ControlResult: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    func set(_ value: Data?) { lock.withLock { data = value } }
    func get() -> Data? { lock.withLock { data } }
}
