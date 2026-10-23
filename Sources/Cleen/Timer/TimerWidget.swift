import CleenKit
import SwiftUI

/// The timer on Início. Small: the ring with the clock inside; a tap starts or pauses,
/// or opens the tab while nothing is going. Medium: the ring as a play/pause button,
/// the phase and the time left beside it (a tap there opens the tab).
struct TimerWidget: View {
    let size: HomeWidgetSize
    @Environment(TimerModel.self) private var model
    @Environment(NotchState.self) private var state

    var body: some View {
        TimerTicks { now in
            switch size {
            case .small: small(now: now)
            case .medium, .large: medium(now: now)
            }
        }
    }

    private func small(now: Date) -> some View {
        Button {
            if model.isActive { model.toggle() } else { state.tab = .timer }
        } label: {
            ring(now: now, lineWidth: 6) {
                VStack(spacing: -1) {
                    clock(now: now, size: 15)
                    Text(model.isPaused ? "pausado" : model.phaseTitle.lowercased())
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(NotchStyle.secondary)
                }
            }
            .frame(width: 80, height: 80)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(model.isActive ? (model.isRunning ? "Pausar" : "Continuar") : "Abrir o Timer")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.phaseTitle)
        .accessibilityValue(TimerClock.string(model.remaining(at: now)))
        .accessibilityAddTraits(.isButton)
    }

    private func medium(now: Date) -> some View {
        HStack(spacing: 12) {
            TimerPlayButton(now: now)
                .frame(width: 72, height: 72)
            Button { state.tab = .timer } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HomeWidgetLabel(title: model.mode == .pomodoro ? "\(model.phaseTitle) · \(model.round)/\(model.rounds)" : "Timer", symbol: model.phase.symbol)
                    clock(now: now, size: 17)
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundStyle(NotchStyle.secondary)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Abrir o Timer")
        }
    }

    private var status: String {
        if let end = model.endDate { return "até \(end.formatted(.dateTime.hour().minute().locale(.cleen)))" }
        return model.isPaused ? "pausado" : "pronto"
    }

    private func clock(now: Date, size: Double) -> some View {
        let text = TimerClock.string(model.remaining(at: now))
        return Text(text)
            .font(.system(size: size, weight: .semibold).monospacedDigit())
            .foregroundStyle(model.isPaused ? NotchStyle.secondary : NotchStyle.primary)
            .contentTransition(.numericText(countsDown: true))
            .animation(.smooth(duration: 0.3), value: text)
    }

    private func ring(now: Date, lineWidth: Double, @ViewBuilder center: () -> some View) -> some View {
        TimerRing(remaining: 1 - model.progress(at: now), color: model.phase.tint, lineWidth: lineWidth, isRunning: model.isRunning, center: center)
    }
}

/// The medium widget's ring: play or pause in the middle, brighter on hover.
private struct TimerPlayButton: View {
    let now: Date
    @Environment(TimerModel.self) private var model
    @State private var isHovered = false

    var body: some View {
        Button(action: model.toggle) {
            TimerRing(remaining: 1 - model.progress(at: now), color: model.phase.tint, lineWidth: 6, isRunning: model.isRunning) {
                Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isHovered ? NotchStyle.primary : NotchStyle.primary.opacity(0.8))
                    // The triangle's visual centre sits right of its frame's.
                    .offset(x: model.isRunning ? 0 : 1.5)
                    .scaleEffect(isHovered ? 1.08 : 1)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .onHover { hovering in withAnimation(.smooth(duration: 0.18)) { isHovered = hovering } }
        .help(model.isRunning ? "Pausar" : (model.isPaused ? "Continuar" : "Iniciar"))
        .accessibilityLabel(model.isRunning ? "Pausar" : (model.isPaused ? "Continuar" : "Iniciar"))
    }
}
