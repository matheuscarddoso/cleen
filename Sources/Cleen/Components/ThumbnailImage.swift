import SwiftUI

/// An image file drawn resizable to fit or fill its frame, like
/// `Image(nsImage:).resizable().scaledToFit()` / `.scaledToFill()`, but decoded at the
/// frame's size off the main thread (see `Thumbnails`).
struct ThumbnailImage: View {
    let url: URL
    let mode: Thumbnails.Mode

    var body: some View {
        GeometryReader { proxy in
            ThumbnailContent(url: url, size: proxy.size, mode: mode)
        }
    }
}

private struct ThumbnailContent: View {
    let url: URL
    let size: CGSize
    let mode: Thumbnails.Mode
    @State private var loaded: (key: String, image: NSImage)?

    private var key: String { "\(url.path)|\(Int(size.width))x\(Int(size.height))" }

    var body: some View {
        // Ready in the cache (prefetched) → drawn on the first frame, no pop-in.
        let image = loaded?.key == key ? loaded?.image : Thumbnails.shared.cached(url, size: size, mode: mode)
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: mode == .fill ? .fill : .fit)
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: key) {
            guard size.width > 0, size.height > 0, Thumbnails.shared.cached(url, size: size, mode: mode) == nil else { return }
            if let image = await Thumbnails.shared.load(url, size: size, mode: mode) {
                loaded = (key, image)
            }
        }
    }
}
