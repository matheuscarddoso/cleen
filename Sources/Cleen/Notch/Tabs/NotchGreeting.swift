import AppKit
import SwiftUI

struct NotchGreeting: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(greeting), \(firstName)!")
                    .font(.system(size: 15, weight: .semibold))
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.cleen)).capitalizedFirst)
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
            }
            Spacer()
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: String(localized: "Bom dia")
        case 12..<18: String(localized: "Boa tarde")
        default: String(localized: "Boa noite")
        }
    }

    private var firstName: String {
        NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName()
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
