import SwiftUI

/// Pill segments, white for the chosen one — the notch's take on a segmented control.
struct NotchSegmented<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? .black : NotchStyle.primary.opacity(0.75))
                        .padding(.horizontal, 9)
                        .frame(height: 22)
                        .background(isSelected ? Color.white : .clear, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(NotchStyle.control, in: .capsule)
        .animation(.smooth(duration: 0.18), value: selection)
    }
}
