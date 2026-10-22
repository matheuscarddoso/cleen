import CleenKit
import SwiftUI

struct LimitsCard: View {
    let title: String
    let symbol: String
    let badge: String?
    let windows: [UsageWindow]

    var body: some View {
        AIUsageCard(title: title, symbol: symbol, badge: badge) {
            ForEach(windows.prefix(3)) { window in
                LimitRow(window: window)
            }
        }
    }
}
