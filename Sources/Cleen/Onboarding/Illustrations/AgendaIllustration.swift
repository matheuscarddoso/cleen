import SwiftUI

/// Today's card from the notch, propped up at an angle: the date, a few events with
/// their calendar colours, and a reminder waiting to be ticked.
struct AgendaIllustration: View {
    private struct Sample: Identifiable {
        let time: String
        let title: String
        let color: Color
        var id: String { title }
    }

    private let samples = [
        Sample(time: "09:30", title: "Daily do time", color: Color(red: 0.36, green: 0.67, blue: 1)),
        Sample(time: "12:30", title: "Almoço", color: Color(red: 1, green: 0.62, blue: 0.24)),
        Sample(time: "16:00", title: "Revisar o PR do checkout", color: Color(red: 0.69, green: 0.45, blue: 0.95)),
    ]

    /// "Sexta-feira": only the first letter goes up.
    private var weekday: String {
        let name = Date.now.formatted(.dateTime.weekday(.wide).locale(.init(identifier: "pt_BR")))
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(weekday)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(Date.now.formatted(.dateTime.day().month(.wide).locale(.init(identifier: "pt_BR"))))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(Date.now.formatted(.dateTime.day()))
                .font(.system(size: 54, weight: .light).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.top, -6)
            VStack(spacing: 8) {
                ForEach(samples) { sample in
                    HStack(spacing: 10) {
                        Capsule().fill(sample.color).frame(width: 3, height: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sample.title).font(.system(size: 12.5, weight: .medium)).foregroundStyle(.white)
                            Text(sample.time).font(.system(size: 11).monospacedDigit()).foregroundStyle(.white.opacity(0.45))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(sample.color.opacity(0.12), in: .rect(cornerRadius: 10, style: .continuous))
                }
                HStack(spacing: 10) {
                    Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1.2).frame(width: 14, height: 14)
                    Text("Pagar o boleto da internet").font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.75))
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)
            }
        }
        .padding(22)
        .frame(width: 280)
        .background(Color.black.opacity(0.82), in: .rect(cornerRadius: 26, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.12)) }
        .shadow(color: .black.opacity(0.4), radius: 30, y: 18)
        .rotationEffect(.degrees(4))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
