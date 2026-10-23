import AppKit
import CoreImage
import SwiftUI

/// Softens a scroll view's edges only where there's more to see, like shadcn's scroll
/// fade: content dissolves into the panel with a progressive blur instead of a hard cut,
/// and the edge you've reached goes crisp again.
struct ScrollEdgeFade: ViewModifier {
    let axis: Axis
    var length = 22.0
    @State private var edges = Edges()

    struct Edges: Equatable {
        var leading = false
        var trailing = false
    }

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Edges.self) { geometry in
                let offset = axis == .vertical ? geometry.contentOffset.y + geometry.contentInsets.top : geometry.contentOffset.x + geometry.contentInsets.leading
                let visible = axis == .vertical ? geometry.containerSize.height : geometry.containerSize.width
                let total = axis == .vertical ? geometry.contentSize.height : geometry.contentSize.width
                return Edges(leading: offset > 1, trailing: offset + visible < total - 1)
            } action: { _, new in
                withAnimation(.smooth(duration: 0.2)) { edges = new }
            }
            .mask(FadeMask(axis: axis, length: length, leading: edges.leading, trailing: edges.trailing))
            .overlay(alignment: axis == .vertical ? .top : .leading) {
                EdgeBlur(axis: axis, length: length, atStart: true).opacity(edges.leading ? 1 : 0)
            }
            .overlay(alignment: axis == .vertical ? .bottom : .trailing) {
                EdgeBlur(axis: axis, length: length, atStart: false).opacity(edges.trailing ? 1 : 0)
            }
    }
}

/// Opaque in the middle, eased to clear at each edge that has more content.
private struct FadeMask: View {
    let axis: Axis
    let length: Double
    let leading: Bool
    let trailing: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = axis == .vertical ? proxy.size.height : proxy.size.width
            let ramp = min(0.45, length / max(size, 1))
            LinearGradient(stops: stops(ramp: ramp), startPoint: axis == .vertical ? .top : .leading, endPoint: axis == .vertical ? .bottom : .trailing)
        }
    }

    /// Ease-out curve so the fade reads as gradual rather than a band.
    private func stops(ramp: Double) -> [Gradient.Stop] {
        let curve: [(Double, Double)] = [(0, 0), (0.25, 0.12), (0.5, 0.4), (0.75, 0.75), (1, 1)]
        var result: [Gradient.Stop] = []
        if leading {
            result += curve.map { .init(color: .black.opacity($0.1), location: $0.0 * ramp) }
        } else {
            result.append(.init(color: .black, location: 0))
        }
        if trailing {
            result += curve.reversed().map { .init(color: .black.opacity($0.1), location: 1 - $0.0 * ramp) }
        } else {
            result.append(.init(color: .black, location: 1))
        }
        return result
    }
}

/// A strip that blurs what's behind it, strongest at the edge and gone inward. A plain
/// Gaussian on the backdrop, no material: materials lift black to grey.
private struct EdgeBlur: NSViewRepresentable {
    let axis: Axis
    let length: Double
    let atStart: Bool

    func makeNSView(context: Context) -> BackdropBlurView {
        BackdropBlurView(axis: axis, atStart: atStart)
    }

    func updateNSView(_ view: BackdropBlurView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BackdropBlurView, context: Context) -> CGSize? {
        axis == .vertical
            ? CGSize(width: proposal.width ?? 0, height: length)
            : CGSize(width: length, height: proposal.height ?? 0)
    }
}

final class BackdropBlurView: NSView {
    private let fade = CAGradientLayer()

    init(axis: Axis, atStart: Bool) {
        super.init(frame: .zero)
        wantsLayer = true
        layerUsesCoreImageFilters = true
        let blur = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 5])
        layer?.backgroundFilters = blur.map { [$0] }
        layer?.masksToBounds = true
        // Opaque at the outer edge, clear inward: the blur eases off like the fade.
        fade.colors = [NSColor.black.cgColor, NSColor.black.withAlphaComponent(0.55).cgColor, NSColor.clear.cgColor]
        fade.locations = [0, 0.45, 1]
        let outer: CGPoint = axis == .vertical ? (atStart ? CGPoint(x: 0.5, y: 1) : CGPoint(x: 0.5, y: 0)) : (atStart ? CGPoint(x: 0, y: 0.5) : CGPoint(x: 1, y: 0.5))
        fade.startPoint = outer
        fade.endPoint = CGPoint(x: 1 - outer.x, y: 1 - outer.y)
        layer?.mask = fade
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.frame = bounds
        CATransaction.commit()
    }
}

extension View {
    /// Fades and blurs the scroll view's edges where more content is waiting.
    func scrollEdgeFade(_ axis: Axis = .vertical, length: Double = 22) -> some View {
        modifier(ScrollEdgeFade(axis: axis, length: length))
    }
}
