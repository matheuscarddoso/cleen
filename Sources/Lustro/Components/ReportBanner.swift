import LustroKit
import SwiftUI

/// The result of the last cleanup, with the failures one click away.
struct ReportBanner: View {
    let report: CleanupReport
    /// Offered when some failures need an administrator password.
    var retryAsAdministrator: (() -> Void)?

    @State private var showsFailures = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: report.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(report.failures.isEmpty ? Theme.good : Theme.warning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(report.headline)
                    .font(Theme.bodyMedium)
                if !report.failures.isEmpty {
                    Text(report.failures.count == 1 ? "1 item não pôde ser removido" : "\(report.failures.count) itens não puderam ser removidos")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            if !report.failures.isEmpty {
                Button("Ver detalhes", action: showFailures)
                    .buttonStyle(.quiet)
            }
            if let retryAsAdministrator, !report.permissionFailures.isEmpty {
                Button("Tentar com senha", action: retryAsAdministrator)
                    .buttonStyle(.quiet)
            }
        }
        .surface(radius: Theme.Radius.medium, padding: 12)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .sheet(isPresented: $showsFailures) {
            FailuresSheet(failures: report.failures)
        }
    }

    private func showFailures() {
        showsFailures = true
    }
}
