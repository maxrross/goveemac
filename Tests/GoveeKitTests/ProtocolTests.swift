import Foundation
import Testing
@testable import GoveeKit

struct ProtocolTests {
    @Test func bluetoothPowerGoldenFrames() {
        #expect(BLEProtocol.encode(.power(true)) == Data([0x33, 0x01, 0x01] + Array(repeating: 0, count: 16) + [0x33]))
        #expect(BLEProtocol.encode(.power(false)) == Data([0x33, 0x01, 0x00] + Array(repeating: 0, count: 16) + [0x32]))
    }

    @Test func bluetoothRGBGoldenFrame() {
        let expected = Data([0x33, 0x05, 0x02, 0xFF, 0x00, 0x80] + Array(repeating: 0, count: 13) + [0x4B])
        #expect(BLEProtocol.encode(.color(RGB(255, 0, 128))) == expected)
    }

    @Test(arguments: [-500, 0, 1, 50, 100, 500])
    func bluetoothBrightnessIsSafe(value: Int) {
        let data = BLEProtocol.encode(.brightness(value))!
        #expect(data.count == 20)
        #expect(data[2] >= 3 && data[2] <= 254)
        #expect(data.reduce(0, ^) == 0)
        if value == 50 { #expect(data[2] == 127) }
        if value >= 100 { #expect(data[2] == 254) }
    }

    @Test func bluetoothDoesNotInventUnsupportedCommands() {
        #expect(BLEProtocol.encode(.temperature(4000)) == nil)
        #expect(BLEProtocol.encode(.status) == nil)
        #expect(BLEProtocol.packet(command: 1, payload: Array(repeating: 0, count: 18)) == nil)
        #expect(BLEProtocol.keepAlive.count == 20)
        #expect(BLEProtocol.keepAlive.prefix(3) == Data([0xAA, 1, 0]))
        #expect(BLEProtocol.keepAlive.reduce(0, ^) == 0)
    }

    @Test func localDiscoveryMessage() throws {
        #expect(String(decoding: try LANProtocol.scan(), as: UTF8.self) == #"{"msg":{"cmd":"scan","data":{"account_topic":"reserve"}}}"#)
    }

    @Test func localPowerAndColorMessages() throws {
        #expect(String(decoding: try LANProtocol.encode(.power(false)), as: UTF8.self) == #"{"msg":{"cmd":"turn","data":{"value":0}}}"#)
        #expect(String(decoding: try LANProtocol.encode(.color(RGB(255, 0, 128))), as: UTF8.self) == #"{"msg":{"cmd":"colorwc","data":{"color":{"b":128,"g":0,"r":255},"colorTemInKelvin":0}}}"#)
        #expect(String(decoding: try LANProtocol.encode(.status), as: UTF8.self) == #"{"msg":{"cmd":"devStatus","data":{}}}"#)
    }

    @Test func localValuesClampToDocumentedRanges() throws {
        #expect(String(decoding: try LANProtocol.encode(.brightness(-10)), as: UTF8.self).contains(#""value":1"#))
        #expect(String(decoding: try LANProtocol.encode(.brightness(500)), as: UTF8.self).contains(#""value":100"#))
        #expect(String(decoding: try LANProtocol.encode(.temperature(1000)), as: UTF8.self).contains(#""colorTemInKelvin":2000"#))
        #expect(String(decoding: try LANProtocol.encode(.temperature(12000)), as: UTF8.self).contains(#""colorTemInKelvin":9000"#))
    }

    @Test func parsesDiscoveryWithoutTrustingAdvertisedIP() {
        let packet = Data(#"{"msg":{"cmd":"scan","data":{"device":"AA:BB","sku":"H6195","ip":"203.0.113.1"}}}"#.utf8)
        #expect(LANProtocol.decode(packet) == .discovery(id: "AA:BB", model: "H6195"))
    }

    @Test func parsesRealStatusShape() {
        let packet = Data(#"{"msg":{"cmd":"devStatus","data":{"onOff":1,"brightness":62,"color":{"r":12,"g":100,"b":250},"colorTemInKelvin":0}}}"#.utf8)
        #expect(LANProtocol.decode(packet) == .status(LightState(isOn: true, brightness: 62, color: RGB(12, 100, 250))))
    }

    @Test(arguments: [
        "", "[]", "{}", "{bad json", #"{"msg":{"cmd":"unknown","data":{}}}"#,
        #"{"msg":{"cmd":"scan","data":{"device":"","sku":"H6195"}}}"#,
        #"{"msg":{"cmd":"scan","data":{"device":"AA"}}}"#,
        #"{"msg":{"cmd":"devStatus","data":{"onOff":1,"brightness":50,"color":{"r":999,"g":0,"b":0}}}}"#,
        #"{"msg":{"cmd":"devStatus","data":{"onOff":2,"brightness":50,"color":{"r":0,"g":0,"b":0}}}}"#
    ])
    func ignoresInvalidPackets(packet: String) {
        #expect(LANProtocol.decode(Data(packet.utf8)) == nil)
    }

    @Test func ignoresOversizedPackets() { #expect(LANProtocol.decode(Data(repeating: 65, count: 8193)) == nil) }

    @Test func changingColorLeavesWhiteMode() {
        let original = LightState(isOn: true, brightness: 50, temperature: 4000)
        let state = LightCommand.color(RGB(1, 2, 3)).applying(to: original)
        #expect(state.temperature == 0)
        #expect(state.color == RGB(1, 2, 3))
        #expect(state.isOn && state.brightness == 50)
    }

    @Test func presetsSurviveStorage() throws {
        let preset = LightPreset(name: "My evening", color: RGB(200, 30, 12), brightness: 23)
        let data = try JSONEncoder().encode([preset])
        #expect(try JSONDecoder().decode([LightPreset].self, from: data) == [preset])
        #expect(Set(LightPreset.builtIns.map(\.id)).count == LightPreset.builtIns.count)
    }

    @Test func unconnectedDevicesDoNotClaimPowerState() {
        let device = LightDevice(id: "test", name: "Test", model: "H6195", connection: .bluetooth)
        #expect(!device.isAvailable && !device.hasKnownState)
        #expect(!device.supportsTemperature)
        #expect(device.status == "Not connected")
    }
}
