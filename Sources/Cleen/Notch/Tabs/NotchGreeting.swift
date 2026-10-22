import AppKit
import SwiftUI

struct NotchGreeting: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(greeting), \(firstName)!")
                    .font(.system(size: 15, weight: .semibold))
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.cleen)).capitalizedFirst)
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
            }
            Spacer()
            NotchStatusPill()
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Bom dia"
        case 12..<18: "Boa tarde"
        default: "Boa noite"
        }
    }

    private var firstName: String {
        NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName()
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
