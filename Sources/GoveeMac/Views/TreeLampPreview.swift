import SwiftUI
import GoveeKit

struct TreeLampPreview: View {
    let heads: [LightHeadState]
    var sceneName: String?
    private var hasLiveColors: Bool { sceneName == nil && heads.allSatisfy(\.hasRequestedState) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: 35, y: 14)); path.addLine(to: CGPoint(x: 35, y: 86))
                for (x, y) in [(26.0, 15.0), (45.0, 42.0), (26.0, 69.0)] {
                    path.move(to: CGPoint(x: x, y: y)); path.addLine(to: CGPoint(x: 35, y: y + 10))
                }
            }.stroke(.secondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            ForEach(heads) { head in
                Ellipse().fill(hasLiveColors ? (head.isOn ? head.color.swiftUIColor : Color.secondary.opacity(0.3)) : Color.secondary.opacity(0.4))
                    .overlay { Ellipse().strokeBorder(.primary.opacity(0.15), lineWidth: 1) }
                    .frame(width: 26, height: 14)
                    .rotationEffect(.degrees(head.id == 1 ? 10 : -10))
                    .offset(x: head.id == 1 ? 43 : 3, y: CGFloat(2 - head.id) * 27 + 5)
            }
            Capsule().fill(.secondary).frame(width: 44, height: 5).offset(x: 13, y: 85)
            Text(sceneName == nil ? "Color unknown" : "Scene active")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize().frame(width: 72).offset(y: 98)
                .opacity(hasLiveColors ? 0 : 1)
        }.frame(width: 72, height: 112)
    }
}
