import AppKit
import CleenKit
import SwiftUI

/// Screen Studio's timeline: the ruler with its marks and dots, the clips (amber) and the
/// zooms (violet) as rounded blocks, the playhead's violet pin and a grey one under the
/// pointer. With the scissors out, an amber pin shows where a click splits the clip.
/// Everything counts in the finished video's seconds.
struct EditorTimeline: View {
    @Environment(EditorModel.self) private var editor
    @State private var hoverX: CGFloat?
    @State private var scroll = ScrollPosition(edge: .leading)
    @State private var scrollX: CGFloat = 0

    static let margin: CGFloat = 20
    // Rows, top to bottom (Screen Studio's proportions).
    static let pinY: CGFloat = 9
    static let labelY: CGFloat = 30
    static let dotY: CGFloat = 42
    static let markerY: CGFloat = 54
    static let clipY: CGFloat = 66
    static let clipHeight: CGFloat = 50
    static let zoomY: CGFloat = 127
    static let zoomHeight: CGFloat = 47

    var body: some View {
        GeometryReader { proxy in
            let scale = pointsPerSecond(width: proxy.size.width)
            let content = editor.duration * scale + Self.margin * 2
            ScrollView(.horizontal) {
                ZStack(alignment: .topLeading) {
                    Color.clear
                    ruler(scale: scale, width: content)
                    clips(scale: scale)
                    zooms(scale: scale, width: content)
                    if let hoverX, !editor.isCutting { pin(at: hoverX, color: EditorTheme.hoverPin, height: proxy.size.height).allowsHitTesting(false) }
                    if editor.isCutting, let hoverX { scissorPin(at: hoverX) }
                    playhead(scale: scale, height: proxy.size.height)
                }
                .frame(width: max(content, proxy.size.width), height: proxy.size.height)
                .coordinateSpace(.named("timeline"))
                .onContinuousHover(coordinateSpace: .named("timeline")) { phase in
                    switch phase {
                    case .active(let point):
                        let x = min(max(point.x, Self.margin), Self.margin + editor.duration * scale)
                        hoverX = x
                    case .ended:
                        hoverX = nil
                    }
                }
            }
            .scrollPosition($scroll)
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, x in scrollX = x }
            .scrollIndicators(editor.timelineZoom > 1 ? .automatic : .never)
            .scrollDisabled(editor.timelineZoom <= 1)
            .onChange(of: editor.currentTime) { _, time in
                follow(time: time, scale: scale, visible: proxy.size.width)
            }
        }
    }

    private func pointsPerSecond(width: CGFloat) -> CGFloat {
        (width - Self.margin * 2) / CGFloat(editor.duration) * CGFloat(editor.timelineZoom)
    }

    private func x(_ t: Double, _ scale: CGFloat) -> CGFloat { Self.margin + CGFloat(t) * scale }

    private func t(_ x: CGFloat, _ scale: CGFloat) -> Double { max(0, min(editor.duration, Double((x - Self.margin) / max(0.0001, scale)))) }

    /// While playing zoomed in, the view pages along with the playhead.
    private func follow(time: Double, scale: CGFloat, visible: CGFloat) {
        guard editor.isPlaying, editor.timelineZoom > 1 else { return }
        let px = x(time, scale)
        let left = scrollX
        if px > left + visible - 60 || px < left {
            withAnimation(.easeInOut(duration: 0.35)) { scroll.scrollTo(x: max(0, px - 80)) }
        }
    }

    // MARK: Ruler

    private func ruler(scale: CGFloat, width: CGFloat) -> some View {
        let step = Self.step(scale: scale)
        let marks = Array(stride(from: 0.0, through: editor.duration, by: step / 2))
        return ZStack(alignment: .topLeading) {
            Color.clear.frame(width: width, height: Self.clipY - 4)
            ForEach(marks.indices, id: \.self) { index in
                let mark = marks[index]
                let isLabel = index % 2 == 0 && index > 0
                if isLabel {
                    Text(verbatim: Self.clock(mark, tenths: false))
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(EditorTheme.tertiary)
                        .fixedSize()
                        .position(x: x(mark, scale), y: Self.labelY)
                }
                Circle()
                    .fill(EditorTheme.tertiary.opacity(0.75))
                    .frame(width: 3.5, height: 3.5)
                    .position(x: x(mark, scale), y: Self.dotY)
            }
        }
        .contentShape(.rect)
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline")).onChanged { drag in
            editor.seek(to: t(drag.location.x, scale))
        })
    }

    /// Labels every 1, 2, 5, 10, 15, 30 or 60 s, at least 120 points apart.
    static func step(scale: CGFloat) -> Double {
        [1, 2, 5, 10, 15, 30, 60, 120, 300, 600].first { CGFloat($0) * scale >= 120 } ?? 1200
    }

    // MARK: Clips

    private func clips(scale: CGFloat) -> some View {
        let starts = editor.timeline.starts
        let step = Self.step(scale: scale)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(editor.project.clips.enumerated()), id: \.element.id) { index, clip in
                let start = starts[index]
                EditorClipBlock(
                    clip: clip,
                    width: max(6, CGFloat(clip.duration) * scale - 3),
                    ticks: Self.ticks(from: start, length: clip.duration, step: step / 2, scale: scale),
                    isSelected: editor.selection == .clip(clip.id),
                    isDimmed: { if case .clip(let id) = editor.selection { return id != clip.id } else { return false } }(),
                    scale: scale,
                    outputStart: start
                )
                .offset(x: x(start, scale) + (index > 0 ? 1.5 : 0), y: Self.clipY)
            }
        }
    }

    /// Where the ruler's half-step marks fall inside a clip, from its left edge.
    private static func ticks(from start: Double, length: Double, step: Double, scale: CGFloat) -> [CGFloat] {
        var result: [CGFloat] = []
        var mark = (start / step).rounded(.up) * step
        while mark < start + length {
            if mark > start + 0.01 { result.append(CGFloat(mark - start) * scale) }
            mark += step
        }
        return result
    }

    // MARK: Zooms

    private func zooms(scale: CGFloat, width: CGFloat) -> some View {
        let timeline = editor.timeline
        return ZStack(alignment: .topLeading) {
            // The empty track: a click adds a zoom there.
            Color.clear
                .frame(width: width, height: Self.zoomHeight)
                .contentShape(.rect)
                .onTapGesture(coordinateSpace: .named("timeline")) { point in
                    editor.seek(to: t(point.x, scale))
                    editor.addZoom()
                }
                .help("Clique para adicionar um zoom")
                .offset(y: Self.zoomY)
            if let hoverX, !editor.isCutting, isOverEmptyZoomTrack(hoverX, scale: scale) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(EditorTheme.zoomTop.opacity(0.18))
                    .overlay {
                        Label("Zoom", systemImage: "plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(EditorTheme.accentSoft.opacity(0.8))
                    }
                    .frame(width: 110, height: Self.zoomHeight)
                    .offset(x: hoverX - 55, y: Self.zoomY)
                    .allowsHitTesting(false)
            }
            ForEach(editor.project.zoom) { segment in
                let start = timeline.outputTime(at: segment.start)
                let end = timeline.outputTime(at: segment.end)
                if end - start > 0.05 {
                    EditorZoomBlock(segment: segment, outputStart: start, outputEnd: end, isSelected: editor.selection == .zoom(segment.id), scale: scale)
                        .offset(x: x(start, scale), y: Self.zoomY)
                }
            }
        }
    }

    private func isOverEmptyZoomTrack(_ px: CGFloat, scale: CGFloat) -> Bool {
        let time = t(px, scale)
        let timeline = editor.timeline
        return !editor.project.zoom.contains { segment in
            time >= timeline.outputTime(at: segment.start) - 0.3 && time <= timeline.outputTime(at: segment.end) + 0.3
        }
    }

    // MARK: Pins

    /// Only the head takes the drag: the line lets clicks through to the blocks.
    private func playhead(scale: CGFloat, height: CGFloat) -> some View {
        pin(at: x(editor.currentTime, scale), color: EditorTheme.playhead, height: height, draggable: true) { location in
            editor.seek(to: t(location, scale))
        }
    }

    private func pin(at px: CGFloat, color: Color, height: CGFloat, draggable: Bool = false, drag: @escaping (CGFloat) -> Void = { _ in }) -> some View {
        ZStack(alignment: .top) {
            Rectangle().fill(color).frame(width: 1.5, height: height - Self.pinY).allowsHitTesting(false)
            EditorPinShape()
                .fill(color)
                .frame(width: 14, height: 18)
                .frame(width: 24, height: 26)
                .contentShape(.rect)
                .offset(y: -Self.pinY - 3)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline")).onChanged { value in drag(value.location.x) })
                .allowsHitTesting(draggable)
        }
        .frame(width: 24)
        .offset(x: px - 12, y: Self.pinY)
    }

    private func scissorPin(at px: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Rectangle().fill(EditorTheme.clipBottom.opacity(0.9)).frame(width: 1.5, height: Self.clipHeight + 30)
            EditorPinShape()
                .fill(EditorTheme.clipBottom)
                .frame(width: 30, height: 36)
                .overlay(alignment: .top) {
                    Image(systemName: "scissors")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.85))
                        .padding(.top, 8)
                }
                .offset(y: -18)
        }
        .offset(x: px - 15, y: Self.markerY - 4)
        .allowsHitTesting(false)
    }

    // MARK: Formatting

    /// "0:07", "0:07.4" or "0:07.42".
    static func clock(_ seconds: Double, tenths: Bool = true, hundredths: Bool = false) -> String {
        let value = max(0, seconds)
        let minutes = Int(value) / 60
        let rest = value - Double(minutes * 60)
        if hundredths { return String(format: "%d:%05.2f", minutes, rest) }
        return tenths ? String(format: "%d:%04.1f", minutes, rest) : String(format: "%d:%02d", minutes, Int(rest))
    }
}

/// A map pin: a round head tapering to a point at the bottom.
struct EditorPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        let center = CGPoint(x: rect.midX, y: rect.minY + r)
        var path = Path()
        path.addArc(center: center, radius: r, startAngle: .degrees(150), endAngle: .degrees(30), clockwise: false)
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.midX + r * 0.35, y: rect.maxY - r * 0.35))
        path.addQuadCurve(to: CGPoint(x: center.x + r * cos(.pi * 150 / 180), y: center.y + r * sin(.pi * 150 / 180)), control: CGPoint(x: rect.midX - r * 0.35, y: rect.maxY - r * 0.35))
        path.closeSubpath()
        return path
    }
}

/// One clip: amber, "Corte" over its length and speed; its ends trim it; with the
/// scissors out, a click splits it where the pin is.
struct EditorClipBlock: View {
    let clip: ClipSegment
    let width: CGFloat
    let ticks: [CGFloat]
    let isSelected: Bool
    let isDimmed: Bool
    let scale: CGFloat
    let outputStart: Double
    @Environment(EditorModel.self) private var editor
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        ZStack {
            if isDimmed {
                shape.fill(EditorTheme.clipDim)
            } else {
                shape.fill(LinearGradient(colors: [EditorTheme.clipTop, EditorTheme.clipBottom], startPoint: .top, endPoint: .bottom))
            }
            ForEach(ticks, id: \.self) { tick in
                Rectangle().fill(Color.white.opacity(0.09)).frame(width: 1).position(x: tick, y: EditorTimeline.clipHeight / 2)
            }
            label.opacity(isDimmed ? 0.55 : 1)
        }
        .frame(width: width, height: EditorTimeline.clipHeight)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(isSelected ? EditorTheme.clipStroke : Color.white.opacity(isDimmed ? 0.06 : 0.14), lineWidth: isSelected ? 1.5 : 1)
        }
        .overlay(alignment: .leading) { handle(leading: true) }
        .overlay(alignment: .trailing) { handle(leading: false) }
        .contentShape(shape)
        .onHover { isHovered = $0 }
        .onTapGesture(coordinateSpace: .named("timeline")) { point in
            if editor.isCutting {
                editor.split(at: Double((point.x - EditorTimeline.margin) / scale))
            } else {
                editor.selection = isSelected ? nil : .clip(clip.id)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isDimmed)
    }

    @ViewBuilder
    private var label: some View {
        if width > 64 {
            VStack(spacing: 1) {
                Text("Corte")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.32))
                HStack(spacing: 5) {
                    Text(verbatim: Self.length(clip.duration))
                    if width > 110 {
                        HStack(spacing: 2) {
                            Image(systemName: "gauge.with.needle").font(.system(size: 11))
                            Text(verbatim: "\(clip.speed.formatted(.number.precision(.fractionLength(0...1))))×")
                        }
                    }
                }
                .font(.system(size: 13.5, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)
            }
            .lineLimit(1)
        }
    }

    /// A white bar at each end, shown when the clip is picked or under the pointer;
    /// dragging it trims the clip.
    @ViewBuilder
    private func handle(leading: Bool) -> some View {
        if !editor.isCutting {
            Capsule()
                .fill(Color.white)
                .frame(width: 3.5, height: 24)
                .opacity(isSelected || isHovered ? 1 : 0)
                .frame(width: 14, height: EditorTimeline.clipHeight)
                .contentShape(.rect)
                .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                .gesture(DragGesture(coordinateSpace: .named("timeline")).onChanged { drag in
                    // The drag in output seconds, back to the recording's at this clip's speed.
                    let output = Double((drag.location.x - EditorTimeline.margin) / scale)
                    let source = clip.start + (output - outputStart) * clip.speed
                    editor.selection = .clip(clip.id)
                    editor.trim(clip.id, leading: leading, to: source)
                })
        }
    }

    /// "5s", "37s", "1m 12s".
    static func length(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return seconds < 10 ? "\(seconds.formatted(.number.precision(.fractionLength(0...1))))s" : "\(total)s" }
        return "\(total / 60)m \(total % 60)s"
    }
}

/// One zoom: violet, "Zoom" over how close and whether it follows the cursor. Drag the
/// middle to move it, the ends to stretch it; a click selects it.
struct EditorZoomBlock: View {
    let segment: ZoomSegment
    let outputStart: Double
    let outputEnd: Double
    let isSelected: Bool
    let scale: CGFloat
    @Environment(EditorModel.self) private var editor
    @State private var dragStart: (start: Double, end: Double)?
    @State private var isHovered = false

    var body: some View {
        let width = max(12, CGFloat(outputEnd - outputStart) * scale)
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        shape
            .fill(LinearGradient(colors: [EditorTheme.zoomTop, EditorTheme.zoomBottom], startPoint: .top, endPoint: .bottom))
            .overlay { shape.strokeBorder(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.12), lineWidth: isSelected ? 1.5 : 1) }
            .overlay {
                if width > 70 {
                    VStack(spacing: 1) {
                        Text("Zoom")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                        HStack(spacing: 6) {
                            HStack(spacing: 2) {
                                Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .medium))
                                Text(verbatim: "\(segment.scale.formatted(.number.precision(.fractionLength(0...1))))×")
                            }
                            if width > 120 {
                                HStack(spacing: 2) {
                                    Image(systemName: segment.focus == nil ? "computermouse.fill" : "scope").font(.system(size: 10.5))
                                    Text(segment.focus == nil ? "Auto" : "Fixo")
                                }
                            }
                        }
                        .font(.system(size: 13.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white)
                    }
                    .lineLimit(1)
                }
            }
            .overlay(alignment: .leading) { edge { output in editor.updateZoom(segment.id) { $0.start = editor.timeline.sourceTime(at: output) } } }
            .overlay(alignment: .trailing) { edge { output in editor.updateZoom(segment.id) { $0.end = editor.timeline.sourceTime(at: output) } } }
            .frame(width: width, height: EditorTimeline.zoomHeight)
            .contentShape(shape)
            .onHover { isHovered = $0 }
            .onTapGesture { editor.selection = isSelected ? nil : .zoom(segment.id) }
            .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .named("timeline")).onChanged { value in
                let origin = dragStart ?? (outputStart, outputEnd)
                if dragStart == nil { dragStart = origin }
                let shift = Double(value.translation.width / scale)
                let length = origin.end - origin.start
                let newStart = max(0, min(editor.duration - length, origin.start + shift))
                let timeline = editor.timeline
                editor.updateZoom(segment.id) {
                    $0.start = timeline.sourceTime(at: newStart)
                    $0.end = timeline.sourceTime(at: newStart + length)
                }
                editor.selection = .zoom(segment.id)
            }.onEnded { _ in dragStart = nil })
            .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    /// An end of the block, stretched by dragging (in output seconds).
    private func edge(_ move: @escaping (Double) -> Void) -> some View {
        Capsule()
            .fill(Color.white)
            .frame(width: 3.5, height: 22)
            .opacity(isSelected || isHovered ? 1 : 0)
            .frame(width: 14, height: EditorTimeline.zoomHeight)
            .contentShape(.rect)
            .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
            .gesture(DragGesture(coordinateSpace: .named("timeline")).onChanged { drag in
                move(max(0, min(editor.duration, Double((drag.location.x - EditorTimeline.margin) / scale))))
            })
    }
}
