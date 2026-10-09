import SwiftUI
import ShadcnUI

/// Page navigation composed from ShadKit's typography, palette and bare buttons.
/// Equal widths avoid label-length sizing; selection does not animate page layout.
struct LightTabsView: View {
    @Binding var selection: String
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme
    private let tabs = ["Color", "Scenes", "Music", "Screen", "Saved looks"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let selected = selection == tab
                Button {
                    guard selection != tab else { return }
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { selection = tab }
                } label: {
                    Text(tab)
                        .font(theme.typography.sans(theme.typography.sm, weight: .medium))
                        .foregroundStyle(selected ? palette.foreground : palette.mutedForeground)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(selected ? palette.foreground : .clear).frame(height: 2)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.shadcnBare)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("light-tab-\(tab)")
            }
        }
    }
}
