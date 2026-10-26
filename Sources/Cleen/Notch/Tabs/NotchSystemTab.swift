import CleenKit
import SwiftUI

/// Live vitals in Droppy's Stats style: each one a colored ring with its icon, the
/// reading large with its unit, a word for how it's doing, and its recent history as a
/// glowing area line underneath.
struct NotchSystemTab: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            StatGauge(
                title: "CPU", symbol: "cpu", color: StatPalette.cpu,
                fraction: monitor.cpu?.total ?? 0,
                value: monitor.cpu.map { "\(Int(($0.total * 100).rounded()))" } ?? "—", unit: "%",
                status: cpuStatus, history: monitor.cpuHistory, scale: 1
            )
            StatGauge(
                title: String(localized: "Memória"), symbol: "memorychip", color: memoryColor,
                fraction: monitor.memory?.usedFraction ?? 0,
                value: monitor.memory.map { "\(Int(($0.usedFraction * 100).rounded()))" } ?? "—", unit: "%",
                status: memoryStatus, history: monitor.memoryHistory, scale: 1
            )
            if let celsius = monitor.battery?.temperatureCelsius {
                StatGauge(
                    title: String(localized: "Temperatura"), symbol: "thermometer.medium", color: StatPalette.temperature,
                    fraction: min(1, max(0, (celsius - 20) / 30)),
                    value: "\(Int(celsius.rounded()))", unit: "°C",
                    status: temperatureStatus(celsius), history: monitor.temperatureHistory, scale: nil
                )
            } else if let disk = monitor.disk {
                let free = Self.split(disk.available.bytes)
                StatGauge(
                    title: String(localized: "Disco"), symbol: "internaldrive", color: StatPalette.temperature,
                    fraction: disk.usedFraction,
                    value: free.number, unit: free.unit,
                    status: String(localized: "livres"), history: [], scale: 1
                )
            }
            let download = Self.split(Int64(monitor.network?.download ?? 0).bytes)
            StatGauge(
                title: String(localized: "Rede"), symbol: "arrow.down", color: StatPalette.network,
                fraction: networkFraction,
                value: download.number, unit: download.unit + "/s",
                status: String(localized: "↑ \(Int64(monitor.network?.upload ?? 0).bytes)/s"), history: monitor.downloadHistory, scale: nil
            )
        }
        .padding(.top, 4)
    }

    private var cpuStatus: String {
        switch monitor.cpu?.total ?? 0 {
        case ..<0.3: String(localized: "Tranquila")
        case ..<0.7: String(localized: "Ocupada")
        default: String(localized: "No limite")
        }
    }

    private var memoryColor: Color {
        switch monitor.memory?.pressure {
        case .critical: NotchStyle.critical
        case .warning: NotchStyle.warning
        default: StatPalette.memory
        }
    }

    private var memoryStatus: String {
        switch monitor.memory?.pressure {
        case .critical: String(localized: "Pressão alta")
        case .warning: String(localized: "Apertada")
        default: monitor.memory.map { String(localized: "de \($0.total.memoryBytes)") } ?? ""
        }
    }

    private func temperatureStatus(_ celsius: Double) -> String {
        switch celsius {
        case ..<38: String(localized: "Normal")
        case ..<44: String(localized: "Morna")
        default: String(localized: "Quente")
        }
    }

    /// Today's download against the busiest moment in the history.
    private var networkFraction: Double {
        let peak = max(monitor.downloadHistory.max() ?? 0, 1)
        return min(1, (monitor.network?.download ?? 0) / peak)
    }

    /// "12,3 MB" as ("12,3", "MB").
    static func split(_ text: String) -> (number: String, unit: String) {
        guard let space = text.lastIndex(where: { $0 == " " || $0 == "\u{00A0}" }) else { return (text, "") }
        return (String(text[..<space]), String(text[text.index(after: space)...]))
    }
}

enum StatPalette {
    static let cpu = Color(red: 0.53, green: 0.56, blue: 1.0)
    static let memory = Color(red: 0.36, green: 0.84, blue: 0.6)
    static let temperature = Color(red: 0.98, green: 0.5, blue: 0.22)
    static let network = Color(red: 0.35, green: 0.76, blue: 0.98)
}

/// One vital: title, ring with icon, the reading and a word, and the area line.
private struct StatGauge: View {
    let title: String
    let symbol: String
    let color: Color
    let fraction: Double
    let value: String
    let unit: String
    let status: String
    let history: [Double]
    /// The history's top: 1 for fractions; nil scales to its own peak.
    let scale: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(color)
            HStack(spacing: 11) {
                ZStack {
                    Circle().stroke(color.opacity(0.18), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: max(0.02, min(1, fraction)))
                        .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(color)
                }
                .frame(width: 48, height: 48)
                .animation(.spring(response: 0.7, dampingFraction: 0.86), value: fraction)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(verbatim: value)
                            .font(.system(size: 30, weight: .semibold).monospacedDigit())
                            .contentTransition(.numericText())
                        Text(verbatim: unit)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(NotchStyle.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .animation(.smooth(duration: 0.4), value: value)
                    Text(status)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(NotchStyle.tertiary)
                        .lineLimit(1)
                }
            }
            AreaLine(values: history, scale: scale, color: color)
                .frame(height: 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// History as a line with a soft fill under it, ending in a glowing dot.
private struct AreaLine: View {
    let values: [Double]
    let scale: Double?
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let points = self.points(in: proxy.size)
            if points.count > 1 {
                ZStack(alignment: .topLeading) {
                    area(points, height: proxy.size.height)
                        .fill(LinearGradient(colors: [color.opacity(0.28), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    line(points)
                        .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    if let last = points.last {
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .shadow(color: color, radius: 4)
                            .position(last)
                    }
                }
            } else {
                Capsule().fill(color.opacity(0.12)).frame(height: 2).frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .animation(.smooth(duration: 0.5), value: values)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let top = scale ?? max(values.max() ?? 1, 0.0001)
        let low = scale == nil ? (values.min() ?? 0) * 0.9 : 0
        let range = max(top - low, 0.0001)
        let step = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { index, value in
            let y = size.height - 3 - CGFloat((value - low) / range) * (size.height - 6)
            return CGPoint(x: CGFloat(index) * step, y: y)
        }
    }

    private func line(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    private func area(_ points: [CGPoint], height: CGFloat) -> Path {
        var path = line(points)
        path.addLine(to: CGPoint(x: points.last!.x, y: height))
        path.addLine(to: CGPoint(x: points[0].x, y: height))
        path.closeSubpath()
        return path
    }
}
