import Foundation
import Testing
@testable import GoveeKit

@Suite struct SceneIconTests {
    @Test func nativeLibraryRetainsGoveeIconsWithoutChangingCommands() throws {
        let data = Data(#"{"data":{"categories":[{"categoryName":"Natural","scenes":[{"sceneName":"Star","iconUrls":["https://example.com/light.png","https://example.com/pressed.png","https://example.com/dark.png"],"lightEffects":[{"sceneCode":13903,"scenceParam":""}]}]}]}}"#.utf8)
        let scene = try #require(NativeScene.parseLibrary(data, model: "H60B2").first)
        #expect(scene.iconURLs?.count == 3)
        #expect(scene.iconURLs?[2].lastPathComponent == "dark.png")
        #expect(scene.packets == NativeScene(model: "H60B2", name: "Star", category: "Natural", code: 13903, parameter: Data()).packets)
    }

    @Test func unsafeIconURLsAreIgnoredAndOldSceneFilesDecode() throws {
        let data = Data(#"{"data":{"categories":[{"scenes":[{"sceneName":"Star","iconUrls":["file:///tmp/private.png","http://example.com/icon.png","https://user:password@example.com/icon.png"],"lightEffects":[{"sceneCode":13903,"scenceParam":""}]}]}]}}"#.utf8)
        let scene = try #require(NativeScene.parseLibrary(data, model: "H60B2").first)
        #expect(scene.iconURLs == nil)
        let old = Data(#"{"id":"H60B2:13903","model":"H60B2","name":"Star","category":"Natural","code":13903,"parameter":""}"#.utf8)
        #expect(try JSONDecoder().decode(NativeScene.self, from: old).iconURLs == nil)
    }
}
