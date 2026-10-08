import SwiftUI
import GoveeKit

struct ColorSwatch: View {
    let color: RGB
    var selected = false
    var label: String?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Circle().fill(color.swiftUIColor)
                .overlay { if selected { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white) } }
                .padding(3)
                .overlay { Circle().strokeBorder(selected ? Color.primary.opacity(0.6) : Color.clear, lineWidth: 1) }
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }.buttonStyle(.plain)
            .accessibilityLabel(label ?? "Set color \(color.hex)")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .help(color.hex)
    }
}
