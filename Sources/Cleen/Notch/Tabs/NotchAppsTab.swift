import CleenKit
import SwiftUI

/// Apps on the left, largest first; the picked app's real footprint on the right.
struct NotchAppsTab: View {
    @Environment(AppsModel.self) private var model

    var body: some View {
        if model.phase != .ready {
            NotchScanning(title: String(localized: "Medindo os apps"), detail: String(localized: "Cada app em /Applications, com caches e dados"))
                .task { if model.phase == .idle { await model.load() } }
        } else {
            HStack(alignment: .top, spacing: 14) {
                AppPickerList()
                    .frame(width: 270)
                Rectangle()
                    .fill(NotchStyle.separator)
                    .frame(width: 1)
                AppUninstallPane()
            }
        }
    }
}
