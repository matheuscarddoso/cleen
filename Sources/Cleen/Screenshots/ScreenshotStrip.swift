import SwiftUI

/// Earlier captures as small thumbnails, newest first.
struct ScreenshotStrip: View {
    @Environment(ScreenshotModel.self) private var model

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 6)], spacing: 6) {
                ForEach(model.items) { shot in
                    let isSelected = shot.id == model.selected?.id
                    Color.white.opacity(0.04)
                        .overlay {
                            ThumbnailImage(url: shot.url, mode: .fill)
                        }
                        .frame(height: 42)
                        .clipShape(.rect(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(isSelected ? NotchStyle.primary.opacity(0.6) : NotchStyle.cardStroke, lineWidth: isSelected ? 1.5 : 1)
                        }
                        .contentShape(.rect)
                        .onTapGesture { model.selectedID = shot.id }
                        .help(shot.url.lastPathComponent)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollEdgeFade()
    }
}
