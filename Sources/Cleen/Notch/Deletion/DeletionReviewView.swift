import AppKit
import CleenKit
import SwiftUI

/// The step before anything is deleted: what goes (largest first), how much, where it
/// ends up, and Cancelar (Esc) beside Confirmar (Return). Shown over the tool, which
/// stays as it was underneath, so cancelling lands right back where you were.
struct DeletionReviewView: View {
    let review: DeletionReview
    @Environment(NotchState.self) private var state

    /// A long list shows its heaviest rows and counts the rest.
    private static let shownRows = 200

    var body: some View {
        let items = review.items.sorted { ($0.size ?? 0) > ($1.size ?? 0) }
        VStack(alignment: .leading, spacing: 10) {
            header
            NotchScroll {
                LazyVStack(spacing: 0) {
                    ForEach(items.prefix(Self.shownRows)) { item in
                        DeletionReviewRow(item: item)
                        if item.id != items.prefix(Self.shownRows).last?.id {
                            Rectangle().fill(NotchStyle.separator).frame(height: 1).padding(.leading, 38)
                        }
                    }
                    if items.count > Self.shownRows {
                        Text("e mais \(items.count - Self.shownRows) itens menores")
                            .font(NotchStyle.caption)
                            .foregroundStyle(NotchStyle.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                }
                .background(NotchStyle.card, in: .rect(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(NotchStyle.cardStroke) }
            }
            buttons
        }
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(review.title)
                    .font(NotchStyle.title)
                Text(review.consequence)
                    .font(NotchStyle.caption)
                    .foregroundStyle(review.outcome == .trash ? NotchStyle.secondary : NotchStyle.warning)
            }
            Spacer(minLength: 8)
            if let total = review.totalSize, total > 0 {
                Text(total.bytes)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
            }
        }
        .padding(.horizontal, 2)
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Spacer()
            Button("Cancelar") { state.cancelDeletion() }
                .buttonStyle(.notchSecondary)
                .keyboardShortcut(.cancelAction)
            Button("Confirmar") { state.confirmDeletion() }
                .buttonStyle(.notchDestructive)
                .keyboardShortcut(.defaultAction)
        }
    }
}

private struct DeletionReviewRow: View {
    let item: DeletionReview.Item

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(NotchStyle.bodyMedium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let detail = item.detail {
                    Text(detail)
                        .font(NotchStyle.caption)
                        .foregroundStyle(NotchStyle.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            if let size = item.size {
                Text(size.bytes)
                    .font(NotchStyle.captionMedium.monospacedDigit())
                    .foregroundStyle(NotchStyle.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 36)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        if let url = item.url {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: item.symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
        }
    }
}
