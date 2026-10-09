import AppKit
import SwiftUI
import ShadcnUI

struct SceneIconView: View {
    let url: URL?
    @State private var loadedURL: URL?
    @State private var image: NSImage?
    @Environment(\.shadcnPalette) private var palette

    var body: some View {
        let cached = url.flatMap { SceneIconCache.shared.cachedImage(for: $0) }
        Group {
            if let image = cached ?? (loadedURL == url ? image : nil) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "sparkles").font(.title2).foregroundStyle(palette.mutedForeground)
            }
        }
        .task(id: url) {
            guard let url else { image = nil; loadedURL = nil; return }
            let result = await SceneIconCache.shared.image(for: url)
            guard !Task.isCancelled else { return }
            image = result; loadedURL = url
        }
    }
}
