import SwiftUI

/// One sector of the disk donut.
struct SpaceSlice: Identifiable {
    let id: String
    let name: String
    let size: Int64
    let color: Color
}
