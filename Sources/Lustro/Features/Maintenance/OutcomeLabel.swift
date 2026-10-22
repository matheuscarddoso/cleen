import SwiftUI

struct OutcomeLabel: View {
    let outcome: MaintenanceModel.Outcome

    var body: some View {
        switch outcome {
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(Theme.caption)
                .foregroundStyle(Theme.good)
                .lineLimit(2)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(Theme.caption)
                .foregroundStyle(Theme.warning)
                .lineLimit(2)
        }
    }
}
