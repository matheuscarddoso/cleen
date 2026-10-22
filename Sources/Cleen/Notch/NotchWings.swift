import SwiftUI

/// Live activity beside the closed notch: disk fullness on the left of the camera,
/// free space on the right. Turns into progress while Cleen is scanning or cleaning.
struct NotchWings: View {
    let notchWidth: Double
    @Environment(SystemMonitor.self) private var monitor
    @Environment(JunkModel.self) private var junk
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: NotchGeometry.wingWidth - NotchStyle.closedTopRadius, alignment: .center)
            Spacer(minLength: notchWidth)
            trailing
                .frame(width: NotchGeometry.wingWidth - NotchStyle.closedTopRadius, alignment: .center)
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cleen")
    }

    private var isBusy: Bool {
        junk.phase == .scanning || junk.isCleaning || app.isSmartScanning || app.isSmartCleaning
    }

    @ViewBuilder
    private var leading: some View {
        if isBusy {
            ProgressView()
                .controlSize(.mini)
                .tint(.white)
        } else {
            WingRing(fraction: monitor.disk?.usedFraction ?? 0)
        }
    }

    private var trailing: some View {
        Text(monitor.disk.map { Self.compact($0.available) } ?? "")
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(NotchStyle.level(monitor.disk?.usedFraction ?? 0))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .contentTransition(.numericText())
    }

    /// `7,1 GB` → `7,1G`: the wing is about 30 points wide.
    static func compact(_ bytes: Int64) -> String {
        // The formatter may separate the unit with a no-break space; \s covers both.
        bytes.bytes.replacing(/\s*([KMGT])B/, with: { $0.output.1 })
    }
}
