import CleenKit
import SwiftUI

/// The disk at the centre with the places Cleen looks circling it. Ripples spread from
/// the centre while it waits for access, and settle into a check once it has it.
struct DiskIllustration: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    private struct Orbiter: Identifiable {
        let symbol: String
        let angle: Double
        let radius: Double
        let size: Double
        var id: String { symbol }
    }

    private let orbiters = [
        Orbiter(symbol: "trash.fill", angle: -128, radius: 142, size: 52),
        Orbiter(symbol: "envelope.fill", angle: -48, radius: 156, size: 62),
        Orbiter(symbol: "hammer.fill", angle: 4, radius: 128, size: 40),
        Orbiter(symbol: "shippingbox.fill", angle: 62, radius: 150, size: 56),
        Orbiter(symbol: "photo.fill", angle: 128, radius: 134, size: 44),
        Orbiter(symbol: "puzzlepiece.extension.fill", angle: 176, radius: 150, size: 48),
    ]

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                RippleRing(delay: Double(index) * 1.1, isDone: model.fullDiskAccess)
            }
            ForEach(Array(orbiters.enumerated()), id: \.element.id) { index, orbiter in
                bubble(orbiter)
                    .offset(y: floating && !reduceMotion ? -5 : 5)
                    .animation(.easeInOut(duration: 2.2 + Double(index) * 0.35).repeatForever(autoreverses: true), value: floating)
                    .offset(position(of: orbiter))
            }
            core
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { floating = true }
    }

    private func position(of orbiter: Orbiter) -> CGSize {
        let angle = orbiter.angle * .pi / 180
        return CGSize(width: cos(angle) * orbiter.radius, height: sin(angle) * orbiter.radius * 0.92)
    }

    private func bubble(_ orbiter: Orbiter) -> some View {
        Circle()
            .fill(Color(white: 0.13).opacity(0.9))
            .overlay { Circle().strokeBorder(.white.opacity(0.1)) }
            .overlay {
                Image(systemName: orbiter.symbol)
                    .font(.system(size: orbiter.size * 0.36))
                    .foregroundStyle(PaintPalette.forest.glow)
            }
            .frame(width: orbiter.size, height: orbiter.size)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    private var core: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(.white)
                .frame(width: 112, height: 112)
                .overlay {
                    Image(systemName: model.fullDiskAccess ? "checkmark" : "internaldrive.fill")
                        .font(.system(size: model.fullDiskAccess ? 40 : 42, weight: .medium))
                        .foregroundStyle(model.fullDiskAccess ? NotchStyle.good : Color(white: 0.12))
                        .contentTransition(.symbolEffect(.replace))
                }
                .shadow(color: .white.opacity(0.25), radius: 24)
            if let free = model.freeSpace {
                Text("\(free.bytes) livres")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                    .background(.black.opacity(0.45), in: .capsule)
            }
        }
        .offset(y: 16)
    }
}
