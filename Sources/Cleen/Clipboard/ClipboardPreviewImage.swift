import AppKit
import CleenKit
import SwiftUI

/// A card's picture filling the space it's given: cropped, never stretched, with the
/// card's corners less its padding and a hairline that keeps dark images off the card.
/// While it renders the space stays a quiet well; when there's nothing to show,
/// `fallback` sits in the middle of it.
struct ClipboardPreviewImage<Fallback: View>: View {
    @Environment(ClipboardModel.self) private var model
    let entry: ClipboardEntry
    let preview: ClipboardPreview
    @ViewBuilder let fallback: () -> Fallback

    var body: some View {
        GeometryReader { proxy in
            ClipboardPreviewContent(
                entry: entry,
                preview: preview,
                storedImage: model.imageURL(for: entry),
                size: proxy.size,
                fallback: fallback
            )
        }
        .accessibilityHidden(true)
    }
}

private struct ClipboardPreviewContent<Fallback: View>: View {
    let entry: ClipboardEntry
    let preview: ClipboardPreview
    let storedImage: URL?
    let size: CGSize
    let fallback: () -> Fallback
    @Environment(\.displayScale) private var scale
    @State private var loaded: (key: String, rendering: ClipboardPreviews.Rendering)?

    var body: some View {
        let target = ClipboardPreviews.target(for: entry, preview: preview, storedImage: storedImage, size: size, scale: scale)
        let rendering = target.flatMap { target in
            loaded?.key == target.key ? loaded?.rendering : ClipboardPreviews.shared.cached(target, size: size)
        }
        let shape = RoundedRectangle(cornerRadius: ClipboardCard.Metrics.innerRadius, style: .continuous)
        ZStack {
            shape.fill(NotchStyle.card)
            if let image = rendering?.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height, alignment: preview.anchor == .top ? .top : .center)
                    .clipShape(shape)
                    .overlay { shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1 / max(scale, 1)) }
                    .transition(.opacity)
            } else if rendering != nil || target == nil {
                fallback()
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: target?.key) {
            guard let target, size.width > 0, size.height > 0, ClipboardPreviews.shared.cached(target, size: size) == nil else { return }
            guard let rendering = await ClipboardPreviews.shared.load(target, size: size, scale: scale), !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.18)) { loaded = (target.key, rendering) }
        }
    }
}
