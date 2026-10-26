import SwiftUI

/// Screen Studio's slider: a thin track, filled in violet up to a round knob.
struct EditorSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    /// Called once when a drag ends.
    var onEnded: () -> Void = {}

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let knob: CGFloat = 18
            let fraction = (value - range.lowerBound) / max(0.0001, range.upperBound - range.lowerBound)
            let x = CGFloat(min(1, max(0, fraction))) * (width - knob)
            ZStack(alignment: .leading) {
                Capsule().fill(EditorTheme.controlSelected).frame(height: 4)
                Capsule().fill(EditorTheme.accent.opacity(0.75)).frame(width: x + knob / 2, height: 4)
                Circle()
                    .fill(EditorTheme.accentSoft)
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    let f = Double(min(1, max(0, (drag.location.x - knob / 2) / max(1, width - knob))))
                    value = range.lowerBound + f * (range.upperBound - range.lowerBound)
                }
                .onEnded { _ in onEnded() })
        }
        .frame(height: 22)
    }
}

/// A row of pills, one picked (Background's kinds, Speed's steps).
struct EditorPills<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    var fill = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.0) { option in
                let isOn = option.0 == selection
                Button {
                    selection = option.0
                } label: {
                    Text(option.1)
                        .font(EditorTheme.label)
                        .foregroundStyle(isOn ? EditorTheme.primary : EditorTheme.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .frame(maxWidth: fill ? .infinity : nil, minHeight: 34)
                        .background(isOn ? EditorTheme.controlSelected : .clear, in: .rect(cornerRadius: 9, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(isOn ? EditorTheme.controlStroke : .clear)
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}

/// A titled block of the inspector.
struct EditorSection<Content: View>: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(EditorTheme.title)
                    .foregroundStyle(EditorTheme.primary)
                if let detail {
                    Text(detail)
                        .font(EditorTheme.body)
                        .foregroundStyle(EditorTheme.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A label over its slider.
struct EditorSliderRow: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    var range: ClosedRange<Double>
    var format: (Double) -> String = { "\(Int(($0 * 100).rounded()))%" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(EditorTheme.body)
                    .foregroundStyle(EditorTheme.secondary)
                Spacer()
                Text(verbatim: format(value))
                    .font(EditorTheme.caption.monospacedDigit())
                    .foregroundStyle(EditorTheme.tertiary)
            }
            EditorSlider(value: $value, range: range)
        }
    }
}

/// A label with a switch.
struct EditorToggleRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(EditorTheme.body)
                .foregroundStyle(EditorTheme.secondary)
        }
        .toggleStyle(.switch)
        .tint(EditorTheme.accent)
        .controlSize(.small)
    }
}

/// The thin rule between inspector blocks.
struct EditorDivider: View {
    var body: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
    }
}
