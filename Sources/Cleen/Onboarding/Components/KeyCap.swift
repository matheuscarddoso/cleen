import SwiftUI

/// A physical key, drawn: a pale cap on a darker skirt that sinks when pressed.
struct KeyCap: View {
    let glyph: String
    var caption: String?
    var width = 76.0
    let isPressed: Bool

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.58))
                .frame(width: width, height: 76)
                .offset(y: 6)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: isPressed ? 0.86 : 0.97), Color(white: isPressed ? 0.8 : 0.9)], startPoint: .top, endPoint: .bottom))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.7), lineWidth: 1)
                }
                .overlay {
                    VStack(spacing: 2) {
                        Text(glyph)
                            .font(.system(size: 26, weight: .regular))
                        if let caption {
                            Text(caption)
                                .font(.system(size: 9.5, weight: .medium))
                                .opacity(0.55)
                        }
                    }
                    .foregroundStyle(Color(white: 0.16))
                }
                .frame(width: width, height: 76)
                .offset(y: isPressed ? 5 : 0)
        }
        .frame(width: width, height: 82, alignment: .top)
        .shadow(color: .black.opacity(isPressed ? 0.2 : 0.35), radius: isPressed ? 4 : 12, y: isPressed ? 3 : 10)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPressed)
    }
}
