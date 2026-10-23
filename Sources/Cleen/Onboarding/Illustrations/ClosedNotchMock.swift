import SwiftUI

/// The closed notch at its real size, with its wings: the disk ring on the left of the
/// camera, the free space on the right.
struct ClosedNotchMock: View {
    static let notchSize = CGSize(width: 190, height: 37)

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .stroke(NotchStyle.critical, lineWidth: 2.5)
                .frame(width: 17, height: 17)
                .frame(width: NotchGeometry.wingWidth)
            Spacer(minLength: Self.notchSize.width)
            Text("14,9G")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(NotchStyle.critical)
                .frame(width: NotchGeometry.wingWidth)
        }
        .frame(width: Self.notchSize.width + NotchGeometry.wingWidth * 2, height: Self.notchSize.height)
        .background(NotchShape(topRadius: NotchStyle.closedTopRadius, bottomRadius: NotchStyle.closedBottomRadius).fill(.black))
    }
}
