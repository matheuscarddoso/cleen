import CleenKit
import SwiftUI

/// The Teleprompter tab, as OmniNotch's: write the script, pick a pace, and it scrolls
/// right under the camera so your eyes stay on the lens.
struct NotchTeleprompterTab: View {
    @Environment(TeleprompterModel.self) private var model
    @Environment(NotchState.self) private var notch
    /// The person is typing the script.
    @State private var isTyping = false
    /// This tab is the one keeping the panel open.
    @State private var isHolding = false

    var body: some View {
        Group {
            if model.isPresenting {
                TeleprompterPlayer()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                TeleprompterEditor(isTyping: $isTyping)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.25), value: model.isPresenting)
        .onAppear {
            // Esc stops the reading first; the next one closes the notch.
            notch.escapeHandler = { [model] in
                guard model.isPresenting else { return false }
                model.stop()
                return true
            }
            syncHold()
        }
        .onDisappear {
            notch.escapeHandler = nil
            // Leaving the tab (or the notch folding up) never leaves text running unseen.
            if case .countdown = model.phase { model.stop() } else { model.pause() }
            isTyping = false
            if isHolding {
                isHolding = false
                notch.holdsOpen = false
            }
        }
        .onChange(of: model.isPresenting) { syncHold() }
        .onChange(of: isTyping) { syncHold() }
    }

    /// Reading keeps the panel open even with the pointer elsewhere (it's on the camera,
    /// not the notch), and so does typing the script.
    private func syncHold() {
        let wants = model.isPresenting || isTyping
        guard wants != isHolding else { return }
        isHolding = wants
        notch.holdsOpen = wants
    }
}

// MARK: - Editor

/// The script on the left, as in Notas; pace, size and Começar on the right.
private struct TeleprompterEditor: View {
    @Environment(TeleprompterModel.self) private var model
    @Binding var isTyping: Bool
    @FocusState private var editorFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            editor
            controls
                .frame(width: 220)
        }
        .padding(.bottom, 2)
        // An empty script is an invitation to type; a written one waits for Começar.
        .task {
            guard model.script.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(350))
            editorFocused = true
        }
        .onChange(of: editorFocused) { _, focused in
            if !focused { isTyping = false }
        }
    }

    private var editor: some View {
        let text = Binding(get: { model.script }, set: { newValue in
            model.script = newValue
            if editorFocused { isTyping = true }
        })
        return ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .textEditorStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundStyle(NotchStyle.primary)
                .tint(NotchStyle.primary)
                .focused($editorFocused)
                .accessibilityLabel("Roteiro")
            if model.script.isEmpty {
                // TextEditor lays its text out 5 pt in (the text container's padding).
                Text("Cole ou escreva o roteiro…")
                    .font(.system(size: 13))
                    .foregroundStyle(NotchStyle.tertiary)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NotchStyle.card)
                .onTapGesture { editorFocused = true }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(editorFocused ? NotchStyle.primary.opacity(0.14) : NotchStyle.cardStroke)
                .allowsHitTesting(false)
        }
        .animation(.smooth(duration: 0.18), value: editorFocused)
        .animation(.smooth(duration: 0.12), value: model.script.isEmpty)
    }

    private var controls: some View {
        let preset = Binding<Int?>(
            get: { TeleprompterPace.presets.contains(model.wordsPerMinute) ? model.wordsPerMinute : nil },
            set: { if let value = $0 { model.wordsPerMinute = value } }
        )
        return VStack(alignment: .leading, spacing: 8) {
            NotchSegmented(
                options: [
                    (String(localized: "Lento"), Optional(TeleprompterPace.slow)),
                    (String(localized: "Normal"), Optional(TeleprompterPace.normal)),
                    (String(localized: "Rápido"), Optional(TeleprompterPace.fast)),
                ],
                selection: preset
            )
            HStack(spacing: 0) {
                TeleprompterStepper(
                    value: String(localized: "\(model.wordsPerMinute) ppm"),
                    decrease: (symbol: "tortoise", help: String(localized: "Mais devagar")),
                    increase: (symbol: "hare", help: String(localized: "Mais rápido")),
                    canDecrease: model.wordsPerMinute > TeleprompterPace.range.lowerBound,
                    canIncrease: model.wordsPerMinute < TeleprompterPace.range.upperBound,
                    step: { model.nudgePace(by: $0) }
                )
                .help("Palavras por minuto")
                Spacer(minLength: 6)
                TeleprompterStepper(
                    value: String(localized: "\(Int(model.fontSize)) pt"),
                    decrease: (symbol: "textformat.size.smaller", help: String(localized: "Texto menor")),
                    increase: (symbol: "textformat.size.larger", help: String(localized: "Texto maior")),
                    canDecrease: model.fontSize > TeleprompterPace.fontSizes.lowerBound,
                    canIncrease: model.fontSize < TeleprompterPace.fontSizes.upperBound,
                    step: { model.fontSize += Double($0) * TeleprompterPace.fontStep }
                )
                .help("Tamanho do texto")
            }
            Spacer(minLength: 0)
            summary
                .font(NotchStyle.caption)
                .foregroundStyle(NotchStyle.tertiary)
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.2), value: model.words)
            Button(action: model.start) {
                Label("Começar", systemImage: "play.fill")
                    .labelStyle(StartLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.notchPrimary)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!model.canStart)
            .help("Começar (⌘↩)")
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var summary: some View {
        let words = model.words
        let seconds = model.readingTime
        if words == 0 {
            Text("Escreva o roteiro para começar")
        } else {
            let count = words == 1 ? String(localized: "1 palavra") : String(localized: "\(words) palavras")
            let time = seconds < 60
                ? String(localized: "\(max(1, Int(seconds.rounded()))) s")
                : String(localized: "\(Int((seconds / 60).rounded())) min")
            Text("\(count) · cerca de \(time)")
        }
    }
}

/// The play glyph a touch smaller than the word, so the pill reads as text first.
private struct StartLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 10, weight: .medium))
            configuration.title
        }
    }
}

/// A value between two glyph buttons, on one grey capsule.
private struct TeleprompterStepper: View {
    let value: String
    let decrease: (symbol: String, help: String)
    let increase: (symbol: String, help: String)
    let canDecrease: Bool
    let canIncrease: Bool
    let step: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            NotchIconButton(symbol: decrease.symbol, help: decrease.help) { step(-1) }
                .disabled(!canDecrease)
                .opacity(canDecrease ? 1 : 0.35)
            Text(value)
                .font(NotchStyle.captionMedium)
                .monospacedDigit()
                .foregroundStyle(NotchStyle.primary)
                .contentTransition(.numericText())
                .frame(minWidth: 46)
                .animation(.smooth(duration: 0.18), value: value)
            NotchIconButton(symbol: increase.symbol, help: increase.help) { step(1) }
                .disabled(!canIncrease)
                .opacity(canIncrease ? 1 : 0.35)
        }
        .padding(1)
        .background(NotchStyle.card, in: .rect(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(NotchStyle.cardStroke)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Player

/// The script large and centered, gliding up so the line you're on sits just under the
/// camera. Pace on the left, transport on the right, both out of the text's way.
private struct TeleprompterPlayer: View {
    @Environment(TeleprompterModel.self) private var model
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            paceColumn
            TeleprompterScroller()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            transportColumn
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.space) {
            model.togglePause()
            return .handled
        }
        .onKeyPress(.upArrow) {
            model.nudgePace(by: 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            model.nudgePace(by: -1)
            return .handled
        }
        .onKeyPress("r") {
            model.restart()
            return .handled
        }
        // Keys work the moment the reading starts: the click on Começar already made the
        // panel key, and nothing here sets up the text system.
        .task { isFocused = true }
    }

    private var paceColumn: some View {
        VStack(spacing: 2) {
            NotchIconButton(symbol: "chevron.up", help: String(localized: "Mais rápido (↑)")) { model.nudgePace(by: 1) }
                .disabled(model.wordsPerMinute >= TeleprompterPace.range.upperBound)
            VStack(spacing: 0) {
                Text(model.wordsPerMinute, format: .number.locale(.cleen))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.18), value: model.wordsPerMinute)
                Text("ppm")
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.tertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(model.wordsPerMinute) palavras por minuto")
            NotchIconButton(symbol: "chevron.down", help: String(localized: "Mais devagar (↓)")) { model.nudgePace(by: -1) }
                .disabled(model.wordsPerMinute <= TeleprompterPace.range.lowerBound)
        }
        .frame(width: 34)
    }

    private var transportColumn: some View {
        VStack(spacing: 4) {
            NotchIconButton(symbol: playSymbol, help: playHelp, isActive: true, action: model.togglePause)
                .contentTransition(.symbolEffect(.replace))
                .disabled(isCountingDown)
                .opacity(isCountingDown ? 0.4 : 1)
            NotchIconButton(symbol: "arrow.counterclockwise", help: String(localized: "Recomeçar (R)"), action: model.restart)
            NotchIconButton(symbol: "xmark", help: String(localized: "Parar (Esc)"), action: model.stop)
        }
        .frame(width: 34)
    }

    private var isCountingDown: Bool {
        if case .countdown = model.phase { true } else { false }
    }

    private var playSymbol: String {
        model.phase == .playing ? "pause.fill" : "play.fill"
    }

    private var playHelp: String {
        switch model.phase {
        case .playing: String(localized: "Pausar (Espaço)")
        case .finished: String(localized: "Ler de novo (Espaço)")
        default: String(localized: "Continuar (Espaço)")
        }
    }
}

/// The moving text. A TimelineView asks the clock for the exact position on every
/// display frame, so the glide is continuous instead of a chain of scroll animations.
private struct TeleprompterScroller: View {
    @Environment(TeleprompterModel.self) private var model
    @State private var textHeight = 0.0

    /// Where the line being read sits: just below the top fade, as close to the
    /// camera as the text can get while staying crisp.
    private static let readingLine = 16.0
    private static let topFade = 18.0
    private static let bottomFade = 44.0

    var body: some View {
        let fontSize = model.fontSize
        // Up to where the last line reaches the reading line, then it rests there.
        let travel = max(0, textHeight - fontSize * 1.3)
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: nil, paused: !model.isRunning)) { context in
                let progress = model.progress(at: context.date)
                ScriptText(script: model.script, fontSize: fontSize)
                    .equatable()
                    .frame(width: proxy.size.width)
                    .onGeometryChange(for: Double.self) { $0.size.height } action: { textHeight = $0 }
                    .offset(y: Self.readingLine - progress * travel)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
            .opacity(textOpacity)
            .animation(.smooth(duration: 0.3), value: textOpacity)
            .mask(EdgeMask(height: proxy.size.height, top: Self.topFade, bottom: Self.bottomFade))
        }
        .clipped()
        .overlay { overlay }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Roteiro")
        .accessibilityValue(model.script)
    }

    private var textOpacity: Double {
        switch model.phase {
        case .countdown: 0.28
        case .paused, .finished: 0.6
        default: 1
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch model.phase {
        case .countdown(let value):
            Text(value, format: .number.locale(.cleen))
                .font(.system(size: 48, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.smooth(duration: 0.3), value: value)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        case .paused:
            StatusPill(text: String(localized: "Pausado · Espaço continua"))
        case .finished:
            StatusPill(text: String(localized: "Fim do roteiro · Espaço lê de novo"))
        default:
            EmptyView()
        }
    }
}

/// The script itself, laid out once: equatable, so the timeline's frames only move it.
/// One Text per paragraph keeps a long script from becoming a single huge layer.
private struct ScriptText: View, Equatable {
    let script: String
    let fontSize: Double

    var body: some View {
        let paragraphs = script.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        VStack(spacing: fontSize * 0.7) {
            ForEach(paragraphs.indices, id: \.self) { index in
                Text(verbatim: paragraphs[index])
                    .font(.system(size: fontSize, weight: .medium))
                    .lineSpacing(fontSize * 0.22)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NotchStyle.primary)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Clear at the top (the camera's side) and the bottom, opaque in between.
private struct EdgeMask: View {
    let height: Double
    let top: Double
    let bottom: Double

    var body: some View {
        let safe = max(height, 1)
        let topEnd = min(0.45, top / safe)
        let bottomStart = max(0.55, 1 - bottom / safe)
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.6), location: topEnd * 0.6),
                .init(color: .black, location: topEnd),
                .init(color: .black, location: bottomStart),
                .init(color: .black.opacity(0.35), location: bottomStart + (1 - bottomStart) * 0.5),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// A quiet note under the text while it isn't moving.
private struct StatusPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(NotchStyle.captionMedium)
            .foregroundStyle(NotchStyle.secondary)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(.black.opacity(0.85), in: .capsule)
            .overlay { Capsule().strokeBorder(NotchStyle.cardStroke) }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 4)
            .transition(.opacity)
    }
}
