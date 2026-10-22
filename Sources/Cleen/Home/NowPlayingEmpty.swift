import AppKit
import SwiftUI

/// Nothing is playing: say so, and offer the players that are installed.
struct NowPlayingEmpty: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nada tocando")
                .font(.system(size: 15, weight: .semibold))
            Text("Música, vídeo ou podcast tocando em qualquer app aparece aqui.")
                .font(NotchStyle.body)
                .foregroundStyle(NotchStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ForEach(NowPlayingSource.allCases, id: \.self) { source in
                    if let url = source.appURL {
                        Button {
                            NSWorkspace.shared.openApplication(at: url, configuration: .init())
                        } label: {
                            Label {
                                Text(source.displayName)
                            } icon: {
                                FileIcon(url: url, size: 14)
                            }
                        }
                        .buttonStyle(.notchSecondary)
                    }
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }
}
