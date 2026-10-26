import CleenKit
import SwiftUI

/// The middle: the canvas shape, Crop and the preview's quality over the styled preview,
/// or the crop editor over the raw frame while cropping.
struct EditorStage: View {
    @Environment(EditorModel.self) private var editor
    @State private var crop = CGRect(x: 0, y: 0, width: 1, height: 1)

    var body: some View {
        VStack(spacing: 14) {
            if editor.cropFrame != nil {
                cropBar
            } else {
                controls
            }
            ZStack {
                if let frame = editor.cropFrame {
                    EditorCropView(image: frame, crop: $crop)
                } else {
                    EditorPreview(player: editor.player)
                        .aspectRatio(canvasAspect, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 6, style: .continuous))
                        .onTapGesture { editor.togglePlay() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 10)
    }

    private var canvasAspect: CGFloat {
        let canvas = editor.canvasSize(longSide: 1280)
        return canvas.width / max(1, canvas.height)
    }

    private var controls: some View {
        HStack(spacing: 6) {
            Menu {
                Picker("Formato", selection: Binding(get: { editor.style.aspect }, set: { value in editor.edit { $0.style.aspect = value } })) {
                    Text("Automático").tag(EditorStyle.Aspect.source)
                    ForEach([EditorStyle.Aspect.wide, .vertical, .square, .classic], id: \.self) { aspect in
                        Text(verbatim: aspect.rawValue).tag(aspect)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                barLabel(editor.style.aspect == .source ? String(localized: "Automático") : editor.style.aspect.rawValue, symbol: "aspectratio", chevron: true)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("O formato do vídeo")
            Button {
                crop = editor.project.crop ?? CGRect(x: 0, y: 0, width: 1, height: 1)
                editor.beginCrop()
            } label: {
                barLabel(String(localized: "Recortar"), symbol: "crop", chevron: false)
            }
            .buttonStyle(.plain)
            .help("Mostrar só uma parte da gravação")
            Spacer()
            Menu {
                Picker("Qualidade da prévia", selection: Binding(get: { editor.previewQuality }, set: { editor.setPreviewQuality($0) })) {
                    Text("Máxima").tag(EditorModel.PreviewQuality.full)
                    Text("Metade").tag(EditorModel.PreviewQuality.half)
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "dial.medium")
                    Text("Qualidade da prévia")
                    Text(editor.previewQuality == .full ? "Máxima" : "Metade").foregroundStyle(EditorTheme.tertiary)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .medium)).foregroundStyle(EditorTheme.secondary)
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 10)
                .frame(height: 32)
                .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .frame(height: 32)
    }

    private var cropBar: some View {
        HStack(spacing: 8) {
            Text("Arraste os cantos para escolher o que aparece")
                .font(EditorTheme.body)
                .foregroundStyle(EditorTheme.secondary)
            Spacer()
            Button("Tudo") { crop = CGRect(x: 0, y: 0, width: 1, height: 1) }
                .buttonStyle(EditorSecondaryButtonStyle())
                .fixedSize()
            Button("Cancelar") { editor.endCrop(nil) }
                .buttonStyle(EditorSecondaryButtonStyle())
                .fixedSize()
                .keyboardShortcut(.cancelAction)
            Button("Pronto") { editor.endCrop(crop) }
                .buttonStyle(EditorPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .frame(height: 32)
    }

    private func barLabel(_ title: String, symbol: String, chevron: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(title)
            if chevron {
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .medium)).foregroundStyle(EditorTheme.secondary)
            }
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, 10)
        .frame(height: 32)
        .contentShape(.rect)
    }
}

/// The raw frame with the crop over it: dimmed outside, a frame with handles at the
/// corners and edges, and the middle to slide it. Works in 0…1 of the frame.
struct EditorCropView: View {
    let image: CGImage
    @Binding var crop: CGRect
    @State private var dragStart: CGRect?

    var body: some View {
        GeometryReader { proxy in
            let fit = fitted(in: proxy.size)
            let rect = CGRect(x: fit.minX + crop.minX * fit.width, y: fit.minY + crop.minY * fit.height, width: crop.width * fit.width, height: crop.height * fit.height)
            ZStack(alignment: .topLeading) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .frame(width: fit.width, height: fit.height)
                    .offset(x: fit.minX, y: fit.minY)
                // Outside the crop, dimmed.
                Path { path in
                    path.addRect(fit)
                    path.addRect(rect)
                }
                .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 1.5)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .contentShape(.rect)
                    .gesture(drag(fit: fit) { start, dx, dy in
                        CGRect(x: min(1 - start.width, max(0, start.minX + dx)), y: min(1 - start.height, max(0, start.minY + dy)), width: start.width, height: start.height)
                    })
                ForEach(Handle.allCases, id: \.self) { handle in
                    let point = handle.point(in: rect)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white)
                        .frame(width: handle.isCorner ? 14 : 10, height: handle.isCorner ? 14 : 10)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                        .position(point)
                        .gesture(drag(fit: fit) { start, dx, dy in handle.resize(start, dx: dx, dy: dy) })
                }
            }
        }
    }

    private func fitted(in size: CGSize) -> CGRect {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let scale = min(size.width / w, size.height / h)
        let fit = CGSize(width: w * scale, height: h * scale)
        return CGRect(x: (size.width - fit.width) / 2, y: (size.height - fit.height) / 2, width: fit.width, height: fit.height)
    }

    private func drag(fit: CGRect, change: @escaping (CGRect, CGFloat, CGFloat) -> CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? crop
                if dragStart == nil { dragStart = start }
                crop = change(start, value.translation.width / max(1, fit.width), value.translation.height / max(1, fit.height))
            }
            .onEnded { _ in dragStart = nil }
    }

    enum Handle: CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

        var isCorner: Bool { [.topLeft, .topRight, .bottomRight, .bottomLeft].contains(self) }

        func point(in rect: CGRect) -> CGPoint {
            switch self {
            case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
            case .top: CGPoint(x: rect.midX, y: rect.minY)
            case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
            case .right: CGPoint(x: rect.maxX, y: rect.midY)
            case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            case .bottom: CGPoint(x: rect.midX, y: rect.maxY)
            case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
            case .left: CGPoint(x: rect.minX, y: rect.midY)
            }
        }

        /// The crop with this handle moved, never smaller than a tenth of the frame.
        func resize(_ start: CGRect, dx: CGFloat, dy: CGFloat) -> CGRect {
            let minimum: CGFloat = 0.1
            var minX = start.minX, minY = start.minY, maxX = start.maxX, maxY = start.maxY
            if [.topLeft, .left, .bottomLeft].contains(self) { minX = min(maxX - minimum, max(0, minX + dx)) }
            if [.topRight, .right, .bottomRight].contains(self) { maxX = max(minX + minimum, min(1, maxX + dx)) }
            if [.topLeft, .top, .topRight].contains(self) { minY = min(maxY - minimum, max(0, minY + dy)) }
            if [.bottomLeft, .bottom, .bottomRight].contains(self) { maxY = max(minY + minimum, min(1, maxY + dy)) }
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }
}
