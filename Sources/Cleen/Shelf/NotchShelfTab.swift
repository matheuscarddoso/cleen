import SwiftUI

/// The shelf: AirDrop on the left, a hairline, the drop zone (then the parked files)
/// on the right. Drag files onto the closed notch and it opens here.
struct NotchShelfTab: View {
    @Environment(ShelfModel.self) private var shelf

    var body: some View {
        HStack(spacing: 20) {
            AirDropTile()
                .frame(width: 180)
            Rectangle()
                .fill(NotchStyle.separator)
                .frame(width: 1)
                .padding(.vertical, 14)
            ShelfDropZone()
        }
        .padding(.bottom, 4)
        .onAppear(perform: shelf.prune)
    }
}
