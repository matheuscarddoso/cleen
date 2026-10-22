import SwiftUI

struct NotchSwitch: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn)
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .tint(Color(red: 0.2, green: 0.78, blue: 0.35))
    }
}
