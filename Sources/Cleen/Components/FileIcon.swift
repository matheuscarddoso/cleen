import SwiftUI

/// The Finder icon for a file, folder or app.
struct FileIcon: View {
    let url: URL
    var size = 28.0

    var body: some View {
        Image(nsImage: IconCache.shared.icon(for: url))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
