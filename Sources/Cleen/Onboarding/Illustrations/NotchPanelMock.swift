import CleenKit
import SwiftUI

/// The open notch as it really looks on Início, at its real size (680 × 234): header,
/// greeting, what's playing, the day, the Espelho and the tab bar, which follows the
/// tabs the person has turned on. The illustrations scale it down.
struct NotchPanelMock: View {
    @Environment(TabPreferences.self) private var tabs

    static let size = NotchGeometry.openPanelSize

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 32)
                .padding(.horizontal, 18)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(greeting), \(firstName)!")
                        .font(.system(size: 15, weight: .semibold))
                    Text(today)
                        .font(NotchStyle.caption)
                        .foregroundStyle(NotchStyle.secondary)
                }
                HStack(alignment: .center, spacing: 16) {
                    nowPlaying
                        .frame(width: 270)
                    divider
                    day
                    divider
                    mirror
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .frame(maxHeight: .infinity, alignment: .top)
            tabBar
                .padding(.top, 6)
                .padding(.bottom, 10)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .foregroundStyle(NotchStyle.primary)
        .background(NotchShape(topRadius: NotchStyle.openTopRadius, bottomRadius: NotchStyle.openBottomRadius).fill(.black))
        .overlay {
            NotchShape(topRadius: NotchStyle.openTopRadius, bottomRadius: NotchStyle.openBottomRadius)
                .stroke(.white.opacity(0.14), lineWidth: 1.5)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("Cleen").font(NotchStyle.title)
            Spacer()
            ForEach(["pin", "gearshape"], id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
                    .frame(width: 26, height: 26)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(NotchStyle.track).frame(width: 1, height: 88)
    }

    private var nowPlaying: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [PaintPalette.dawn.glow, PaintPalette.dawn.haze, PaintPalette.plum.haze], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { Image(systemName: "music.note").font(.system(size: 28, weight: .medium)).foregroundStyle(.white.opacity(0.7)) }
                .frame(width: 88, height: 88)
            VStack(alignment: .leading, spacing: 2) {
                Text("Weightless").font(.system(size: 15, weight: .semibold))
                Text("Ambient Transmissions").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.62))
                Text("Marconi Union").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                HStack(spacing: 14) {
                    Image(systemName: "backward.fill")
                    Image(systemName: "pause.fill").font(.system(size: 17))
                    Image(systemName: "forward.fill")
                }
                .font(.system(size: 13))
                .padding(.top, 6)
            }
            .lineLimit(1)
        }
    }

    private var day: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(month).font(.system(size: 16, weight: .semibold))
                ForEach(-2...2, id: \.self) { offset in
                    Text("\(dayNumber(offset))")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(offset == 0 ? .black : NotchStyle.secondary)
                        .frame(width: 24, height: 24)
                        .background(offset == 0 ? Color.white : .clear, in: .circle)
                }
            }
            HStack(spacing: 8) {
                Capsule().fill(Color(red: 0.36, green: 0.67, blue: 1)).frame(width: 3, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Daily do time").font(.system(size: 12, weight: .medium))
                    Text("09:30 – 09:45").font(NotchStyle.caption).foregroundStyle(NotchStyle.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NotchStyle.card, in: .rect(cornerRadius: 10, style: .continuous))
        }
    }

    private var mirror: some View {
        Circle()
            .fill(.white.opacity(0.1))
            .overlay {
                VStack(spacing: 5) {
                    Image(systemName: "web.camera").font(.system(size: 20, weight: .medium))
                    Text("Espelho").font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.55))
            }
            .frame(width: 88, height: 88)
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Array(tabs.visible.enumerated()), id: \.element) { index, tab in
                Image(systemName: tab.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(index == 0 ? 1 : 0.5))
                    .frame(width: 32, height: 28)
                    .background(index == 0 ? NotchStyle.selection : .clear, in: .rect(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Bom dia"
        case 12..<18: "Boa tarde"
        default: "Boa noite"
        }
    }

    private var today: String {
        let text = Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.cleen))
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private var month: String {
        Date.now.formatted(.dateTime.month(.abbreviated).locale(.cleen)).replacing(".", with: "").capitalized
    }

    private func dayNumber(_ offset: Int) -> Int {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
        return Calendar.current.component(.day, from: date)
    }

    private var firstName: String {
        NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName()
    }
}
