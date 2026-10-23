import SwiftUI

struct AlertSettings: View {
    @AppStorage(LowDiskAlert.enabledKey) private var enabled = true
    @AppStorage(LowDiskAlert.thresholdKey) private var threshold = 10

    var body: some View {
        NotchGroup {
            SettingRow(title: String(localized: "Avisar quando o disco estiver quase cheio"), note: String(localized: "No máximo duas vezes por dia.")) {
                NotchSwitch(label: String(localized: "Avisar"), isOn: $enabled)
            }
            SettingRow(title: String(localized: "Avisar abaixo de")) {
                NotchStepper(value: $threshold, range: 2...100) { String(localized: "\($0) GB") }
                    .disabled(!enabled)
                    .opacity(enabled ? 1 : 0.4)
            }
        }
        .onChange(of: enabled) { _, on in
            if on { Task { await LowDiskAlert.requestPermission() } }
        }
    }
}
