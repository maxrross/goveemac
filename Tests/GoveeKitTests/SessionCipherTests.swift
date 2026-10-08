// Golden captures documented by mpalczew/govee-ble-segments; see notices.
import Foundation
import Testing
@testable import GoveeKit

struct SessionCipherTests {
    @Test func decryptsCapturedAuthenticationAndCommands() throws {
        let authentication = try BLESessionCipher(key: BLESessionCipher.authenticationKey)
        let reply = try authentication.decrypt(hex("9e6122db157166686c5d658a2de1cdfbc9202c8e"))
        #expect(reply.prefix(2) == Data([0xE7, 0x01]))
        #expect(reply.reduce(0, ^) == 0)
        let session = try BLESessionCipher(key: Data(reply[2..<18]))
        let off = try session.decrypt(hex("3ced005c862462cb58c0fa5753826089c5128c78"))
        #expect(off == BLEProtocol.encode(.power(false)))
        let red = try session.decrypt(hex("9eea057b3a50524ada34503afca43690c5128c8e"))
        #expect(red.prefix(6) == Data([0x33, 0x05, 0x0D, 255, 0, 0]))
        #expect(red.reduce(0, ^) == 0)
        #expect(try session.encrypt(off) == hex("3ced005c862462cb58c0fa5753826089c5128c78"))
    }

    @Test func rejectsInvalidLengths() throws {
        #expect(throws: BLECipherError.self) { try BLESessionCipher(key: Data(repeating: 0, count: 15)) }
        let cipher = try BLESessionCipher(key: BLESessionCipher.authenticationKey)
        #expect(throws: BLECipherError.self) { try cipher.encrypt(Data(repeating: 0, count: 19)) }
    }

    @Test func percentBrightnessNeverExceedsOneHundred() {
        #expect(BLEProtocol.encode(.brightness(100), percentBrightness: true)?[2] == 100)
        #expect(BLEProtocol.encode(.brightness(70), percentBrightness: true)?[2] == 70)
        #expect(BLEProtocol.encode(.brightness(1000), percentBrightness: true)?[2] == 100)
        let color = BLEProtocol.encode(.color(RGB(10, 20, 30)), extendedColor: true)!
        #expect(color.prefix(7) == Data([0x33, 0x05, 0x15, 0x01, 10, 20, 30]))
        #expect(color.count == 20 && color.reduce(0, ^) == 0)
    }

    private func hex(_ value: String) -> Data {
        let characters = Array(value)
        return Data(stride(from: 0, to: characters.count, by: 2).map {
            UInt8(String(characters[$0...($0 + 1)]), radix: 16)!
        })
    }
}
