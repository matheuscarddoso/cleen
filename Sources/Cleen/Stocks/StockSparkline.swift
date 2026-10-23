import CleenKit
import SwiftUI

extension StockQuote.Direction {
    /// Green up, red down, grey when the day is flat.
    var tint: Color {
        switch self {
        case .up: NotchStyle.good
        case .down: NotchStyle.critical
        case .flat: NotchStyle.secondary
        }
    }
}

/// Today's line for one ticker, across the whole session so a morning chart stops
/// partway, over a dotted line at the previous close. A Path rather than Swift Charts:
/// the tab draws a dozen of these each minute and needs no axes.
struct StockSparkline: View {
    let quote: StockQuote
    var lineWidth = 1.25
    var showsBaseline = true

    var body: some View {
        let layout = StockChart.layout(quote)
        let tint = quote.direction.tint
        Canvas { context, size in
            let inset = lineWidth
            let height = max(size.height - inset * 2, 1)
            func point(_ p: StockChart.Point) -> CGPoint {
                CGPoint(x: p.x * size.width, y: inset + (1 - p.y) * height)
            }

            if showsBaseline, let baseline = layout.baseline {
                let y = inset + (1 - baseline) * height
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(NotchStyle.tertiary), style: StrokeStyle(lineWidth: 1, dash: [1.5, 2.5]))
            }

            guard layout.points.count > 1 else { return }
            var line = Path()
            line.addLines(layout.points.map(point))

            var area = line
            area.addLine(to: CGPoint(x: point(layout.points.last!).x, y: size.height))
            area.addLine(to: CGPoint(x: point(layout.points.first!).x, y: size.height))
            area.closeSubpath()
            context.fill(area, with: .linearGradient(
                Gradient(colors: [tint.opacity(0.22), tint.opacity(0)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
            ))
            context.stroke(line, with: .color(tint), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// The day's change as a colored pill: `+1,53%`.
struct StockChangePill: View {
    let quote: StockQuote
    var fontSize = 10.5

    var body: some View {
        let tint = quote.direction.tint
        Text(quote.changeFraction.map { StockFormat.change($0) } ?? "—")
            .font(.system(size: fontSize, weight: .semibold).monospacedDigit())
            .foregroundStyle(tint)
            .contentTransition(.numericText())
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(quote.direction == .flat ? NotchStyle.control : tint.opacity(0.16), in: .capsule)
            .lineLimit(1)
            .fixedSize()
    }
}
