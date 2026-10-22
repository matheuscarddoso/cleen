import SwiftUI

/// The result of the last cleanup, in one line.
struct NotchReportLine: View {
    let report: CleanupReport

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: report.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(report.failures.isEmpty ? NotchStyle.good : NotchStyle.warning)
            Text(report.headline)
                .font(NotchStyle.bodyMedium)
            if !report.failures.isEmpty {
                Text("· \(report.failures.count) não removidos")
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
