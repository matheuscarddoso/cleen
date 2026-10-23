import SwiftUI

/// The top of a MacBook display, drawn in real points (1512 wide, menu bar 37): the
/// bezel, a wallpaper, the menu bar, and whatever hangs from the camera housing at the
/// top centre. Fades out downward, so it reads as a glimpse of the screen.
struct MacScreen<Notch: View>: View {
    /// Zoomed in on the app: the panel fills the painting's side and most of the
    /// screen runs off the edges.
    var scale = 0.48
    @ViewBuilder let notch: Notch

    /// A MacBook's real width, so the notch and the panel keep their true size against
    /// the screen. Only the right half shows; the left dissolves into the page.
    static var displaySize: CGSize { CGSize(width: 1512, height: 700) }
    private static var bezel: Double { 14 }
    /// How far right of the illustration's centre the notch sits.
    static var centerShift: Double { 29 }
    static var drop: Double { 92 }

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
            // The notch sits right of centre and a little low, where the veil is clear:
            // the panel's right edge lands just inside the card's, its top row below
            // the veil's curve.
            .offset(x: Self.centerShift, y: Self.drop)
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
            ForEach([String(localized: "Arquivo"), String(localized: "Editar"), String(localized: "Visualizar"), String(localized: "Ir"), String(localized: "Janela"), String(localized: "Ajuda")], id: \.self) { item in
                Text(item).font(.system(size: 13))
            }
            Spacer()
            ForEach(["magnifyingglass", "switch.2", "wifi", "battery.75percent"], id: \.self) { symbol in
                Image(systemName: symbol).font(.system(size: 14))
            }
            Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute().locale(.cleen)))
                .font(.system(size: 13))
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 22)
        .frame(height: 37)
        .background(.white.opacity(0.1))
    }
}
