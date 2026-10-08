import Foundation

/// Stateful crossover filters avoid restarting the audio analysis at each buffer.
public struct AudioBands: Sendable {
    private var low = 0.0
    private var upper = 0.0
    private var dc = 0.0
    public init() { }

    public mutating func levels(_ samples: [Float], sampleRate: Double) -> [Double] {
        guard !samples.isEmpty, sampleRate.isFinite, sampleRate > 0 else { return [0, 0, 0] }
        let lowA = 1 - exp(-2 * .pi * 250 / sampleRate)
        let highA = 1 - exp(-2 * .pi * 2500 / sampleRate)
        let dcA = 1 - exp(-2 * .pi * 20 / sampleRate)
        var energies = [0.0, 0.0, 0.0]
        for sample in samples {
            let raw = Double(sample.isFinite ? sample : 0)
            dc += dcA * (raw - dc)
            let x = raw - dc
            low += lowA * (x - low); upper += highA * (x - upper)
            let bands = [low, upper - low, x - upper]
            for i in 0..<3 { energies[i] += bands[i] * bands[i] }
        }
        return energies.map { sqrt($0 / Double(samples.count)) }
    }
}

/// Audio-driven brightness and hue, with automatic gain, onset detection and
/// fast attack / slower release. Stores energy values only, never audio samples.
public struct MusicResponse: Sendable {
    private var reference = 0.008
    private var envelope = [0.0, 0.0, 0.0]
    private var averageBass = 0.0
    private var previousBass = 0.0
    private var lastTime: Double?
    private var lastBeat = -Double.infinity
    private var hue = 0.58
    public private(set) var beatCount = 0
    public private(set) var colors = Array(repeating: RGB(0, 0, 0), count: 3)
    public init() { }

    public mutating func update(levels: [Double], time: Double, sensitivity: Double = 2) -> [RGB] {
        guard time.isFinite else { return colors }
        let dt = min(0.5, max(0.001, time - (lastTime ?? time - 1.0 / 30)))
        lastTime = time
        let raw = (0..<3).map { i in i < levels.count && levels[i].isFinite ? max(0, levels[i]) : 0 }
        let energy = zip(raw, [1.0, 1.4, 2.0]).map(*)
        let strongest = energy.max() ?? 0
        let audible = strongest > 0.0003
        reference = max(0.003, strongest, reference * exp(-dt / 4))
        let gain = sensitivity.isFinite ? min(5, max(0.2, sensitivity)) / 2 : 1
        if audible, raw[0] > averageBass * 1.45 + 0.0005,
           raw[0] > previousBass * 1.08, time - lastBeat > 0.20 {
            hue = (hue + 0.137).truncatingRemainder(dividingBy: 1)
            lastBeat = time; beatCount += 1
        }
        averageBass += (raw[0] - averageBass) * (1 - exp(-dt / 0.45))
        previousBass = raw[0]
        let total = energy.reduce(0, +)
        let spectrum = total > 0 ? (energy[1] + 2 * energy[2]) / (2 * total) : 0
        if audible { hue = (hue + dt * 0.025 * min(1, strongest / reference)).truncatingRemainder(dividingBy: 1) }
        for i in 0..<3 {
            let target = audible ? sqrt(min(1, energy[i] / reference * gain)) : 0
            let duration = target > envelope[i] ? 0.018 : 0.18
            envelope[i] += (target - envelope[i]) * (1 - exp(-dt / duration))
            let brightness = envelope[i] < 0.002 ? 0 : min(1, envelope[i] + (audible ? 0.10 : 0))
            colors[i] = LiveColors.hsv(hue + Double(i) * 0.14 + spectrum * 0.22, saturation: 0.88, value: brightness)
        }
        return colors
    }
}
