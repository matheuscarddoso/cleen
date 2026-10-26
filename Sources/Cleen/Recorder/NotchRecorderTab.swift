import AppKit
import ScreenCaptureKit
import SwiftUI

/// Gravar: Screen Studio's recording bar in the notch. What to record (a display, a
/// window, an area, a plugged-in iPhone), what to record with it (camera, microphone,
/// the Mac's sound), and the options; while recording it becomes the timer and Stop.
struct NotchRecorderTab: View {
    @Environment(RecorderModel.self) private var recorder
    @Environment(NotchState.self) private var notch

    var body: some View {
        VStack(spacing: 10) {
            switch recorder.state {
            case .recording, .finishing:
                RecorderLiveView()
            case .countdown(let value):
                RecorderCountdownView(value: value)
            case .failed(let message):
                RecorderMessage(text: message)
                RecorderToolbar()
            case .idle, .picking:
                if let last = recorder.lastRecording {
                    RecorderQuickShare(folder: last)
                }
                RecorderToolbar()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.25), value: recorder.state)
        // Just the bar: the panel shrinks to it, with no empty band above and below.
        .onChange(of: isJustTheBar, initial: true) { _, compact in
            withAnimation(NotchController.searchResize) { notch.isCompactTool = compact }
        }
        .onAppear { recorder.tabAppeared() }
        .onDisappear {
            notch.isCompactTool = false
            recorder.tabDisappeared()
        }
    }

    private var isJustTheBar: Bool {
        switch recorder.state {
        case .idle, .picking: recorder.lastRecording == nil
        case .recording, .finishing, .countdown: true
        case .failed: false
        }
    }
}

/// The bar itself: sources on the left, inputs in the middle, folder and options right.
struct RecorderToolbar: View {
    @Environment(RecorderModel.self) private var recorder
    @State private var hovered: String?
    @State private var displays: [SCDisplay] = []
    @State private var windows: [SCWindow] = []
    @State private var mobiles: [CaptureDevices.Device] = []

    var body: some View {
        HStack(spacing: 4) {
            displayButton
            windowButton
            RecorderSourceButton(title: String(localized: "Área"), symbol: "rectangle.dashed") { recorder.pickArea() }
            deviceButton
            divider
            RecorderCameraMenu()
            RecorderMicrophoneMenu()
            RecorderSystemAudioButton()
            divider
            Button {
                try? FileManager.default.createDirectory(at: RecorderModel.folder, withIntermediateDirectories: true)
                NSWorkspace.shared.open(RecorderModel.folder)
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .frame(width: 40, height: 40)
                    .contentShape(.rect)
                    .toolbarHoverItem("folder")
            }
            .buttonStyle(.plain)
            .help("Abrir a pasta das gravações")
            RecorderOptionsMenu()
        }
        .toolbarHoverHighlight($hovered)
        .padding(.horizontal, 6)
        .frame(height: 64)
        .background(NotchStyle.card, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NotchStyle.cardStroke) }
        .task { await refresh() }
    }

    private var divider: some View {
        Rectangle().fill(NotchStyle.separator).frame(width: 1, height: 36).padding(.horizontal, 4)
    }

    /// One display records at once; with more, a menu says which.
    @ViewBuilder
    private var displayButton: some View {
        if displays.count > 1 {
            Menu {
                ForEach(displays, id: \.displayID) { display in
                    Button(Self.name(of: display)) { recorder.record(.display(display)) }
                }
            } label: {
                RecorderSourceLabel(title: String(localized: "Tela"), symbol: "display")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        } else {
            RecorderSourceButton(title: String(localized: "Tela"), symbol: "display") {
                Task {
                    if displays.isEmpty { await refresh() }
                    if let display = displays.first { recorder.record(.display(display)) } else { recorder.requestScreenAccess() }
                }
            }
        }
    }

    private var windowButton: some View {
        Menu {
            if windows.isEmpty {
                Text("Nenhuma janela para gravar")
            }
            ForEach(windows, id: \.windowID) { window in
                Button {
                    recorder.record(.window(window))
                } label: {
                    Text(verbatim: "\(window.owningApplication?.applicationName ?? "") — \(window.title ?? "")")
                }
            }
        } label: {
            RecorderSourceLabel(title: String(localized: "Janela"), symbol: "macwindow")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .simultaneousGesture(TapGesture().onEnded { Task { await refresh() } })
    }

    private var deviceButton: some View {
        Menu {
            if mobiles.isEmpty {
                Text("Conecte um iPhone ou iPad pelo cabo")
            }
            ForEach(mobiles) { mobile in
                Button(mobile.name) { recorder.record(.device(mobile)) }
            }
        } label: {
            RecorderSourceLabel(title: String(localized: "Dispositivo"), symbol: "iphone")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    private func refresh() async {
        mobiles = await Task.detached { CaptureDevices.mobileDevices() }.value
        guard recorder.hasScreenAccess, let content = await recorder.shareableContent() else { return }
        displays = content.displays
        windows = recorder.recordableWindows(in: content)
    }

    private static func name(of display: SCDisplay) -> String {
        NSScreen.screens.first { $0.displayID == display.displayID }?.localizedName ?? String(localized: "Tela")
    }
}

/// One of the four sources: an icon over its name, as in Screen Studio.
struct RecorderSourceButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RecorderSourceLabel(title: title, symbol: symbol)
        }
        .buttonStyle(.plain)
    }
}

struct RecorderSourceLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .regular))
                .frame(height: 20)
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
        }
        .frame(width: 58, height: 52)
        .contentShape(.rect)
        .toolbarHoverItem(title)
    }
}

/// A sentence above the bar when something stopped a recording.
struct RecorderMessage: View {
    let text: String
    @Environment(RecorderModel.self) private var recorder

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(NotchStyle.warning)
            Text(text)
                .font(NotchStyle.bodyMedium)
                .foregroundStyle(NotchStyle.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("OK") { recorder.dismissError() }
                .buttonStyle(.notchSecondary)
        }
    }
}
