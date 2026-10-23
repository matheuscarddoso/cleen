import AppKit
import SwiftUI

/// The latest screenshot with what you'd do next: copy, share, AirDrop, delete. Earlier
/// captures sit on the right.
struct NotchScreenshotsTab: View {
    @Environment(ScreenshotModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.nativeThumbnailOn {
                ThumbnailHint()
            }
            content
        }
        .onAppear(perform: model.refreshNativeThumbnail)
    }

    @ViewBuilder
    private var content: some View {
        if let shot = model.selected {
            HStack(alignment: .top, spacing: 16) {
                ScreenshotPreview(shot: shot)
                    .frame(width: 210)
                ScreenshotActions(shot: shot)
                    .frame(width: 250)
                Rectangle()
                    .fill(NotchStyle.separator)
                    .frame(width: 1)
                ScreenshotStrip()
            }
            .padding(.bottom, 4)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20))
                    .foregroundStyle(NotchStyle.tertiary)
                Text("Nenhum screenshot nos últimos 7 dias")
                    .font(.system(size: 12.5, weight: .medium))
                Text("Tire um com ⌘⇧3, ⌘⇧4 ou ⌘⇧5 e ele abre aqui.")
                    .font(.system(size: 11))
                    .foregroundStyle(NotchStyle.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
