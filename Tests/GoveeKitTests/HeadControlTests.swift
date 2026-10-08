import Foundation
import Testing
@testable import GoveeKit

struct HeadControlTests {
    @Test(arguments: [0, 1, 2]) func writesOnlyTheChosenHead(index: Int) throws {
        let command = LightCommand.head(LightHeadState(id: index, color: RGB(0, 0, 255)))
        let packets = try #require(BLEProtocol.commandSequence(command, model: "H60B2", encrypted: true))
        // No whole-lamp manual-color packet: it would overwrite the other heads.
        #expect(packets.count == 1)
        let packet = packets[0]
        #expect(packet.prefix(7) == Data([0x33, 5, 0x15, 1, 0, 0, 255]))
        #expect(packet[12] == UInt8(1 << index) && packet[13] == 0)
        #expect(DeviceCatalog.headName(model: "H60B2", index: index) == ["Bottom", "Middle", "Top"][index])
        #expect(packet.count == 20 && packet.reduce(0, ^) == 0)
        let json = try JSONSerialization.jsonObject(with: LANProtocol.encode(command, model: "H60B2")) as! [String: Any]
        let message = json["msg"] as! [String: Any]
        #expect(message["cmd"] as? String == "ptReal")
        let data = message["data"] as! [String: Any]
        let frames = data["command"] as! [String]
        #expect(frames.count == 1 && Data(base64Encoded: frames[0]) == packet)
    }

    @Test func headOffRetainsItsChosenColor() throws {
        let head = LightHeadState(id: 1, color: RGB(255, 0, 0), brightness: 50, isOn: false)
        let packet = try #require(BLEProtocol.encode(.head(head), model: "H60B2", encrypted: true))
        #expect(packet[4...6] == Data([0, 0, 0]))
        #expect(packet[12] == 2)
        #expect(head.color == RGB(255, 0, 0) && head.brightness == 50)
        var on = head; on.isOn = true
        #expect(on.wireColor == RGB(128, 0, 0))
    }

    @Test func rejectsInvalidHeadsAndUnverifiedModels() throws {
        for index in [-1, 3, 100] {
            let command = LightCommand.head(LightHeadState(id: index))
            #expect(BLEProtocol.commandSequence(command, model: "H60B2", encrypted: true) == nil)
            #expect(throws: ProtocolEncodingError.self) { try LANProtocol.encode(command, model: "H60B2") }
        }
        #expect(BLEProtocol.encode(.head(LightHeadState(id: 0)), model: "H6098", encrypted: true) == nil)
    }

    @Test func mixedHeadPresetsAndLegacyPresetsDecode() throws {
        let heads = [LightHeadState(id: 0, color: RGB(255, 0, 0)),
                     LightHeadState(id: 1, color: RGB(0, 255, 0), brightness: 50),
                     LightHeadState(id: 2, color: RGB(0, 0, 255), isOn: false)]
        let preset = LightPreset(name: "Three colors", color: RGB(255, 0, 0), brightness: 70, heads: heads)
        #expect(try JSONDecoder().decode(LightPreset.self, from: JSONEncoder().encode(preset)).heads == heads)
        let legacy = Data(#"{"id":"old","name":"Old preset","symbol":"bookmark","color":{"red":255,"green":0,"blue":0},"brightness":70,"temperature":0,"isBuiltIn":false}"#.utf8)
        #expect(try JSONDecoder().decode(LightPreset.self, from: legacy).heads == nil)
    }
}
