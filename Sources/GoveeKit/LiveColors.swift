import Foundation

public enum LiveEffect: String, CaseIterable, Codable, Sendable {
    case rainbow, breathe, candle, ocean, aurora, sunset, colorCycle
    public var title: String {
        switch self {
        case .colorCycle: "Color cycle"
        default: rawValue.capitalized
        }
    }
}
public enum LiveColors {
    public static func hsv(_ hue: Double, saturation: Double = 1, value: Double = 1) -> RGB {
        let h = (hue - floor(hue)) * 6, s = max(0, min(1, saturation)), v = max(0, min(1, value))
        let c = v * s, x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1)), m = v - c
        let rgb: (Double, Double, Double)
        switch Int(h) {
        case 0: rgb = (c,x,0); case 1: rgb = (x,c,0); case 2: rgb = (0,c,x)
        case 3: rgb = (0,x,c); case 4: rgb = (x,0,c); default: rgb = (c,0,x)
        }
        return RGB(UInt8(((rgb.0+m)*255).rounded()), UInt8(((rgb.1+m)*255).rounded()), UInt8(((rgb.2+m)*255).rounded()))
    }
    public static func mix(_ a: RGB, _ b: RGB, amount: Double) -> RGB {
        let t = max(0, min(1, amount))
        func channel(_ a: UInt8, _ b: UInt8) -> UInt8 { UInt8((Double(a)*(1-t)+Double(b)*t).rounded()) }
        return RGB(channel(a.red,b.red), channel(a.green,b.green), channel(a.blue,b.blue))
    }
    public static func scale(_ c: RGB, _ level: Double) -> RGB { mix(RGB(0,0,0), c, amount: level) }
    public static func effect(_ effect: LiveEffect, time: Double, count: Int, speed: Double = 1, color: RGB) -> [RGB] {
        (0..<max(1,count)).map { index in
            let t = time * max(0.1,min(5,speed)), phase = Double(index)/Double(max(1,count))
            let wave = (sin(t + phase * 2 * .pi) + 1)/2
            switch effect {
            case .rainbow: return hsv(t/12 + phase/3)
            case .colorCycle: return hsv(t/18)
            case .breathe: return scale(color, 0.08 + 0.92 * wave)
            case .candle: return scale(RGB(255,120,16), 0.5 + 0.35*wave + 0.15*sin(t*7+phase))
            case .ocean: return mix(RGB(0,36,160), RGB(0,230,204), amount: wave)
            case .aurora: return mix(RGB(117,20,230), RGB(12,240,135), amount: wave)
            case .sunset: return mix(RGB(235,24,94), RGB(255,170,16), amount: wave)
            }
        }
    }
    /// RMS energy in three simple frequency bands. No samples are retained.
    public static func audioLevels(_ samples: [Float], sampleRate: Double) -> [Double] {
        guard !samples.isEmpty, sampleRate > 0 else { return [0,0,0] }
        let lowA = 1 - exp(-2 * .pi * 250 / sampleRate)
        let highA = 1 - exp(-2 * .pi * 2500 / sampleRate)
        var low = 0.0, upper = 0.0, energies = [0.0,0.0,0.0]
        for sample in samples {
            let x = Double(sample.isFinite ? sample : 0)
            low += lowA * (x-low); upper += highA * (x-upper)
            let bands = [low, upper-low, x-upper]
            for i in 0..<3 { energies[i] += bands[i]*bands[i] }
        }
        return energies.map { sqrt($0/Double(samples.count)) }
    }
}
