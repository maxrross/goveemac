import AppKit
import SwiftUI

/// macOS can retain native scrollers when SwiftUI requests hidden indicators.
/// Place this inside scroll content; it only configures its enclosing scroll view.
struct ScrollIndicatorHider: NSViewRepresentable {
    func makeNSView(context: Context) -> IndicatorProbe { IndicatorProbe() }
    func updateNSView(_ view: IndicatorProbe, context: Context) { view.hideIndicators() }

    final class IndicatorProbe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.hideIndicators() }
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            DispatchQueue.main.async { [weak self] in self?.hideIndicators() }
        }

        override func layout() {
            super.layout()
            hideIndicators()
        }

        func hideIndicators() {
            var parent = superview
            while let view = parent {
                if let scroll = view as? NSScrollView {
                    // Legacy scrollers reserve width even during page-layout
                    // changes, causing short and tall tabs to shift sideways.
                    if scroll.scrollerStyle != .overlay { scroll.scrollerStyle = .overlay }
                    if scroll.hasVerticalScroller { scroll.hasVerticalScroller = false }
                    if scroll.hasHorizontalScroller { scroll.hasHorizontalScroller = false }
                    return
                }
                parent = view.superview
            }
        }
    }
}
