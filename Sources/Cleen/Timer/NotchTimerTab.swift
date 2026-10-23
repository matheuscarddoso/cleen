import CleenKit
import SwiftUI

/// The Timer tab: the countdown big on the left inside its ring, the mode, lengths and
/// controls on the right. Space starts and pauses.
struct NotchTimerTab: View {
    @Environment(TimerModel.self) private var model
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 20) {
            TimerTicks { now in
                TimerClockFace(now: now)
            }
            .layoutPriority(1)
            Rectangle()
                .fill(NotchStyle.separator)
                .frame(width: 1)
                .padding(.vertical, 6)
            controls
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.space) {
            model.toggle()
            return .handled
        }
        // Same settling delay as the clipboard's search field: taking focus on the
        // switch's own frame stalled it.
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            isFocused = true
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                NotchSegmented(
                    options: [("Timer", TimerMode.countdown), ("Pomodoro", TimerMode.pomodoro)],
                    selection: Binding(get: { model.mode }, set: { model.setMode($0) })
                )
                .disabled(model.isActive)
                .opacity(model.isActive ? 0.4 : 1)
                .help(model.isActive ? "Zere o timer para trocar de modo" : "Timer simples ou Pomodoro")
                Spacer(minLength: 0)
                if model.mode == .countdown {
                    wheel
                        .transition(.opacity)
                }
            }
            Group {
                if model.mode == .countdown {
                    lengths
                } else {
                    pomodoroPlan
                }
            }
            .frame(height: 26)
            .transition(.opacity)
            buttons
        }
        .animation(.smooth(duration: 0.2), value: model.mode)
        .animation(.smooth(duration: 0.2), value: model.isActive)
    }

    /// Any length in minutes; white in the middle when it isn't one of the presets.
    private var wheel: some View {
        @Bindable var model = model
        return HStack(spacing: 5) {
            DurationWheel(
                minutes: $model.countdownMinutes,
                range: TimerModel.minuteRange,
                isHighlighted: !TimerModel.presets.contains(model.countdownMinutes)
            )
            Text("min")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchStyle.tertiary)
        }
        .disabled(model.isActive)
    }

    private var lengths: some View {
        HStack(spacing: 2) {
            ForEach(TimerModel.presets, id: \.self) { minutes in
                TimerChip(title: "\(minutes)", isSelected: model.countdownMinutes == minutes) {
                    model.countdownMinutes = minutes
                }
                .help("\(minutes) minutos")
            }
        }
        .disabled(model.isActive)
    }

    /// The rhythm, with the phase under way lifted, and the rounds of the cycle.
    private var pomodoroPlan: some View {
        HStack(spacing: 2) {
            step("Foco", length: model.plan.focus, isCurrent: model.phase == .focus)
            step("Pausa", length: model.plan.shortBreak, isCurrent: model.phase == .shortBreak)
            step("Longa", length: model.plan.longBreak, isCurrent: model.phase == .longBreak)
            TimerTicks { now in
                TimerRounds(
                    rounds: model.rounds,
                    current: model.round,
                    progress: model.phase == .focus ? model.progress(at: now) : 1
                )
            }
            .padding(.leading, 10)
        }
    }

    private func step(_ title: String, length: TimeInterval, isCurrent: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text("\(Int(length / 60))")
                .monospacedDigit()
                .foregroundStyle(isCurrent ? NotchStyle.secondary : NotchStyle.tertiary)
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(isCurrent ? NotchStyle.primary : NotchStyle.secondary)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(isCurrent ? NotchStyle.selection : .clear, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var buttons: some View {
        HStack(spacing: 6) {
            Button(action: model.toggle) {
                Label(primaryTitle, systemImage: model.isRunning ? "pause.fill" : "play.fill")
                    .frame(minWidth: 72)
            }
            .buttonStyle(.notchPrimary)
            .help("\(primaryTitle) (espaço)")
            Button("Zerar", action: model.reset)
                .buttonStyle(.notchSecondary)
                .disabled(!model.canReset)
            Button("+1 min", action: model.addMinute)
                .buttonStyle(.notchSecondary)
                .disabled(model.mode == .pomodoro && !model.isActive)
                .help("Mais um minuto")
            if model.mode == .pomodoro {
                Button("Pular", action: model.skip)
                    .buttonStyle(.notchSecondary)
                    .help(model.phase.isBreak ? "Pular a pausa" : "Pular para a pausa")
                    .transition(.opacity)
            }
        }
        .labelStyle(.titleAndIcon)
    }

    private var primaryTitle: String {
        if model.isRunning { return "Pausar" }
        return model.isPaused ? "Continuar" : "Iniciar"
    }
}

/// The left half: the ring with the phase glyph (a play/pause button on hover), and
/// the countdown beside it.
private struct TimerClockFace: View {
    let now: Date
    @Environment(TimerModel.self) private var model
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 18) {
            Button(action: model.toggle) {
                TimerRing(remaining: 1 - model.progress(at: now), color: model.phase.tint, lineWidth: 5, isRunning: model.isRunning) {
                    Image(systemName: centerSymbol)
                        .font(.system(size: isHovered ? 22 : 20, weight: .light))
                        .foregroundStyle(isHovered ? NotchStyle.primary : model.phase.tint.opacity(0.8))
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 100, height: 100)
                .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .onHover { hovering in withAnimation(.smooth(duration: 0.18)) { isHovered = hovering } }
            .accessibilityLabel(model.isRunning ? "Pausar" : "Iniciar")

            VStack(alignment: .leading, spacing: 2) {
                Text(model.phaseDetail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
                Text(TimerClock.string(model.remaining(at: now)))
                    .font(.system(size: 44, weight: .light).monospacedDigit())
                    .foregroundStyle(model.isPaused ? NotchStyle.secondary : NotchStyle.primary)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.smooth(duration: 0.3), value: TimerClock.string(model.remaining(at: now)))
                    .padding(.leading, -2)
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(NotchStyle.tertiary)
            }
            .lineLimit(1)
            .fixedSize()
            .accessibilityElement(children: .combine)
        }
    }

    private var centerSymbol: String {
        if isHovered { return model.isRunning ? "pause.fill" : "play.fill" }
        return model.phase.symbol
    }

    private var status: String {
        if let end = model.endDate {
            return "termina às \(end.formatted(.dateTime.hour().minute().locale(.cleen)))"
        }
        return model.isPaused ? "pausado" : "pronto para começar"
    }
}
