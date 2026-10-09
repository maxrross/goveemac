import Foundation

/// Motion applied through the lamp's master brightness. Never replaces RGB,
/// individual-head settings, white temperature, or a native scene program.
public enum ColorEffect: String, CaseIterable, Codable, Sendable {
    case breathe, pulse, flicker

    public var title: String { rawValue.capitalized }

    public func brightness(time: Double, base: Int, speed: Double) -> Int {
        let ceiling = max(1, min(100, base))
        let scaled = (time.isFinite ? max(0, time) : 0) * (speed.isFinite ? max(0.1, min(5, speed)) : 1)
        let t = scaled.isFinite ? scaled : 0
        let level: Double
        switch self {
        case .breathe: level = 0.25 + 0.75 * (cos(t.truncatingRemainder(dividingBy: 4) * .pi / 2) + 1) / 2
        case .pulse: level = 0.3 + 0.7 * pow((cos(t.truncatingRemainder(dividingBy: 2) * .pi) + 1) / 2, 3)
        case .flicker:
            let phase = t.truncatingRemainder(dividingBy: 2 * .pi)
            level = 0.75 + 0.15 * sin(phase * 7) + 0.1 * sin(phase * 13)
        }
        return max(1, min(ceiling, Int((Double(ceiling) * level).rounded())))
    }
}
