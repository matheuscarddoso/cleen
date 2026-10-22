import SwiftUI
import UniformTypeIdentifiers

/// The shelf, as in OmniNotch: an AirDrop tile on the left, a drop zone (then the
/// parked files) on the right. Drag files onto the closed notch and it opens here.
struct NotchShelfTab: View {
    @Environment(ShelfModel.self) private var shelf

    var body: some View {
        HStack(spacing: 10) {
            AirDropTile()
                .frame(width: 200)
            ShelfDropZone()
        }
        .padding(.bottom, 4)
        .onAppear(perform: shelf.prune)
    }
}
