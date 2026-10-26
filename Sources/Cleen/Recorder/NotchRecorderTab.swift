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
        // The flag stays as it was: the panel's height only reads it on Gravar, so the
        // next visit opens at the right height straight away.
        .onDisappear { recorder.tabDisappeared() }
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
    /// On the floating bar it has no card of its own: the bar is the card.
    var isFloating = false
    @Environment(RecorderModel.self) private var recorder
    @State private var hovered: String?
    @State private var mobiles: [CaptureDevices.Device] = []

    var body: some View {
        HStack(spacing: 4) {
            RecorderSourceButton(title: String(localized: "Tela"), symbol: "display", isSelected: recorder.selecting == .display) { recorder.select(.display) }
            RecorderSourceButton(title: String(localized: "Janela"), symbol: "macwindow", isSelected: recorder.selecting == .window) { recorder.select(.window) }
            RecorderSourceButton(title: String(localized: "Área"), symbol: "rectangle.dashed", isSelected: recorder.selecting == .area) { recorder.select(.area) }
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
        .background(isFloating ? .clear : NotchStyle.card, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(isFloating ? .clear : NotchStyle.cardStroke) }
        .animation(.easeOut(duration: 0.18), value: recorder.selecting)
        .task { await refresh() }
    }

    private var divider: some View {
        Rectangle().fill(NotchStyle.separator).frame(width: 1, height: 36).padding(.horizontal, 4)
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
    }
}

/// One of the four sources: an icon over its name, as in Screen Studio.
struct RecorderSourceButton: View {
    let title: String
    let symbol: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RecorderSourceLabel(title: title, symbol: symbol, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct RecorderSourceLabel: View {
    let title: String
    let symbol: String
    var isSelected = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .regular))
                .frame(height: 20)
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
        }
        .frame(width: 58, height: 52)
        // The source being picked keeps a backdrop of its own, as in Screen Studio.
        .background(isSelected ? NotchStyle.control : .clear, in: .rect(cornerRadius: 10, style: .continuous))
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
