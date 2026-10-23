import AppKit
import CleenKit
import SwiftUI

/// One item inside an opened row: indented under the parent's checkbox, with its own
/// check, path and size. Click anywhere to toggle it.
struct NotchChildRow: View {
    let title: String
    let path: URL
    let size: Int64
    let isOn: Bool
    var note: String?
    let toggle: () -> Void

    var body: some View {
        NotchRow(title: title, subtitle: note ?? Paths.abbreviate(path), verticalPadding: 3, action: toggle) {
            NotchCheckbox(state: isOn ? .on : .off, label: title, action: toggle)
        } trailing: {
            Text(size.bytes)
                .font(NotchStyle.captionMedium.monospacedDigit())
                .foregroundStyle(NotchStyle.tertiary)
            NotchIconButton(symbol: "magnifyingglass", help: "Mostrar no Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([path])
            }
        }
        .padding(.leading, 25)
    }
}
