import CleenKit
import SwiftUI

/// The Claude (or Codex) limits that matter now: the session window, and the week next
/// to it when there's room. A tap opens Uso de IA.
struct AIUsageWidget: View {
    let size: HomeWidgetSize
    @Environment(AIUsageModel.self) private var model
    @Environment(NotchState.self) private var state

    var body: some View {
        Button { state.tab = .ai } label: {
            switch size {
            case .small:
                let session = windows.first
                HomeRing(fraction: session?.used ?? 0, color: session.map(NotchAIUsageTab.color(for:)) ?? NotchStyle.barFill) {
                    VStack(spacing: -1) {
                        Text(session?.used.percent ?? "—")
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .contentTransition(.numericText())
                        Text(session == nil ? String(localized: "IA") : String(localized: "sessão"))
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(NotchStyle.secondary)
                    }
                }
                .frame(width: 80, height: 80)
            case .medium, .large:
                VStack(alignment: .leading, spacing: 7) {
                    HomeWidgetLabel(title: model.claude?.plan.map { "Claude \($0)" } ?? String(localized: "Uso de IA"), symbol: "chart.bar.xaxis")
                    if windows.isEmpty {
                        Text(model.summary.map { $0.monthCost.dollars } ?? "—")
                            .font(.system(size: 17, weight: .semibold).monospacedDigit())
                        Text("gasto no mês")
                            .font(.system(size: 11))
                            .foregroundStyle(NotchStyle.secondary)
                    } else {
                        ForEach(windows.prefix(2)) { window in
                            meter(window)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .help("Abrir Uso de IA")
        .task { await model.watch() }
    }

    /// Claude's windows when signed in, otherwise Codex's, otherwise the first other tool's.
    private var windows: [UsageWindow] {
        if let claude = model.claude?.windows, !claude.isEmpty { return claude }
        if let codex = model.codex, !codex.isEmpty { return codex }
        return model.providers.lazy.map(model.providerWindows(of:)).first { !$0.isEmpty } ?? []
    }

    private func meter(_ window: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(window.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchStyle.primary.opacity(0.85))
                Spacer()
                Text(window.used.percent)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(NotchAIUsageTab.color(for: window))
                    .contentTransition(.numericText())
            }
            UsageBar(fraction: window.used, tint: NotchAIUsageTab.color(for: window) == NotchStyle.primary ? nil : NotchAIUsageTab.color(for: window))
            if let reset = window.resetsAt {
                Text("renova em \(NotchAIUsageTab.countdown(to: reset))")
                    .font(.system(size: 9.5))
                    .foregroundStyle(NotchStyle.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
