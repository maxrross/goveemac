import Foundation
import Testing
@testable import GoveeKit

struct SceneAndLiveTests {
    @Test func sceneFragmentsMatchPublishedProtocol() throws {
        let scene = NativeScene(model: "H60B2", name: "Fixture", category: "Test", code: 0x1234, parameter: Data(0..<40))
        let frames = try #require(scene.packets)
        #expect(frames.count == 4)
        #expect(frames[0].prefix(5) == Data([0xA3,0,1,3,2]))
        #expect(frames[1].prefix(2) == Data([0xA3,1]))
        #expect(frames[2].prefix(2) == Data([0xA3,0xFF]))
        #expect(frames[3].prefix(5) == Data([0x33,5,4,0x34,0x12]))
        #expect(frames.allSatisfy { $0.count == 20 && $0.reduce(0, ^) == 0 })
        let reconstructed = frames[0][5..<19] + frames[1][2..<19] + frames[2][2..<11]
        #expect(reconstructed == scene.parameter)
        #expect(BLEProtocol.commandSequence(.scene(scene), model: "H6098", encrypted: true) == nil)
        #expect(throws: SceneError.self) { try LANProtocol.encode(.scene(scene), model: "H6098") }
        let json = try JSONSerialization.jsonObject(with: LANProtocol.encode(.scene(scene), model: "H60B2")) as! [String: Any]
        let message = json["msg"] as! [String: Any], data = message["data"] as! [String: Any]
        #expect(data["command"] as? [String] == frames.map { $0.base64EncodedString() })
    }
    @Test func fragmentsHandleBoundaryAndRejectInvalidLibraries() throws {
        for count in [1,14,15,31,32,2048] {
            let scene = NativeScene(model: "H60B2", name: "T", category: "T", code: 1, parameter: Data(repeating: 42, count: count))
            let frames = try #require(scene.packets)
            #expect(frames.allSatisfy { $0.count == 20 && $0.reduce(0, ^) == 0 })
            let dataFrames = frames.dropLast()
            #expect(dataFrames.last?[1] == 0xFF || dataFrames.count == 1)
        }
        let resident = NativeScene(model: "H60B2", name: "Rainbow", category: "Natural", code: 22, parameter: Data())
        #expect(resident.packets?.count == 1 && resident.packets?.first?.prefix(5) == Data([0x33,5,4,22,0]))
        #expect(NativeScene(model: "H60B2", name: "T", category: "T", code: 0, parameter: Data([1])).packets == nil)
        #expect(throws: SceneError.self) { try NativeScene.parseLibrary(Data("{}".utf8), model: "H60B2") }
        let fixture = Data(#"{"data":{"categories":[{"categoryName":"Natural","scenes":[{"sceneName":"Aurora","lightEffects":[{"sceneCode":12,"scenceParam":"AQ==","specialEffect":[{"supportSku":["H60B2"],"scenceParam":"AgM="}]}]}]}]}}"#.utf8)
        let scenes = try NativeScene.parseLibrary(fixture, model: "H60B2")
        #expect(scenes.count == 1 && scenes[0].name == "Aurora" && scenes[0].parameter == Data([2,3]))
    }
    @Test func audioBandsDistinguishBassAndTreble() {
        func tone(_ frequency: Double) -> [Float] { (0..<4800).map { Float(sin(2 * .pi * frequency * Double($0)/48000)*0.5) } }
        let bass = LiveColors.audioLevels(tone(60), sampleRate: 48000)
        let treble = LiveColors.audioLevels(tone(10000), sampleRate: 48000)
        #expect(bass[0] > bass[2]*5)
        #expect(treble[2] > treble[0]*5)
        #expect(LiveColors.audioLevels(Array(repeating: 0, count: 100), sampleRate: 48000) == [0,0,0])
        #expect(LiveColors.audioLevels([], sampleRate: 48000) == [0,0,0])
    }
    @Test func effectsAnimateAndKeepChannelBounds() {
        for effect in LiveEffect.allCases {
            let first = LiveColors.effect(effect, time: 0, count: 3, color: RGB(255,100,20))
            let later = LiveColors.effect(effect, time: 2.7, count: 3, color: RGB(255,100,20))
            #expect(first.count == 3 && first != later)
        }
        #expect(LiveColors.hsv(0) == RGB(255,0,0))
        #expect(LiveColors.hsv(1.0/3) == RGB(0,255,0))
        #expect(LiveColors.scale(RGB(255,50,100), 0) == RGB(0,0,0))
    }
    @Test func screenRegionsPreserveHeadOrderAndIgnoreRowPadding() throws {
        let width = 6, height = 6, rowBytes = 32
        var bytes = [UInt8](repeating: 255, count: rowBytes*height)
        let bands = [RGB(255,0,0), RGB(0,255,0), RGB(0,0,255)]
        for y in 0..<height {
            for x in 0..<width {
                let color = bands[y/2], offset = y*rowBytes+x*4
                bytes[offset] = color.blue; bytes[offset+1] = color.green; bytes[offset+2] = color.red
            }
        }
        #expect(ScreenColors.sample(bgra: bytes, width: width, height: height, rowBytes: rowBytes, mapping: "rows") == bands.reversed().map { $0 })
        #expect(ScreenColors.sample(bgra: bytes, width: width, height: height, rowBytes: rowBytes, mapping: "whole") == Array(repeating: RGB(85,85,85), count: 3))
        #expect(ScreenColors.sample(bgra: [], width: width, height: height, rowBytes: rowBytes, mapping: "rows") == nil)
        #expect(ScreenColors.sample(bgra: bytes, width: -1, height: height, rowBytes: rowBytes, mapping: "rows") == nil)
    }
    @Test func rejectsOversizedSocketPathsAndPreservesControlRequests() throws {
        #expect(throws: ControlError.self) { try ControlSocket.address(String(repeating: "x", count: 200)) }
        var request = ControlRequest(action: "head"); request.head = "top"; request.value = "#FF0000"
        let roundtrip = try JSONDecoder().decode(ControlRequest.self, from: JSONEncoder().encode(request))
        #expect(roundtrip.action == "head" && roundtrip.head == "top" && roundtrip.value == "#FF0000")
    }
}
