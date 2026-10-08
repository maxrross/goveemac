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

    @Test func treeLampColorAddressesAllThreeHeads() {
        let color = BLEProtocol.encode(.color(RGB(36, 165, 255)), extendedColor: true, segmentMask: 7)!
        #expect(color.prefix(7) == Data([0x33, 0x05, 0x15, 0x01, 36, 165, 255]))
        #expect(color[12] == 7 && color[13] == 0)
        #expect(color.count == 20 && color.reduce(0, ^) == 0)
        #expect(DeviceCatalog.friendlyName(model: "H60B2") == "Tree floor lamp")
        #expect(DeviceCatalog.hasModeOnlyColorReply(model: "H60B2"))
    }

    @Test func treeLampLeavesSceneModeBeforeSettingHeads() {
        let packets = BLEProtocol.commandSequence(.color(RGB(36, 165, 255)), model: "H60B2", encrypted: true)!
        #expect(packets.count == 2)
        #expect(packets[0].prefix(6) == Data([0x33, 0x05, 0x02, 36, 165, 255]))
        #expect(packets[1].prefix(7) == Data([0x33, 0x05, 0x15, 1, 36, 165, 255]))
        #expect(packets[1][12] == 7 && packets[1][13] == 0)
        #expect(packets.allSatisfy { $0.count == 20 && $0.reduce(0, ^) == 0 })
        #expect(BLEProtocol.encode(.brightness(100), model: "H60B2", encrypted: false)?[2] == 100)
    }

    @Test func treeLampLANColorUsesBinaryCommand() throws {
        let data = try LANProtocol.encode(.color(RGB(36, 165, 255)), model: "H60B2")
        let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let message = root["msg"] as! [String: Any]
        #expect(message["cmd"] as? String == "ptReal")
        let payload = message["data"] as! [String: Any]
        let packets = payload["command"] as! [String]
        #expect(packets.count == 1)
        let frame = Data(base64Encoded: packets[0])!
        #expect(frame == Data([0x33, 5, 0x15, 1, 36, 165, 255, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 91]))
    }

    @Test func customHexColorsRejectMalformedInput() {
        #expect(RGB(hex: "#24a5FF") == RGB(36, 165, 255))
        #expect(RGB(hex: " FF0000 ") == RGB(255, 0, 0))
        for value in ["#FFF", "-12345", "#FF00GG", "ＦＦ0000", "#FFFFFFFF", ""] {
            #expect(RGB(hex: value) == nil)
        }
    }

    private func hex(_ value: String) -> Data {
        let characters = Array(value)
        return Data(stride(from: 0, to: characters.count, by: 2).map {
            UInt8(String(characters[$0...($0 + 1)]), radix: 16)!
        })
    }
}
