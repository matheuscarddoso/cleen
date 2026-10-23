import SwiftUI

/// The top of a MacBook display, drawn in real points (1512 wide, menu bar 37): the
/// bezel, a wallpaper, the menu bar, and whatever hangs from the camera housing at the
/// top centre. Fades out downward, so it reads as a glimpse of the screen.
struct MacScreen<Notch: View>: View {
    var scale = 0.3
    @ViewBuilder let notch: Notch

    /// A MacBook's real width, so the notch and the panel keep their true size against
    /// the screen. Only the right half shows; the left dissolves into the page.
    static var displaySize: CGSize { CGSize(width: 1512, height: 700) }
    private static var bezel: Double { 14 }
    /// How far left of the illustration's centre the screen sits.
    static var centerShift: Double { -34 }

    var body: some View {
        let outer = CGSize(width: Self.displaySize.width + Self.bezel * 2, height: Self.displaySize.height + Self.bezel)
        display
            .padding(.horizontal, Self.bezel)
            .padding(.top, Self.bezel)
            .background(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40, style: .continuous)
                    .fill(Color(white: 0.06))
                    .overlay {
                        // The aluminium lip catching the light along the top edge.
                        UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 3)
                    }
            }
            .frame(width: outer.width, height: outer.height, alignment: .top)
            .mask {
                LinearGradient(stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
            }
            .compositingGroup()
            .scaleEffect(scale)
            .frame(width: outer.width * scale, height: outer.height * scale)
            // Right edge just inside the panel's: the notch lands right of the page,
            // the left half runs under the veil.
            .offset(x: Self.centerShift)
    }

    private var display: some View {
        ZStack(alignment: .top) {
            wallpaper
            menuBar
            notch
        }
        .frame(width: Self.displaySize.width, height: Self.displaySize.height, alignment: .top)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous))
    }

    private var wallpaper: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x16294F), Color(hex: 0x3F66A8), Color(hex: 0x9CB6DF)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(hex: 0xF2C9A6).opacity(0.55), .clear], center: UnitPoint(x: 0.68, y: 0.95), startRadius: 20, endRadius: 620)
        }
    }

    private var menuBar: some View {
        HStack(spacing: 20) {
            Image(systemName: "apple.logo").font(.system(size: 15))
            Text("Finder").font(.system(size: 13, weight: .semibold))
            ForEach(["Arquivo", "Editar", "Visualizar", "Ir", "Janela", "Ajuda"], id: \.self) { item in
                Text(item).font(.system(size: 13))
            }
            Spacer()
            ForEach(["magnifyingglass", "switch.2", "wifi", "battery.75percent"], id: \.self) { symbol in
                Image(systemName: symbol).font(.system(size: 14))
            }
            Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute().locale(.init(identifier: "pt_BR"))))
                .font(.system(size: 13))
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 22)
        .frame(height: 37)
        .background(.white.opacity(0.1))
    }
}
