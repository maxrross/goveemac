import Darwin
import Foundation
import GoveeKit

enum ConnectionError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}

/// All socket state is confined to `queue`. Callbacks carry only Sendable values.
final class LANService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "community.goveemac.lan", qos: .utility)
    private var descriptor: Int32 = -1
    private var source: DispatchSourceRead?
    private var handler: (@Sendable (LANEvent, String) -> Void)?

    func start(handler: @escaping @Sendable (LANEvent, String) -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                self.handler = handler
                if descriptor >= 0 { continuation.resume(); return }
                do { try openSocket(); continuation.resume() }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    func scan() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    guard descriptor >= 0 else { throw ConnectionError.message("Local Wi-Fi is not ready. Try discovering lights again.") }
                    let data = try LANProtocol.scan()
                    let interfaces = Self.interfaces()
                    if interfaces.isEmpty {
                        try send(data, to: LANProtocol.multicastAddress, port: LANProtocol.discoveryPort)
                    } else {
                        var sent = false
                        var lastError: Error?
                        for var address in interfaces {
                            setsockopt(descriptor, IPPROTO_IP, IP_MULTICAST_IF, &address, socklen_t(MemoryLayout<in_addr>.size))
                            do { try send(data, to: LANProtocol.multicastAddress, port: LANProtocol.discoveryPort); sent = true }
                            catch { lastError = error }
                        }
                        if !sent { throw lastError ?? ConnectionError.message("No network interface could send discovery.") }
                    }
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func send(_ command: LightCommand, to address: String) async throws {
        let data = try LANProtocol.encode(command)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    try send(data, to: address, port: LANProtocol.controlPort)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    private func openSocket() throws {
        let fd = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw systemError("Could not open a local network socket") }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = LANProtocol.responsePort.bigEndian
        address.sin_addr.s_addr = INADDR_ANY
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            let message = errno == EADDRINUSE
                ? "UDP port 4002 is in use. Quit other Govee LAN controllers and try again."
                : "Could not listen on UDP port 4002: \(String(cString: strerror(errno))). Check Local Network permission in System Settings."
            Darwin.close(fd)
            throw ConnectionError.message(message)
        }
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        descriptor = fd
        let interfaces = Self.interfaces()
        for address in interfaces.isEmpty ? [in_addr(s_addr: INADDR_ANY)] : interfaces {
            var membership = ip_mreq(imr_multiaddr: in_addr(s_addr: inet_addr(LANProtocol.multicastAddress)), imr_interface: address)
            setsockopt(fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &membership, socklen_t(MemoryLayout<ip_mreq>.size))
        }
        let readSource = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        readSource.setEventHandler { [weak self] in self?.receive() }
        readSource.setCancelHandler { Darwin.close(fd) }
        source = readSource
        readSource.resume()
    }

    private func send(_ data: Data, to host: String, port: UInt16) throws {
        guard descriptor >= 0 else { throw ConnectionError.message("Local network connection is unavailable.") }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
            throw ConnectionError.message("Enter a valid IPv4 address, such as 192.168.1.50.")
        }
        let count = data.withUnsafeBytes { buffer in
            withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(descriptor, buffer.baseAddress, buffer.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard count == data.count else { throw systemError("Could not send to the light") }
    }

    private func receive() {
        while descriptor >= 0 {
            var bytes = [UInt8](repeating: 0, count: 8193)
            var address = sockaddr_in()
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(descriptor, &bytes, bytes.count, 0, $0, &length)
                }
            }
            guard count > 0 else { return }
            guard let event = LANProtocol.decode(Data(bytes.prefix(count))) else { continue }
            var host = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &address.sin_addr, &host, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }
            handler?(event, String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self))
        }
    }

    private func systemError(_ prefix: String) -> ConnectionError {
        .message("\(prefix): \(String(cString: strerror(errno))).")
    }

    private static func interfaces() -> [in_addr] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0 else { return [] }
        defer { freeifaddrs(pointer) }
        var result: [in_addr] = []
        var cursor = pointer
        while let item = cursor {
            let interface = item.pointee
            if let address = interface.ifa_addr,
               address.pointee.sa_family == sa_family_t(AF_INET),
               interface.ifa_flags & UInt32(IFF_UP) != 0,
               interface.ifa_flags & UInt32(IFF_MULTICAST) != 0,
               interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0 {
                result.append(UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr)
            }
            cursor = interface.ifa_next
        }
        return result
    }

    deinit { source?.cancel() }
}
