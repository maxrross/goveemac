// Session protocol informed by mpalczew/govee-ble-segments (MIT).
// See THIRD_PARTY_NOTICES.md. Implemented with Apple's CommonCrypto.
import CommonCrypto
import Foundation

public enum BLECipherError: Error { case invalidLength, cryptoFailure }

public struct BLESessionCipher: Sendable {
    public static let authenticationKey = Data("MakingLifeSmarte".utf8)
    private let key: Data

    public init(key: Data) throws {
        guard key.count == 16 else { throw BLECipherError.invalidLength }
        self.key = key
    }

    public func encrypt(_ packet: Data) throws -> Data { try transform(packet, decrypt: false) }
    public func decrypt(_ packet: Data) throws -> Data { try transform(packet, decrypt: true) }

    private func transform(_ packet: Data, decrypt: Bool) throws -> Data {
        guard packet.count == 20 else { throw BLECipherError.invalidLength }
        var output = [UInt8](repeating: 0, count: 16)
        var moved = 0
        let status = key.withUnsafeBytes { keyBytes in
            packet.withUnsafeBytes { input in
                CCCrypt(CCOperation(decrypt ? kCCDecrypt : kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode), keyBytes.baseAddress, 16, nil,
                        input.baseAddress, 16, &output, 16, &moved)
            }
        }
        guard status == kCCSuccess, moved == 16 else { throw BLECipherError.cryptoFailure }
        return Data(output) + streamTransform(Data(packet.suffix(4)))
    }

    // Govee's legacy transport uses RC4 for its final four bytes, freshly initialized per packet.
    private func streamTransform(_ input: Data) -> Data {
        let bytes = [UInt8](key)
        var permutation = Array(0..<256)
        var j = 0
        for i in 0..<256 {
            j = (j + permutation[i] + Int(bytes[i % 16])) & 255
            permutation.swapAt(i, j)
        }
        var i = 0
        j = 0
        return Data(input.map { byte in
            i = (i + 1) & 255
            j = (j + permutation[i]) & 255
            permutation.swapAt(i, j)
            return byte ^ UInt8(permutation[(permutation[i] + permutation[j]) & 255])
        })
    }
}
