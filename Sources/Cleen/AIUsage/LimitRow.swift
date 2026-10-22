import CleenKit
import SwiftUI

/// "Sessão · 42% usado", a bar with a tick where an even pace would be, and when it
/// resets / where the current pace lands.
struct LimitRow: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(window.name)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("\(window.used.percent) usado")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
            ZStack {
                UsageBar(fraction: window.used, height: 4, tint: tint)
                if let pace = window.elapsed() {
                    PaceTick(fraction: pace)
                }
            }
            Text(caption)
                .font(.system(size: 9.5))
                .foregroundStyle(NotchStyle.tertiary)
                .lineLimit(1)
        }
    }

    private var tint: Color {
        if let projected = window.projected(), projected > 1 { return NotchStyle.critical }
        return NotchStyle.level(window.used)
    }

    private var caption: String {
        var parts: [String] = []
        if let reset = window.resetsAt {
            parts.append("Reinicia em \(Self.countdown(to: reset))")
        }
        if let projected = window.projected() {
            parts.append(projected > 1 ? "acaba antes" : "ritmo \(min(projected, 1).percent)")
        }
        return parts.joined(separator: " · ")
    }

    /// `57 min`, `3h 20min`, `2 dias`: short enough for one line.
    static func countdown(to date: Date) -> String {
        let seconds = max(0, date.timeIntervalSinceNow)
        if seconds >= 86_400 {
            let days = Int((seconds / 86_400).rounded())
            return days == 1 ? "1 dia" : "\(days) dias"
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(max(1, minutes)) min" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)min"
    }
}
