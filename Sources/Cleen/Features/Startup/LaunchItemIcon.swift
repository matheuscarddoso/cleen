import CleenKit
import SwiftUI

struct LaunchItemIcon: View {
    let item: LaunchItem

    var body: some View {
        if let app = item.appBundle {
            FileIcon(url: app, size: 28)
        } else {
            SymbolBadge(
                symbol: item.signature.isSuspicious ? "exclamationmark.shield" : "gearshape",
                tint: item.signature.isSuspicious ? Theme.warning : .secondary,
                size: 28
            )
        }
    }
}
