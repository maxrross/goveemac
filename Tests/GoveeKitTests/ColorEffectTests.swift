import Foundation
import Testing
@testable import GoveeKit

@Suite struct ColorEffectTests {
    @Test func brightnessMotionStaysWithinTheChosenCeiling() {
        for effect in ColorEffect.allCases {
            for base in [1, 14, 70, 100] {
                for speed in [0.1, 1.0, 5.0] {
                    for step in 0...100 {
                        let value = effect.brightness(time: Double(step) / 8, base: base, speed: speed)
                        #expect((1...base).contains(value))
                    }
                }
            }
        }
    }

    @Test func breatheStartsAtFullBrightnessAndRepeatsSmoothly() {
        #expect(ColorEffect.breathe.brightness(time: 0, base: 80, speed: 1) == 80)
        #expect(ColorEffect.breathe.brightness(time: 2, base: 80, speed: 1) == 20)
        #expect(ColorEffect.breathe.brightness(time: 4, base: 80, speed: 1) == 80)
        #expect(ColorEffect.breathe.brightness(time: 1, base: 80, speed: 2) == 20)
    }

    @Test func overlayPacketsCannotReplaceColorsOrSceneSelection() throws {
        for effect in ColorEffect.allCases {
            let value = effect.brightness(time: 1.25, base: 70, speed: 1)
            let packets = try #require(BLEProtocol.commandSequence(.brightness(value), model: "H60B2", encrypted: true))
            #expect(packets.count == 1)
            #expect(packets[0][0] == 0x33)
            #expect(packets[0][1] == 0x04)
            #expect(packets[0][2] == UInt8(value))
        }
    }

    @Test func invalidInputsRemainSafeAndFlickerVaries() {
        for effect in ColorEffect.allCases {
            #expect((1...100).contains(effect.brightness(time: .infinity, base: 999, speed: .nan)))
            #expect(effect.brightness(time: 0, base: -1, speed: 1) == 1)
            #expect((1...100).contains(effect.brightness(time: .greatestFiniteMagnitude, base: 70, speed: 5)))
            #expect((1...70).contains(effect.brightness(time: .greatestFiniteMagnitude, base: 70, speed: 1)))
        }
        #expect(Set((0..<40).map { ColorEffect.flicker.brightness(time: Double($0) / 8, base: 70, speed: 1) }).count > 10)
    }
}
