import Foundation
import Testing
@testable import GoveeKit

struct MusicResponseTests {
    @Test func quietAudioProducesVisibleColorsAndSilenceFadesOut() {
        var response = MusicResponse()
        let colors = response.update(levels: [0.004, 0.002, 0.001], time: 0)
        #expect(colors.allSatisfy { max($0.red, $0.green, $0.blue) > 90 })
        for i in 1...120 { _ = response.update(levels: [0, 0, 0], time: Double(i) / 30) }
        #expect(response.colors == Array(repeating: RGB(0, 0, 0), count: 3))
    }

    @Test func repeatedBassOnsetsChangeHueWithoutRandomFlashing() {
        var response = MusicResponse()
        var peaks: [RGB] = []
        for i in 0..<90 {
            let beat = i % 15 == 0
            let colors = response.update(levels: [beat ? 0.10 : 0.008, 0.02, 0.006], time: Double(i) / 30)
            if beat { peaks.append(colors[0]) }
        }
        #expect(response.beatCount >= 5)
        #expect(Set(peaks.map(\.hex)).count >= 5)
        #expect(peaks.allSatisfy { max($0.red, $0.green, $0.blue) > 170 })
    }

    @Test func continuousToneStaysLitAndInvalidEnergyIsIgnored() {
        var response = MusicResponse()
        for i in 0..<120 { _ = response.update(levels: [0.03, 0.01, 0.004], time: Double(i) / 30) }
        #expect(response.beatCount == 1)
        #expect(response.colors.allSatisfy { max($0.red, $0.green, $0.blue) > 100 })
        for i in 120..<240 { _ = response.update(levels: [.nan, -.infinity, -1], time: Double(i) / 30) }
        #expect(response.colors == Array(repeating: RGB(0, 0, 0), count: 3))
    }

    @Test func audioFiltersKeepContinuityAcrossBufferBoundaries() {
        let samples = (0..<4096).map { Float(0.4 * sin(2 * .pi * 60 * Double($0) / 48000) + 0.1 * sin(2 * .pi * 8000 * Double($0) / 48000)) }
        var full = AudioBands(), chunks = AudioBands()
        let expected = full.levels(samples, sampleRate: 48000)
        var accumulated = [0.0, 0.0, 0.0]
        for offset in stride(from: 0, to: samples.count, by: 1024) {
            let levels = chunks.levels(Array(samples[offset..<offset + 1024]), sampleRate: 48000)
            for i in 0..<3 { accumulated[i] += levels[i] * levels[i] / 4 }
        }
        for i in 0..<3 { #expect(abs(sqrt(accumulated[i]) - expected[i]) < 1e-10) }
    }
}
