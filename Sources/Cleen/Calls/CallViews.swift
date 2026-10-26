import SwiftUI

/// The closed notch during a call, Droppy's way: a green phone and the time on the left
/// of the camera, the voice as bars (green to orange) on the right.
struct CallWings: View {
    let call: CallMonitor.Call
    let levels: [Double]
    let isMuted: Bool
    let notchWidth: Double
    let inset: Double

    static let green = Color(red: 0.3, green: 0.85, blue: 0.45)

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 12, weight: .semibold))
                TimelineView(.periodic(from: call.since, by: 1)) { context in
                    Text(verbatim: CallClock.text(context.date.timeIntervalSince(call.since)))
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .lineLimit(1)
                        .fixedSize()
                        .contentTransition(.numericText())
                }
            }
            .foregroundStyle(Self.green)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, inset + 2)
            Spacer(minLength: notchWidth)
            CallLevelBars(levels: levels, isMuted: isMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, inset + 2)
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Em chamada no \(call.app.name)"))
    }
}

/// The voice, bar by bar: green when soft, warming to orange as it gets louder.
struct CallLevelBars: View {
    let levels: [Double]
    let isMuted: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(levels.indices, id: \.self) { index in
                let level = levels[index]
                Capsule()
                    .fill(isMuted ? Color.white.opacity(0.25) : color(level))
                    .frame(width: 2.6, height: 3 + 11 * level)
            }
        }
        .frame(height: 15)
        .animation(.smooth(duration: 0.12), value: levels)
    }

    private func color(_ level: Double) -> Color {
        let t = min(1, max(0, level))
        return Color(red: 0.3 + 0.68 * t, green: 0.85 - 0.25 * t, blue: 0.45 - 0.25 * t)
    }
}

/// The open notch during a call: the microphone, the camera, the screen share and
/// hanging up, in reach. Red is off.
struct CallControls: View {
    @Environment(CallMonitor.self) private var calls
    @Environment(NotchState.self) private var notch

    var body: some View {
        if let call = calls.call {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill").foregroundStyle(CallWings.green)
                    Text(call.app.name).foregroundStyle(NotchStyle.primary)
                    TimelineView(.periodic(from: call.since, by: 1)) { context in
                        Text(verbatim: CallClock.text(context.date.timeIntervalSince(call.since)))
                            .monospacedDigit()
                            .foregroundStyle(NotchStyle.secondary)
                    }
                    Spacer()
                    Button("Mostrar") { calls.showApp() }
                        .buttonStyle(.plain)
                        .foregroundStyle(NotchStyle.secondary)
                    Button {
                        withAnimation(NotchController.searchResize) { notch.showsCall = false }
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(NotchStyle.secondary)
                    .help("Ver as abas")
                    .padding(.leading, 8)
                }
                .font(.system(size: 12, weight: .medium))
                HStack(spacing: 18) {
                    control(symbol: calls.isMicMuted ? "mic.slash.fill" : "mic.fill", isOff: calls.isMicMuted, enabled: MicrophoneMute.canMute || call.app.shortcuts.microphone != nil, help: calls.isMicMuted ? "Ligar o microfone" : "Silenciar o microfone") {
                        calls.toggleMicrophone()
                    }
                    control(symbol: calls.isCameraOff ? "video.slash.fill" : "video.fill", isOff: calls.isCameraOff, enabled: call.app.shortcuts.camera != nil, help: "Câmera") {
                        calls.toggleCamera()
                    }
                    control(symbol: calls.isSharingOff ? "rectangle.on.rectangle.slash.fill" : "rectangle.on.rectangle", isOff: calls.isSharingOff, enabled: call.app.shortcuts.share != nil, help: "Compartilhar a tela") {
                        calls.toggleSharing()
                    }
                    Button { calls.hangUp() } label: {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 54)
                            .background(Color(red: 0.92, green: 0.24, blue: 0.24), in: .circle)
                    }
                    .buttonStyle(CallButtonStyle())
                    .help("Desligar")
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func control(symbol: String, isOff: Bool, enabled: Bool, help: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(isOff ? Color(red: 1, green: 0.36, blue: 0.36) : NotchStyle.primary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 54, height: 54)
                .background(isOff ? Color(red: 0.55, green: 0.1, blue: 0.1).opacity(0.55) : NotchStyle.control, in: .circle)
                .overlay { Circle().strokeBorder(Color.white.opacity(0.08)) }
        }
        .buttonStyle(CallButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .help(enabled ? help : "Este app não tem atalho para isso")
        .animation(.smooth(duration: 0.2), value: isOff)
    }
}

private struct CallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// "0:06", "12:40", "1:02:15".
enum CallClock {
    static func text(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600, minutes = (total % 3600) / 60, rest = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
    }
}
