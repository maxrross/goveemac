import AppKit
import ImageIO

/// Bounded cache of decoded thumbnails, shared across scene-browser lifetimes.
@MainActor final class SceneIconCache {
    static let shared = SceneIconCache()
    private var images: [URL: NSImage] = [:]
    private var order: [URL] = []
    private var pending: [URL: Task<CGImage?, Never>] = [:]

    func cachedImage(for url: URL) -> NSImage? { images[url] }

    func image(for url: URL) async -> NSImage? {
        if let image = images[url] { return image }
        let task: Task<CGImage?, Never>
        if let loading = pending[url] { task = loading }
        else {
            task = Task.detached(priority: .utility) {
                guard url.scheme == "https",
                      let (data, response) = try? await URLSession.shared.data(from: url),
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      data.count <= 2_000_000,
                      let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
                // Decode a 2× thumbnail off the main thread instead of decoding
                // the full remote artwork during a page's first layout.
                return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 160,
                    kCGImageSourceShouldCacheImmediately: true
                ] as CFDictionary)
            }
            pending[url] = task
        }
        let thumbnail = await task.value
        pending[url] = nil
        if let image = images[url] { return image }
        guard let thumbnail else { return nil }
        let image = NSImage(cgImage: thumbnail, size: .zero)
        images[url] = image; order.append(url)
        if order.count > 128 { images[order.removeFirst()] = nil }
        return image
    }
}
