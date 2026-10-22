import SwiftUI

@Animatable
struct PaceTickShape: Shape {
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        let x = rect.minX + rect.width * min(1, max(0, fraction))
        return Path(roundedRect: CGRect(x: x - 0.75, y: rect.minY, width: 1.5, height: rect.height), cornerRadius: 0.75)
    }
}
