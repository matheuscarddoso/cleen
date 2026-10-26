import AppKit
import CleenKit
import SwiftUI

/// Play and the time on top; below, the take with its trim handles and, under it, the
/// zooms as blocks to select, slide or stretch. Clicking the ruler moves the playhead.
struct EditorTimeline: View {
    @Environment(EditorModel.self) private var editor

    var body: some View {
        VStack(spacing: 10) {
            transport
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        ruler(width: width)
                        clip(width: width)
                        zooms(width: width)
                    }
                    .coordinateSpace(.named("timeline"))
                    playhead(width: width, height: proxy.size.height)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(white: 0.11))
    }

    private var duration: Double { max(0.1, editor.project.duration) }

    private func x(_ t: Double, _ width: CGFloat) -> CGFloat { CGFloat(t / duration) * width }

    private func t(_ x: CGFloat, _ width: CGFloat) -> Double { max(0, min(duration, Double(x / max(1, width)) * duration)) }

    // MARK: Transport

    private var transport: some View {
        HStack(spacing: 14) {
            Button {
                editor.togglePlay()
            } label: {
                Image(systemName: editor.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.1), in: .circle)
            }
            .buttonStyle(.plain)
            .help(editor.isPlaying ? "Pausar (espaço)" : "Reproduzir (espaço)")
            Text(verbatim: "\(Self.clock(editor.currentTime - editor.project.trimStart)) / \(Self.clock(editor.project.trimmedDuration))")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Button {
                editor.addZoom()
            } label: {
                Label("Zoom", systemImage: "plus.magnifyingglass")
            }
            .buttonStyle(EditorSecondaryButtonStyle())
            .help("Adicionar um zoom no ponto atual")
        }
    }

    // MARK: Tracks

    private func ruler(width: CGFloat) -> some View {
        let step = Self.step(for: duration, width: width)
        return ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(Array(stride(from: 0, through: duration, by: step)), id: \.self) { mark in
                Text(verbatim: Self.clock(mark, tenths: false))
                    .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.4))
                    .offset(x: x(mark, width))
            }
        }
        .frame(height: 14)
        .contentShape(.rect)
        .gesture(DragGesture(minimumDistance: 0).onChanged { editor.seek(to: t($0.location.x, width)) })
    }

    private func clip(width: CGFloat) -> some View {
        let start = x(editor.project.trimStart, width), end = x(editor.project.trimEnd, width)
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.98, green: 0.62, blue: 0.24), Color(red: 0.95, green: 0.45, blue: 0.2)], startPoint: .top, endPoint: .bottom))
                .frame(width: max(8, end - start))
                .offset(x: start)
                .overlay(alignment: .leading) {
                    Text("Gravação")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.black.opacity(0.7))
                        .padding(.leading, 14)
                        .offset(x: start)
                }
            handle(at: start) { location in
                editor.edit { $0.trimStart = min(t(location, width), $0.trimEnd - 0.5) }
            }
            handle(at: end - 10) { location in
                editor.edit { $0.trimEnd = max(t(location + 10, width), $0.trimStart + 0.5) }
            }
        }
        .frame(height: 40)
    }

    private func handle(at offset: CGFloat, move: @escaping (CGFloat) -> Void) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white)
            .frame(width: 10, height: 40)
            .overlay { Capsule().fill(Color.black.opacity(0.35)).frame(width: 2, height: 14) }
            .offset(x: offset)
            .gesture(DragGesture(coordinateSpace: .named("timeline")).onChanged { move($0.location.x) })
            .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
            .help("Arraste para cortar")
    }

    private func zooms(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
            ForEach(editor.project.zoom) { segment in
                EditorZoomBlock(segment: segment, isSelected: editor.selectedZoom == segment.id, x: { x($0, width) }, t: { t($0, width) })
            }
        }
        .frame(height: 32)
    }

    private func playhead(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 2, height: height)
            .overlay(alignment: .top) {
                Circle().fill(Color.white).frame(width: 10, height: 10).offset(y: -2)
            }
            .offset(x: x(editor.currentTime, width) - 1)
            .allowsHitTesting(false)
    }

    // MARK: Formatting

    /// "0:07.4", "1:12.0".
    static func clock(_ seconds: Double, tenths: Bool = true) -> String {
        let value = max(0, seconds)
        let minutes = Int(value) / 60
        let rest = value - Double(minutes * 60)
        return tenths ? String(format: "%d:%04.1f", minutes, rest) : String(format: "%d:%02d", minutes, Int(rest))
    }

    /// A ruler mark every 1, 2, 5, 10, 15, 30 or 60 s, about one per 80 points.
    static func step(for duration: Double, width: CGFloat) -> Double {
        let wanted = duration / max(1, Double(width) / 80)
        return [1, 2, 5, 10, 15, 30, 60, 120, 300].first { $0 >= wanted } ?? 600
    }
}

/// One zoom on the timeline: drag the middle to move it, the ends to stretch it.
struct EditorZoomBlock: View {
    let segment: ZoomSegment
    let isSelected: Bool
    let x: (Double) -> CGFloat
    let t: (CGFloat) -> Double
    @Environment(EditorModel.self) private var editor
    @State private var dragStart: (start: Double, end: Double)?

    var body: some View {
        let start = x(segment.start), end = x(segment.end)
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color(red: 0.55, green: 0.42, blue: 1).opacity(isSelected ? 0.95 : 0.7))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.white.opacity(isSelected ? 0.9 : 0), lineWidth: 1.5)
            }
            .overlay(alignment: .leading) {
                Label(String(format: "%.1f×", segment.scale), systemImage: "magnifyingglass")
                    .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.white)
                    .padding(.leading, 8)
                    .lineLimit(1)
            }
            .overlay(alignment: .leading) { edge { location in editor.updateZoom(segment.id) { $0.start = t(location) } } }
            .overlay(alignment: .trailing) { edge { location in editor.updateZoom(segment.id) { $0.end = t(location) } } }
            .frame(width: max(12, end - start), height: 32)
            .offset(x: start)
            .onTapGesture { editor.selectedZoom = segment.id }
            .gesture(DragGesture(coordinateSpace: .named("timeline")).onChanged { value in
                let origin = dragStart ?? (segment.start, segment.end)
                if dragStart == nil { dragStart = origin }
                let shift = t(value.location.x) - t(value.startLocation.x)
                let length = origin.end - origin.start
                let newStart = max(0, min(editor.project.duration - length, origin.start + shift))
                editor.updateZoom(segment.id) {
                    $0.start = newStart
                    $0.end = newStart + length
                }
                editor.selectedZoom = segment.id
            }.onEnded { _ in dragStart = nil })
    }

    /// An end of the block, stretched by dragging.
    private func edge(_ move: @escaping (CGFloat) -> Void) -> some View {
        Color.white.opacity(0.001)
            .frame(width: 8)
            .contentShape(.rect)
            .gesture(DragGesture(coordinateSpace: .named("timeline")).onChanged { move($0.location.x) })
            .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
    }
}
